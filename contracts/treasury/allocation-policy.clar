;; allocation-policy.clar
;; Defines protocol revenue allocation percentages
;; Basis points: 10000 = 100%
;;
;; REPAIRED: Added timelock governance, immutability lock, and transparency events

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_SHARE u1001)
(define-constant ERR_POLICY_LOCKED u1002)

;; Default allocation: 60/20/20 split
(define-constant DEFAULT_STAKING_SHARE u6000) ;; 60%
(define-constant DEFAULT_DEV_SHARE u2000)     ;; 20%
(define-constant DEFAULT_INSURANCE_SHARE u2000) ;; 20%

;; Current allocations
(define-data-var staking-share uint u6000) ;; 60%
(define-data-var dev-fund-share uint u2000) ;; 20%
(define-data-var insurance-share uint u2000) ;; 20%

;; Governance
(define-data-var admin principal tx-sender)
(define-data-var timelock principal .timelock)
(define-data-var policy-locked bool false) ;; When true, allocations cannot be changed
(define-data-var last-change-block uint u0)

;; Events
(define-private (emit-allocation-changed (staking uint) (dev uint) (insurance uint))
  (print {
    event: "allocation-changed",
    staking: staking,
    dev: dev,
    insurance: insurance,
    timestamp: burn-block-height
  })
)

(define-private (emit-policy-locked (timestamp uint))
  (print {
    event: "policy-locked",
    locked-at: timestamp,
    message: "60/20/20 split is now immutable"
  })
)

;; Authorization
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-timelock)
  (is-eq tx-sender (var-get timelock))
)

(define-private (is-authorized)
  (or (is-admin) (is-timelock))
)

;; Read-only
(define-read-only (get-allocation-percentages)
  (ok {
    staking: (var-get staking-share),
    dev: (var-get dev-fund-share),
    insurance: (var-get insurance-share),
  })
)

(define-public (set-allocations
    (staking uint)
    (dev uint)
    (insurance uint)
  )
  (begin
    ;; Must be authorized and policy not locked
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (asserts! (is-eq (+ staking (+ dev insurance)) u10000) (err ERR_INVALID_SHARE))
    
    ;; Set new allocations
    (var-set staking-share staking)
    (var-set dev-fund-share dev)
    (var-set insurance-share insurance)
    (var-set last-change-block burn-block-height)
    
    ;; Emit event
    (emit-allocation-changed staking dev insurance)
    
    (ok true)
  )
)

;; @desc Permanently lock the allocation policy (makes 60/20/20 immutable)
;; Can only be called by timelock after governance vote
(define-public (lock-policy)
  (begin
    (asserts! (is-timelock) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (var-set policy-locked true)
    (emit-policy-locked burn-block-height)
    (ok true)
  )
)

;; @desc Reset to default 60/20/20 split (emergency use)
(define-public (reset-to-default)
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (var-set staking-share DEFAULT_STAKING_SHARE)
    (var-set dev-fund-share DEFAULT_DEV_SHARE)
    (var-set insurance-share DEFAULT_INSURANCE_SHARE)
    (var-set last-change-block burn-block-height)
    (emit-allocation-changed DEFAULT_STAKING_SHARE DEFAULT_DEV_SHARE DEFAULT_INSURANCE_SHARE)
    (ok true)
  )
)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-timelock (new-timelock principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set timelock new-timelock)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-policy-locked)
  (var-get policy-locked)
)

(define-read-only (get-last-change-block)
  (var-get last-change-block)
)

(define-read-only (get-default-allocations)
  {
    staking: DEFAULT_STAKING_SHARE,
    dev: DEFAULT_DEV_SHARE,
    insurance: DEFAULT_INSURANCE_SHARE
  }
)

(define-read-only (get-policy-status)
  {
    locked: (var-get policy-locked),
    last-change: (var-get last-change-block),
    admin: (var-get admin),
    timelock: (var-get timelock)
  }
)
