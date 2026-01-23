;; interest-rate-model.clar
;; Conxian Finance: Interest Rate Model
;; Calculates interest rates based on utilization and market conditions

;; Constants
(define-constant ERR_NOT_IMPLEMENTED (err u9999))
(define-constant BASE_RATE u500) ;; 5% base rate
(define-constant OPTIMAL_UTILIZATION u8000) ;; 80% optimal utilization
(define-constant MAX_RATE u5000) ;; 50% max rate

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var rate-slope u2000) ;; 20% slope

;; Maps
(define-map pool-data
  { pool: principal }
  {
    total-borrows: uint,
    total-supply: uint,
    current-rate: uint
  }
)

;; Read-Only: Calculate Interest Rate
(define-read-only (calculate-interest-rate (pool principal) (utilization uint))
  (let (
    (base-rate BASE_RATE)
    (slope (var-get rate-slope))
  )
    (if (<= utilization OPTIMAL_UTILIZATION)
      ;; Below optimal: linear increase
      (ok (+ base-rate (* (/ (* utilization slope) u10000) u100)))
      ;; Above optimal: steeper increase
      (let ((excess-utilization (- utilization OPTIMAL_UTILIZATION)))
        (ok (min (+ (+ base-rate (* (/ (* OPTIMAL_UTILIZATION slope) u10000) u100))
                   (* (/ (* excess-utilization (* slope u3)) u10000) u100))
                 MAX_RATE))
      )
    )
  )
)

;; Read-Only: Get Pool Rate
(define-read-only (get-pool-rate (pool principal))
  (match (map-get? pool-data { pool: pool })
    data (ok (get current-rate data))
    (ok BASE_RATE) ;; Default to base rate
  )
)

;; Public: Update Pool Data
(define-public (update-pool-data (pool principal) (total-borrows uint) (total-supply uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_IMPLEMENTED)
    
    (let ((utilization (if (> total-supply u0)
                          (/ (* total-borrows u10000) total-supply)
                          u0)))
      (match (calculate-interest-rate pool utilization)
        rate (begin
          (map-set pool-data { pool: pool } {
            total-borrows: total-borrows,
            total-supply: total-supply,
            current-rate: (unwrap-panic rate)
          })
          (ok (unwrap-panic rate))
        )
        error error
      )
    )
  )
)

;; Public: Update Rate Slope
(define-public (update-rate-slope (new-slope uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_IMPLEMENTED)
    (var-set rate-slope new-slope)
    (ok true)
  )
)

;; Stub function for compatibility
(define-read-only (stub-func)
  (ok true)
)
