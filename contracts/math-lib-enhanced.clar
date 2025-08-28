;; Enhanced Mathematical Library for Advanced DeFi Operations
;; Enables competitive pool mathematics, pricing algorithms, and yield calculations

;; Constants for mathematical operations
(define-constant PRECISION u1000000) ;; 6 decimal precision
(define-constant MAX_ITERATIONS u50)
(define-constant E_SCALED u2718281) ;; e * 10^6 for precision
(define-constant LN_2_SCALED u693147) ;; ln(2) * 10^6

;; Error codes
(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_OVERFLOW (err u1002))
(define-constant ERR_CONVERGENCE (err u1003))

;; Square root using Newton-Raphson method
;; Critical for liquidity calculations in AMM pools
(define-private (sqrt (x uint))
  (if (<= x u1)
    (ok u1)
    (let ((initial-guess (/ x u2)))
      (sqrt-iterate x initial-guess u0))))

(define-private (sqrt-iterate (x uint) (guess uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (let ((new-guess (/ (+ guess (/ x guess)) u2))
          (diff (if (> new-guess guess) 
                  (- new-guess guess) 
                  (- guess new-guess))))
      (if (<= diff u1)
        (ok new-guess)
        (sqrt-iterate x new-guess (+ iterations u1))))))

;; Power function for weighted pool calculations
;; Essential for Balancer-style pools with arbitrary weights
(define-private (pow (base uint) (exponent uint))
  (if (is-eq exponent u0)
    (ok PRECISION)
    (if (is-eq exponent u1)
      (ok base)
      (if (is-eq base u0)
        (ok u0)
        (pow-iterate base exponent u1 u0)))))

(define-private (pow-iterate (base uint) (exp uint) (result uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (if (is-eq exp u0)
      (ok result)
      (if (is-eq (mod exp u2) u1)
        (pow-iterate 
          (/ (* base base) PRECISION) 
          (/ exp u2) 
          (/ (* result base) PRECISION) 
          (+ iterations u1))
        (pow-iterate 
          (/ (* base base) PRECISION) 
          (/ exp u2) 
          result 
          (+ iterations u1))))))

;; Natural logarithm for interest rate calculations
;; Required for compound interest and yield optimization
(define-private (ln (x uint))
  (if (<= x u0)
    ERR_INVALID_INPUT
    (if (is-eq x PRECISION)
      (ok u0)
      (ln-taylor-series x u0))))

(define-private (ln-taylor-series (x uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (let ((normalized (- x PRECISION))
          (term (/ normalized PRECISION)))
      (if (<= (abs-diff x PRECISION) u1000)
        (ok normalized)
        (ln-taylor-iterate normalized term u1 normalized iterations)))))

(define-private (ln-taylor-iterate (x uint) (term uint) (n uint) (sum uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (if (<= term u1)
      (ok sum)
      (let ((next-term (/ (* term x) (+ n u1)))
            (next-sum (if (is-eq (mod n u2) u1)
                        (+ sum next-term)
                        (- sum next-term))))
        (ln-taylor-iterate x next-term (+ n u1) next-sum (+ iterations u1))))))

;; Exponential function for compound calculations
(define-private (exp (x uint))
  (if (is-eq x u0)
    (ok PRECISION)
    (exp-taylor-series x u0)))

(define-private (exp-taylor-series (x uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (exp-taylor-iterate x PRECISION u1 PRECISION iterations)))

(define-private (exp-taylor-iterate (x uint) (term uint) (n uint) (sum uint) (iterations uint))
  (if (>= iterations MAX_ITERATIONS)
    ERR_CONVERGENCE
    (if (<= term u1)
      (ok sum)
      (let ((next-term (/ (* term x) n))
            (next-sum (+ sum next-term)))
        (exp-taylor-iterate x next-term (+ n u1) next-sum (+ iterations u1))))))

;; Utility function for absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (> a b) (- a b) (- b a)))

;; Public interface functions for pool mathematics
(define-read-only (calculate-sqrt (x uint))
  (sqrt x))

(define-read-only (calculate-power (base uint) (exponent uint))
  (pow base exponent))

(define-read-only (calculate-ln (x uint))
  (ln x))

(define-read-only (calculate-exp (x uint))
  (exp x))

;; Advanced pool mathematics for different AMM types
;; Constant product formula: x * y = k
(define-read-only (constant-product-invariant (x uint) (y uint))
  (* x y))

;; Weighted product formula: (x/wx)^wx * (y/wy)^wy = k
(define-read-only (weighted-product-invariant (x uint) (y uint) (wx uint) (wy uint))
  (match (pow (/ (* x PRECISION) wx) wx)
    success-x (match (pow (/ (* y PRECISION) wy) wy)
      success-y (ok (* success-x success-y))
      error-y error-y)
    error-x error-x))

;; StableSwap invariant for low-slippage stable trading
;; A * n^n * sum(x_i) + D = A * D * n^n + D^(n+1) / (n^n * prod(x_i))
(define-read-only (stable-swap-invariant (x uint) (y uint) (amplification uint))
  (let ((sum (+ x y))
        (product (* x y))
        (n u2)
        (ann (* amplification (* n n))))
    (+ (* ann sum) (/ (* product (pow-unwrap u2 u3)) (* ann product)))))

;; Helper function to unwrap power calculation results
(define-private (pow-unwrap (base uint) (exp uint))
  (unwrap-panic (pow base exp)))

;; Fee calculation with basis points precision
(define-read-only (calculate-fee (amount uint) (fee-bps uint))
  (/ (* amount fee-bps) u10000))

;; Slippage calculation for trade impact assessment
(define-read-only (calculate-slippage (expected uint) (actual uint))
  (if (> expected actual)
    (/ (* (- expected actual) u10000) expected)
    u0))

;; Price impact calculation for large trades
(define-read-only (calculate-price-impact (reserve-in uint) (reserve-out uint) (amount-in uint))
  (let ((k (constant-product-invariant reserve-in reserve-out))
        (new-reserve-in (+ reserve-in amount-in))
        (new-reserve-out (/ k new-reserve-in))
        (amount-out (- reserve-out new-reserve-out))
        (price-before (/ (* reserve-out PRECISION) reserve-in))
        (price-after (/ (* new-reserve-out PRECISION) new-reserve-in)))
    (calculate-slippage price-before price-after)))
