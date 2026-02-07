;; risk-manager.clar
;; Assesses position health and manages liquidations

(impl-trait .core-traits.risk-manager-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_HEALTHY_POSITION u6000)
(define-constant HEALTH_FACTOR_BASE u10000)
(define-constant LIQUIDATION_THRESHOLD u8000)
(define-constant COLLATERAL_FACTOR u7500)
(define-constant LIQUIDATION_BONUS u500)

;; Data Vars
(define-data-var dimensional-engine principal tx-sender)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) (err ERR_NOT_AUTHORIZED))
    (var-set dimensional-engine new-engine)
    (ok true)
  )
)

(define-data-var base-price-feed principal tx-sender)
(define-data-var global-collateral-factor uint COLLATERAL_FACTOR)

;; Efficient Storage
(define-map position-health
  uint
  {
    health-factor: uint,
    collateral-value: uint,
    debt-value: uint,
    last-update: uint,
  }
)

(define-private (calculate-health-factor (collateral-value uint) (debt-value uint))
  (if (is-eq debt-value u0)
    u100000
    (/ (* collateral-value (var-get global-collateral-factor)) debt-value)
  )
)

(define-public (get-health-factor (position-id uint))
  (match (map-get? position-health position-id)
    health-data (ok (get health-factor health-data))
    (ok u20000)
  )
)

(define-public (update-position-health
    (position-id uint)
    (collateral-value uint)
    (debt-value uint)
    (asset principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get dimensional-engine)) (err ERR_NOT_AUTHORIZED))
    (let ((health-factor (calculate-health-factor collateral-value debt-value)))
      (map-set position-health position-id {
        health-factor: health-factor,
        collateral-value: collateral-value,
        debt-value: debt-value,
        last-update: burn-block-height,
      })
      (ok health-factor)
    )
  )
)

(define-public (liquidate (position-id uint) (collateral-token <sip-010-ft-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get dimensional-engine)) (err ERR_NOT_AUTHORIZED))
    (let ((hf (unwrap-panic (get-health-factor position-id))))
      (asserts! (< hf LIQUIDATION_THRESHOLD) (err ERR_HEALTHY_POSITION))
      (let ((pos (unwrap-panic (contract-call? .position-manager get-position position-id))))
         (let (
           (debt (get size pos))
           (collateral (get collateral pos))
           (bonus-amount (/ (* debt LIQUIDATION_BONUS) u10000))
           (target-seize (+ debt bonus-amount))
           (seize-amount (if (>= collateral target-seize) target-seize collateral))
         )
           (try! (contract-call? .lending-manager seize-collateral collateral-token (get owner pos) tx-sender seize-amount))
           (try! (contract-call? .position-manager force-close-position position-id))
           (map-delete position-health position-id)
           (ok true)
         )
      )
    )
  )
)

(define-public (set-asset-collateral-factor (asset principal) (factor uint) (vol-adj uint))
  (ok true)
)

(define-read-only (get-asset-factor (asset principal))
  (ok u8000)
)

(define-read-only (get-global-collateral-factor)
  (ok (var-get global-collateral-factor))
)

(define-read-only (is-liquidatable (position-id uint))
  (match (map-get? position-health position-id)
    data (ok (< (get health-factor data) LIQUIDATION_THRESHOLD))
    (ok false)
  )
)
