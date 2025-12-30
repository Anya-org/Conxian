;; rewards.clar
;; Implements the decaying yield curve for the Conxian Protocol.

;; --- Traits ---
(use-trait access-control .traits.access-control-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant LAUNCH_HEIGHT_DELAY u100)
(define-constant DECAY_PHASE_1_DURATION u4320) ;; Approx 1 month in blocks

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var launch-block uint u0)
(define-data-var conxian-access-contract principal .conxian-access)

;; --- Public Read-Only ---

(define-read-only (get-reward-multiplier (user principal))
  (let ((tier (unwrap! (get-user-tier user) (err u0)))
        (current-height block-height)
        (launch-height (var-get launch-block)))
    (if (< tier u2)
      (ok u100) ;; 1.0x multiplier for Silver Tier
      (let ((age (- current-height launch-height)))
        (if (< age DECAY_PHASE_1_DURATION)
          (ok u250) ;; 2.5x multiplier for Gold Tier in Phase 1
          (ok u150) ;; 1.5x multiplier for Gold Tier after Phase 1
        )
      )
    )
  )
)

;; --- Private Read-Only ---

(define-private (get-user-tier (user principal))
  (contract-call? .conxian-access get-user-tier user)
)

;; --- Admin Functions ---

(define-public (set-launch-block)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set launch-block (+ block-height LAUNCH_HEIGHT_DELAY))
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-access-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set conxian-access-contract contract)
    (ok true)
  )
)
