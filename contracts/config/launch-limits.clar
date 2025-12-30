;; launch-limits.clar
;; Defines the risk management "firewalls" for the Conxian Protocol launch.

;; --- Constants ---

;; --- TVL Caps (in micro-units) ---
(define-constant GLOBAL_TVL_CAP u500000000000) ;; $500,000
(define-constant SILVER_CAP u500000000) ;; $500
(define-constant GOLD_CAP u10000000000) ;; $10,000

;; --- Logic Injection for Vaults ---

;; @desc Provides the assertion logic to enforce TVL caps in a deposit function.
;; This function is intended to be copied into the main vault contract.
(define-read-only (enforce-deposit-limits (user principal) (user-balance uint) (deposit-amount uint))
  (let ((tier (try! (contract-call? .conxian-access get-user-tier user)))
        (new-total-tvl (+ (get-total-tvl) deposit-amount)))

    (asserts! (< new-total-tvl GLOBAL_TVL_CAP) (err u5001))

    (if (is-eq tier u1) ;; Silver Tier
      (asserts! (<= (+ user-balance deposit-amount) SILVER_CAP) (err u5002))
      (if (is-eq tier u2) ;; Gold Tier
        (asserts! (<= (+ user-balance deposit-amount) GOLD_CAP) (err u5003))
        (err u5004) ;; User has no tier
      )
    )
  )
)

;; --- Helper Functions ---

(define-read-only (get-total-tvl)
  (var-get total-tvl)
)

(define-public (update-total-tvl (new-tvl uint))
  (begin
    ;; In production, this would be restricted to a trusted oracle or automated system
    ;; For now, restrict to deployer/owner
    (asserts! (is-eq tx-sender (var-get oracle-updater)) (err u5005))
    (var-set total-tvl new-tvl)
    (ok true)
  )
)
