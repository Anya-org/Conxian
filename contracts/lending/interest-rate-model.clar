;; interest-rate-model.clar
;; Interest rate model for lending protocols
;; Implements dynamic interest rate calculation based on utilization

(define-constant ERR_INVALID_UTILIZATION (err u1001))
(define-constant ERR_UTILIZATION_TOO_HIGH (err u1002))

;; Interest rate curve parameters
(define-data-var base-rate uint u500)     ;; 0.05% base rate
(define-data-var slope-1 uint u1000)     ;; 0.1% slope for low utilization
(define-data-var slope-2 uint u3000)     ;; 0.3% slope for high utilization
(define-data-var kink-point uint u80000) ;; 80% utilization kink

;; Calculate interest rate based on utilization
(define-read-only (calculate-interest-rate (utilization uint))
  (begin
    (asserts! (<= utilization u100000) ERR_UTILIZATION_TOO_HIGH)
    
    (ok (if (< utilization (var-get kink-point))
      ;; Below kink: base_rate + utilization * slope_1
      (+ (var-get base-rate) 
         (* (/ utilization u100000) (var-get slope-1)))
      ;; Above kink: rate_at_kink + (utilization - kink) * slope_2
      (let ((rate-at-kink 
              (+ (var-get base-rate) 
                 (* (/ (var-get kink-point) u100000) (var-get slope-1))))
            (excess-utilization (- utilization (var-get kink-point))))
        (+ rate-at-kink 
           (* (/ excess-utilization u100000) (var-get slope-2)))
      )
    ))
  )
)

;; Get current parameters
(define-read-only (get-parameters)
  {
    base-rate: (var-get base-rate),
    slope-1: (var-get slope-1),
    slope-2: (var-get slope-2),
    kink-point: (var-get kink-point)
  }
)

;; Update parameters (admin only)
(define-public (update-parameters 
    (new-base-rate uint)
    (new-slope-1 uint)
    (new-slope-2 uint)
    (new-kink-point uint)
  )
  (begin
    (asserts! (is-eq tx-sender tx-sender) (err u1003)) ;; TODO: Add proper auth
    (var-set base-rate new-base-rate)
    (var-set slope-1 new-slope-1)
    (var-set slope-2 new-slope-2)
    (var-set kink-point new-kink-point)
    (ok true)
  )
)
