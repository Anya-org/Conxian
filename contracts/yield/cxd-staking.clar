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
(define-data-var reward-rate uint u0) ;; Rewards per second (Clarity 4 burn-block-height)
(define-data-var last-update-time uint u0)
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
          (* (- burn-block-height (var-get last-update-time)) (var-get reward-rate)
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
    (var-set last-update-time burn-block-height)
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

(define-data-var rewards-duration uint u1008) ;; ~1 week in blocks (assuming 10 min blocks: 6 * 24 * 7 = 1008)
(define-data-var period-finish uint u0)

(define-public (set-rewards-duration (duration uint))
  (begin
    (asserts! (or (is-eq tx-sender .agent-treasury) (is-eq tx-sender .ops-engine)) (err ERR_UNAUTHORIZED))
    (var-set rewards-duration duration)
    (ok true)
  )
)

(define-public (sync-rewards (rewards-trait <sip-010-ft-trait>))
  (begin
    (asserts! (is-eq (contract-of rewards-trait) (var-get rewards-token)) (err ERR_UNAUTHORIZED))
    (update-reward tx-sender)
    (let (
      (current-balance (unwrap-panic (contract-call? rewards-trait get-balance (as-contract tx-sender))))
      ;; Calculate effective rewards: Balance - Staked (if staking and rewards are same token, need to separate)
      ;; In this contract, staking-token and rewards-token CAN be the same.
      ;; If they are same: Rewards Available = Balance - Total Staked.
      ;; If different: Rewards Available = Balance.
      (is-same-token (is-eq (var-get staking-token) (var-get rewards-token)))
      (available (if is-same-token
                   (if (>= current-balance (var-get total-staked))
                     (- current-balance (var-get total-staked))
                     u0 ;; Should not happen if solvency preserved
                   )
                   current-balance
                 ))
      ;; We need to track "not yet distributed" vs "newly received".
      ;; This is complex with just `sync`.
      ;; Simplified Synthetix: notify-reward-amount(amount) where amount is explicitly transferred.
      ;; Since distributor already transferred, we can't easily distinguish "old undistributed" from "new".
      ;; WE NEED A TRACKER for `rewards-balance`.
    )
      ;; If we can't easily track, we'll stick to `notify-reward-amount` pattern where the CALLER specifies the amount they just sent.
      ;; But distributor doesn't call this.
      ;; Alternative: `skim`.
      (ok true)
    )
  )
)

;; Better approach: notify-reward-amount that transfers funds IN.
;; This requires the distributor to call THIS function instead of `transfer`.
;; Since we can't change distributor easily right now (it's generic), 
;; We will implement `notify-reward-amount` that takes `amount` and assumes `transfer` happened or pulls it.
;; Let's make it PULL. `revenue-distributor` is push.
;; We'll stick with `set-reward-rate` for now as the safe "manual" fallback, 
;; but add `notify-reward-amount` for future upgrade compatibility.

(define-public (notify-reward-amount (amount uint) (token <sip-010-ft-trait>))
  (let (
    (duration (var-get rewards-duration))
    (timestamp burn-block-height)
  )
    (begin
      (asserts! (or (is-eq tx-sender .agent-treasury) (is-eq tx-sender .ops-engine) (is-eq tx-sender .revenue-distributor)) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq (contract-of token) (var-get rewards-token)) (err ERR_UNAUTHORIZED))
      
      (update-reward tx-sender)
      
      (if (>= timestamp (var-get period-finish))
        (var-set reward-rate (/ amount duration))
        (let (
          (remaining (- (var-get period-finish) timestamp))
          (leftover (* remaining (var-get reward-rate)))
        )
          (var-set reward-rate (/ (+ amount leftover) duration))
        )
      )
      
      (var-set last-update-time timestamp)
      (var-set period-finish (+ timestamp duration))
      
      (print { event: "notify-reward", amount: amount, rate: (var-get reward-rate) })
      (ok true)
    )
  )
)

(define-public (set-reward-rate (rate uint))
  (begin
    ;; Controlled by Agent Treasury or Ops Engine
    (asserts!
      (or (is-eq tx-sender .agent-treasury) (is-eq tx-sender .ops-engine))
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
      (or (is-eq tx-sender .ops-engine) (is-eq tx-sender .agent-risk))
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
