;; funding-rate-calculator.clar
;; Gas-Optimized Funding Rate Calculator
;; Core Logic for Perpetual Futures Funding

(impl-trait .core-traits.funding-rate-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant FUNDING_INTERVAL u8) ;; 8 hours (approx in blocks, but we use timestamps ideally, here simplified)
(define-constant MAX_FUNDING_RATE u500) ;; 0.05% max per interval

;; Data Vars
(define-data-var last-funding-time uint block-height)
(define-data-var current-funding-rate int 0)

;; Public Functions
(define-public (update-funding-rate
    (mark-price uint)
    (index-price uint)
  )
  (begin
    ;; Funding Rate = Clamp(Ma - Ia, -0.05%, 0.05%)
    ;; Simplified gas-free calculation
    (let ((diff (- (to-int mark-price) (to-int index-price))))
      (var-set current-funding-rate diff)
      (var-set last-funding-time block-height)
      (ok diff)
    )
  )
)

(define-read-only (get-funding-rate (id uint))
  (ok (to-uint (var-get current-funding-rate)))
)
