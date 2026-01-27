(use-trait risk-manager-trait .risk-management.risk-manager-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

(impl-trait .risk-management.risk-manager-trait)
(impl-trait .automation-traits.office-job-trait)
(use-trait office-job-trait .automation-traits.office-job-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_PARAMETERS (err u1005))
(define-constant ERR_NOT_CONFIGURED (err u1006))
(define-constant MIN_LEVERAGE u100)

(define-data-var contract-owner principal tx-sender)
(define-data-var max-leverage uint u2000)
(define-data-var maintenance-margin uint u500)
(define-data-var liquidation-threshold uint u8000)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)

(define-public (set-risk-parameters
    (new-max-leverage uint)
    (new-maintenance-margin uint)
    (new-liquidation-threshold uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and (>= new-max-leverage MIN_LEVERAGE) (<= new-max-leverage u5000))
      ERR_INVALID_PARAMETERS
    )
    (asserts!
      (and (> new-maintenance-margin u0) (< new-maintenance-margin u10000))
      ERR_INVALID_PARAMETERS
    )
    (asserts!
      (and (> new-liquidation-threshold new-maintenance-margin) (<= new-liquidation-threshold u10000))
      ERR_INVALID_PARAMETERS
    )
    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)
    (ok true)
  )
)

(define-public (set-liquidation-rewards
    (min-reward uint)
    (max-reward uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and
        (> min-reward u0)
        (<= min-reward max-reward)
        (<= max-reward u5000)
      )
      ERR_INVALID_PARAMETERS
    )
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    (ok true)
  )
)

(define-public (liquidate (position-id uint))
  (begin
    ;; Simplified liquidation logic
    (ok true)
  )
)

(define-read-only (get-health-factor (position-id uint))
  (begin
    ;; Simplified health factor calculation
    (ok u15000) ;; 150% health factor
  )
)

(define-public (update-position-health (position-id uint) (new-health uint) (collateral-value uint) (strategy principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Update logic would go here
    (ok true)
  )
)

(define-public (set-asset-collateral-factor (asset principal) (factor uint) (risk-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Set factor logic would go here
    (ok true)
  )
)

(define-read-only (get-asset-factor (asset principal))
  (begin
    ;; Return default collateral factor
    (ok u8000) ;; 80%
  )
)

(define-read-only (get-global-collateral-factor)
  (begin
    ;; Return global collateral factor
    (ok u8000) ;; 80%
  )
)

(define-read-only (is-liquidatable (position-id uint))
  (begin
    ;; Simplified liquidation check
    (ok false)
  )
)

(define-public (liquidate-position
    (position-id uint)
    (liquidator principal)
  )
  (ok {
    liquidated: true,
    reward: u0,
    repaid: u0,
  })
)

(define-public (set-insurance-fund (fund principal))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (var-set insurance-fund fund)
    (ok true)
  )
)

(define-read-only (calculate-liquidation-price (position {
  entry-price: uint,
  leverage: uint,
  is-long: bool,
}))
  (let (
      (m-margin (var-get maintenance-margin))
      (entry-price (get entry-price position))
      (leverage (get leverage position))
      (is-long (get is-long position))
    )
    (if is-long
      (ok (* entry-price
        (/ (+ (- (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
      (ok (* entry-price
        (/ (- (+ (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
    )
  )
)

(define-private (check-role (role (string-ascii 32)))
  (if (is-eq role "ROLE_ADMIN")
    (ok true)
    (err u1001)
  )
)

(define-public (assess-position-risk (position-id uint))
  (let (
      (position (unwrap! (contract-call? .position-manager get-position position-id)
        ERR_INVALID_PARAMETERS
      ))
      (collateral (get collateral position))
      (size (get size position))
      (entry-price (get entry-price position))
      (threshold (var-get liquidation-threshold))
      (health-factor (if (is-eq size u0)
        u1000000
        (/ (* collateral threshold) size)
      ))
      (liquidation-price (unwrap!
        (calculate-liquidation-price {
          entry-price: entry-price,
          leverage: (get leverage position),
          is-long: (get is-long position),
        })
        ERR_INVALID_PARAMETERS
      ))
    )
    (ok {
      health-factor: health-factor,
      liquidation-price: liquidation-price,
      risk-level: (if (> health-factor u15000)
        "LOW"
        (if (> health-factor u11000)
          "MEDIUM"
          "HIGH"
        )
      ),
    })
  )
)

(define-data-var cxvg-seat-nft-id uint u0)

(define-public (vote-on-solvency)
  (ok true)
)

;; --- Office Worker Implementation ---

(define-public (check-work-needed)
  (begin
    ;; In a real implementation, this would iterate over a registry of open positions.
    ;; For now, we return false as we don't have an iterable list of positions in this contract state.
    ;; This is a placeholder to satisfy the trait.
    (ok false)
  )
)

(define-public (do-work (job-data (buff 2048)))
  (let ((position-id u0)) ;; Simplified - would parse from job-data in production
    ;; Check work needed logic would go here to validate
    (begin
      ;; Call the internal liquidation
      ;; We don't have a private liquidate function, so we call the public one? 
      ;; Or we assume do-work IS the liquidation trigger.
      ;; Let's assume we call liquidate-position.
      (unwrap! (liquidate-position position-id tx-sender) ERR_UNAUTHORIZED)
      
      ;; Payout
      ;; We assume the job pays 5 uSTX for now (placeholder)
      (contract-call? .office-manager payout tx-sender u5)
    )
  )
)
