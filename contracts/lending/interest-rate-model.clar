;; interest-rate-model.clar
;; Implements a jump rate model for calculating interest rates

(define-constant ONE_18 (pow u10 u18))

(define-data-var base-rate-per-year uint u0)
(define-data-var multiplier-per-year uint u0)
(define-data-var jump-multiplier-per-year uint u0)
(define-data-var kink-utilization uint u0)

;; @desc Initializes the interest rate model
;; @param base-rate The base interest rate
;; @param multiplier The multiplier for the interest rate
;; @param jump-multiplier The jump multiplier for the interest rate
;; @param kink The utilization rate at which the jump multiplier is applied
(define-public (init
  (base-rate uint)
  (multiplier uint)
  (jump-multiplier uint)
  (kink uint)
)
  (begin
    (var-set base-rate-per-year base-rate)
    (var-set multiplier-per-year multiplier)
    (var-set jump-multiplier-per-year jump-multiplier)
    (var-set kink-utilization kink)
    (ok true)
  )
)

;; @desc Calculates the borrow interest rate
;; @param utilization The current utilization of the lending pool
;; @returns The borrow interest rate
(define-read-only (get-borrow-rate (utilization uint))
  (if (< utilization (var-get kink-utilization))
    (+ (* utilization (/ (var-get multiplier-per-year) ONE_18)) (var-get base-rate-per-year))
    (+ (+ (* (var-get kink-utilization) (/ (var-get multiplier-per-year) ONE_18)) (var-get base-rate-per-year)) (* (- utilization (var-get kink-utilization)) (/ (var-get jump-multiplier-per-year) ONE_18)))
  )
)

;; @desc Calculates the supply interest rate
;; @param utilization The current utilization of the lending pool
;; @returns The supply interest rate
(define-read-only (get-supply-rate (utilization uint))
  (let ((borrow-rate (get-borrow-rate utilization)))
    (* borrow-rate (/ utilization ONE_18))
  )
)