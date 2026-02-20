;; cxd-staking.clar
;; Conxian Enterprise Standard: Staking & Yield (Tier 0 Compliance)
;; Implements O(1) Scalable Reward Distribution with "Clean-Hands" Enforcement.
;; Pausable Staking (Deposits paused on emergency, Withdrawals always open).
;; Clarity 4 Standard: Native stacks-block-time for second-precision yield.

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
(define-data-var rewards-token principal .cxd-token) ;; Rewards in CXD
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u0)
(define-data-var last-update-time uint u0)
(define-data-var reward-per-token-stored uint u0)
(define-data-var staking-paused bool false)

;; Authorized Callers (Breaking Circular Dependencies)
(define-data-var ops-engine-principal principal tx-sender)
(define-data-var agent-risk-principal principal tx-sender)
(define-data-var agent-treasury-principal principal tx-sender)

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

;; --- Reward Calculation Logic ---

(define-read-only (reward-per-token)
  (if (is-eq (var-get total-staked) u0)
    (var-get reward-per-token-stored)
    (+ (var-get reward-per-token-stored)
       (/ (* (var-get reward-rate)
             (- stacks-block-time (var-get last-update-time))
             u1000000)
          (var-get total-staked)))
  )
)

(define-read-only (earned (account principal))
  (+ (/ (* (unwrap-panic (get-user-balance account))
           (- (reward-per-token) (default-to u0 (map-get? user-reward-per-token-paid account))))
        u1000000)
     (default-to u0 (map-get? user-rewards account)))
)

(define-private (update-reward (account principal))
  (begin
    (var-set reward-per-token-stored (reward-per-token))
    (var-set last-update-time stacks-block-time)
    (map-set user-rewards account (earned account))
    (map-set user-reward-per-token-paid account (var-get reward-per-token-stored))
  )
)

;; --- Public Functions ---

(define-public (stake (amount uint))
  (begin
    (asserts! (not (var-get staking-paused)) (err ERR_PAUSED))
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))
    (update-reward tx-sender)
    (try! (contract-call? .cxd-token transfer amount tx-sender (as-contract tx-sender) none))
    (var-set total-staked (+ (var-get total-staked) amount))
    (map-set user-balance tx-sender (+ (unwrap-panic (get-user-balance tx-sender)) amount))
    (ok true)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (let ((balance (unwrap-panic (get-user-balance tx-sender))))
      (asserts! (>= balance amount) (err ERR_UNAUTHORIZED))
      (update-reward tx-sender)
      (try! (as-contract (contract-call? .cxd-token transfer amount tx-sender tx-sender none)))
      (var-set total-staked (- (var-get total-staked) amount))
      (map-set user-balance tx-sender (- balance amount))
      (ok true)
    )
  )
)

(define-public (get-reward)
  (begin
    (update-reward tx-sender)
    (let ((reward (default-to u0 (map-get? user-rewards tx-sender))))
      (if (> reward u0)
        (begin
          (map-set user-rewards tx-sender u0)
          (try! (as-contract (contract-call? .cxd-token transfer reward tx-sender tx-sender none)))
          (ok reward)
        )
        (ok u0)
      )
    )
  )
)

;; --- Admin/Agent Functions ---

(define-public (set-reward-rate (rate uint))
  (begin
    (asserts!
      (or (is-eq tx-sender (var-get agent-treasury-principal)) (is-eq tx-sender (var-get ops-engine-principal)))
      (err ERR_UNAUTHORIZED)
    )
    (update-reward tx-sender)
    (var-set reward-rate rate)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts!
      (or (is-eq tx-sender (var-get ops-engine-principal)) (is-eq tx-sender (var-get agent-risk-principal)))
      (err ERR_UNAUTHORIZED)
    )
    (var-set staking-paused paused)
    (print {
      event: "staking-pause-update",
      paused: paused,
      timestamp: stacks-block-time
    })
    (ok true)
  )
)

(define-public (set-authorized-principals (ops principal) (risk principal) (treasury principal))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-owner)) (err ERR_UNAUTHORIZED))
    (var-set ops-engine-principal ops)
    (var-set agent-risk-principal risk)
    (var-set agent-treasury-principal treasury)
    (ok true)
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-user-balance (user principal))
  (ok (default-to u0 (map-get? user-balance user)))
)

(define-read-only (get-staking-stats)
  {
    total-staked: (var-get total-staked),
    reward-rate: (var-get reward-rate),
    staking-paused: (var-get staking-paused)
  }
)
