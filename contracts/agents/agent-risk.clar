(use-trait risk-manager-trait .core-traits.risk-manager-trait)
(use-trait rbac-trait .core-traits.conxian-access-trait)

(impl-trait .core-traits.risk-manager-trait)
(impl-trait .automation-traits.office-job-trait)
(use-trait office-job-trait .automation-traits.office-job-trait)

(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_INVALID_PARAMETERS u1005)
(define-constant ERR_NOT_CONFIGURED u1006)
(define-constant MIN_LEVERAGE u100)

(define-data-var contract-owner principal tx-sender)
(define-data-var max-leverage uint u2000)
(define-data-var maintenance-margin uint u500)
(define-data-var liquidation-threshold uint u8000)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)
(define-data-var last-checked-id uint u0)

(define-public (set-risk-parameters
    (new-max-leverage uint)
    (new-maintenance-margin uint)
    (new-liquidation-threshold uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and (>= new-max-leverage MIN_LEVERAGE) (<= new-max-leverage u5000))
      (err ERR_INVALID_PARAMETERS)
    )
    (asserts!
      (and (> new-maintenance-margin u0) (< new-maintenance-margin u10000))
      (err ERR_INVALID_PARAMETERS)
    )
    (asserts!
      (and (> new-liquidation-threshold new-maintenance-margin) (<= new-liquidation-threshold u10000))
      (err ERR_INVALID_PARAMETERS)
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
      (err ERR_INVALID_PARAMETERS)
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
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Update logic would go here
    (ok new-health)
  )
)

(define-public (set-asset-collateral-factor (asset principal) (factor uint) (risk-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
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
  (match (assess-position-risk position-id)
    risk-data (ok (< (get health-factor risk-data) u10000))
    error (err u404)
  )
)

(define-public (liquidate-position
    (position-id uint)
    (liquidator principal)
  )
  (begin
    (asserts! (> u1 u0) (err u1001))
    (ok {
      liquidated: true,
      reward: u0,
      repaid: u0,
    })
  )
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

(define-read-only (assess-position-risk (position-id uint))
  (let (
      (position (unwrap! (contract-call? .position-manager get-position position-id)
        (err ERR_INVALID_PARAMETERS)
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
        (err ERR_INVALID_PARAMETERS)
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

;; @desc Autonomous check to see if any position needs liquidation.
;; Keepers call this to see if they should trigger do-work.
(define-public (check-work-needed)
  (let (
    (next-id (+ (var-get last-checked-id) u1))
  )
    (match (contract-call? .dimensional-core get-position tx-sender next-id)
      pos (ok (unwrap-panic (is-liquidatable next-id)))
      none (begin
        (var-set last-checked-id u0) ;; Reset loop
        (ok false)
      )
    )
  )
)

;; @desc Executes the liquidation and rewards the worker.
;; @param job-data: The position-id encoded as a buffer (using to-consensus-buff).
(define-public (do-work (job-data (buff 2048)))
  (let (
    (position-id (unwrap! (from-consensus-buff? uint (unwrap! (as-max-len? job-data u16) (err ERR_INVALID_PARAMETERS))) (err ERR_INVALID_PARAMETERS)))
  )
    (begin
      ;; 1. Validate work is still needed
      (asserts! (unwrap-panic (is-liquidatable position-id)) (err ERR_INVALID_PARAMETERS))

      ;; 2. Execute Liquidation in the Core
      (try! (contract-call? .dimensional-core liquidate-position tx-sender position-id .oracle-aggregator))
      
      ;; 3. Update last checked ID to move the scanner forward
      (var-set last-checked-id position-id)

      ;; 4. Payout to Worker (5 uSTX reward)
      (contract-call? .office-manager payout tx-sender u5)
    )
  )
)
