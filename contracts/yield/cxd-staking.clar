;; cxd-staking.clar
;; Conxian Enterprise Standard: Staking & Yield (Tier 0 Compliance)
;; Implements O(1) Scalable Reward Distribution with "Clean-Hands" Enforcement.
;; Pausable Staking (Deposits paused on emergency, Withdrawals always open).

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_NON_COMPLIANT u8001)
(define-constant ERR_ZERO_STAKE u8002)
(define-constant ERR_NOT_FOUND u8003)
(define-constant ERR_PAUSED u8004)

;; State
(define-data-var staking-token principal .cxd-token)
(define-data-var rewards-token principal .cxd-token) ;; Rewards in CXD (can be changed to other token)
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u0) ;; Rewards per block
(define-data-var last-update-block uint u0)
(define-data-var reward-per-token-stored uint u0)
(define-data-var staking-paused bool false)

;; Maps
(define-map user-balance
  principal
  uint
)
(define-map user-reward-per-token-paid
  principal
  uint
)
(define-map user-rewards
  principal
  uint
)

;; --- Compliance ---
(define-private (check-compliance (user principal))
  (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
    (if (is-ok compliance-status)
      true
      false
    )
  )
)

;; --- Math & View ---

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? user-balance account))
)

(define-read-only (get-reward-per-token)
  (let ((total (var-get total-staked)))
    (if (is-eq total u0)
      (var-get reward-per-token-stored)
      (+ (var-get reward-per-token-stored)
        (/
          (* (- block-height (var-get last-update-block)) (var-get reward-rate)
            u1000000 ;; Precision Factor
          )
          total
        ))
    )
  )
)

(define-read-only (earned (account principal))
  (let (
      (balance (get-balance account))
      (per-token (get-reward-per-token))
      (paid (default-to u0 (map-get? user-reward-per-token-paid account)))
      (rewards (default-to u0 (map-get? user-rewards account)))
    )
    (/ (+ (* balance (- per-token paid)) (* rewards u1000000)) u1000000)
  )
)

;; --- Core Actions ---

(define-private (update-reward (account principal))
  (let ((new-per-token (get-reward-per-token)))
    (var-set reward-per-token-stored new-per-token)
    (var-set last-update-block block-height)
    (if (not (is-eq account tx-sender))
      true ;; No-op if just updating global
      (begin
        (map-set user-rewards account (earned account))
        (map-set user-reward-per-token-paid account new-per-token)
        true
      )
    )
  )
)

(define-public (stake
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    ;; Fail if paused
    (asserts! (not (var-get staking-paused)) (err ERR_PAUSED))
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))
    (asserts! (is-eq (contract-of token) (var-get staking-token))
      (err ERR_UNAUTHORIZED)
    )
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))

    (update-reward tx-sender)

    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))

    (var-set total-staked (+ (var-get total-staked) amount))
    (map-set user-balance tx-sender (+ (get-balance tx-sender) amount))

    (print {
      event: "stake",
      user: tx-sender,
      amount: amount,
    })
    (ok true)
  )
)

(define-public (withdraw
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    ;; Withdrawals are allowed even if paused (User Protection Ethos)
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))
    (asserts! (is-eq (contract-of token) (var-get staking-token))
      (err ERR_UNAUTHORIZED)
    )
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (asserts! (>= (get-balance tx-sender) amount) (err ERR_ZERO_STAKE))

    (update-reward tx-sender)

    (var-set total-staked (- (var-get total-staked) amount))
    (map-set user-balance tx-sender (- (get-balance tx-sender) amount))

    (as-contract (try! (contract-call? token transfer amount tx-sender tx-sender none)))

    (print {
      event: "withdraw",
      user: tx-sender,
      amount: amount,
    })
    (ok true)
  )
)

(define-public (get-reward (token <sip-010-ft-trait>))
  (let ((reward (earned tx-sender)))
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))
    (asserts! (is-eq (contract-of token) (var-get rewards-token))
      (err ERR_UNAUTHORIZED)
    )

    (update-reward tx-sender)
    (map-set user-rewards tx-sender u0)

    (if (> reward u0)
      (as-contract (try! (contract-call? token transfer reward tx-sender tx-sender none)))
      true
    )

    (print {
      event: "get-reward",
      user: tx-sender,
      amount: reward,
    })
    (ok reward)
  )
)

(define-public (exit
    (staking-token-trait <sip-010-ft-trait>)
    (rewards-token-trait <sip-010-ft-trait>)
  )
  (begin
    (try! (withdraw (get-balance tx-sender) staking-token-trait))
    (get-reward rewards-token-trait)
  )
)

;; --- Admin ---

(define-public (set-reward-rate (rate uint))
  (begin
    ;; Controlled by Agent Treasury or Ops Engine
    (asserts!
      (or (is-eq tx-sender .agent-treasury) (is-eq tx-sender .conxian-operations-engine))
      (err ERR_UNAUTHORIZED)
    )
    (update-reward tx-sender)
    (var-set reward-rate rate)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    ;; Controlled by Ops Engine or Risk Agent (Emergency)
    (asserts!
      (or (is-eq tx-sender .conxian-operations-engine) (is-eq tx-sender .agent-risk))
      (err ERR_UNAUTHORIZED)
    )
    (var-set staking-paused paused)
    (print {
      event: "staking-pause-update",
      paused: paused,
    })
    (ok true)
  )
)
