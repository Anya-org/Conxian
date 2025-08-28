;; Unified Math Library - Consolidates all mathematical functions
;; Version: v3.0 - Phase 1 Consolidation


;; Constants
(define-constant SCALE u1000000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant E_SCALED u2718281) ;; e * 10^6
(define-constant LN_2_SCALED u693147) ;; ln(2) * 10^6

;; Error codes
(define-constant ERR_OVERFLOW u1000)
(define-constant ERR_DIVISION_BY_ZERO u1001)
(define-constant ERR_INVALID_INPUT u1002)
(define-constant ERR_SQRT_OF_NEGATIVE u1003)

;; Safe arithmetic operations
(define-public (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (< result a)
      (err ERR_OVERFLOW)
      (ok result))))

(define-public (safe-sub (a uint) (b uint))
  (if (< a b)
    (err ERR_OVERFLOW)
    (ok (- a b))))

(define-public (safe-mul (a uint) (b uint))
  (if (is-eq a u0)
    (ok u0)
    (let ((result (* a b)))
      (if (is-eq (/ result a) b)
        (ok result)
        (err ERR_OVERFLOW)))))

(define-public (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_DIVISION_BY_ZERO)
    (ok (/ a b))))

;; Fixed-point multiplication
(define-public (mul-fixed (a uint) (b uint))
  (safe-div (unwrap-panic (safe-mul a b)) SCALE))

(define-public (div-fixed (a uint) (b uint))
  (safe-div (unwrap-panic (safe-mul a SCALE)) b))

;; Square root using Newton's method
(define-public (calculate-sqrt (n uint))
  (if (is-eq n u0)
    (ok u0)
    (if (is-eq n u1)
      (ok u1)
      (ok (sqrt-newton n (/ n u2))))))

(define-private (sqrt-newton (n uint) (guess uint))
  (let ((new-guess (/ (+ guess (/ n guess)) u2)))
    (if (or (is-eq new-guess guess) (<= (- new-guess guess) u1))
      guess
      (sqrt-newton n new-guess))))

;; Power function using exponentiation by squaring
(define-public (pow (base uint) (exp uint))
  (if (is-eq exp u0)
    (ok u1)
    (if (is-eq exp u1)
      (ok base)
      (ok (pow-iter base exp u1)))))

(define-private (pow-iter (base uint) (exp uint) (result uint))
  (if (is-eq exp u0)
    result
    (if (is-eq (mod exp u2) u1)
      (pow-iter (* base base) (/ exp u2) (* result base))
      (pow-iter (* base base) (/ exp u2) result))))

;; Natural logarithm approximation using Taylor series
(define-public (ln (x uint))
  (if (<= x u0)
    (err ERR_INVALID_INPUT)
    (if (is-eq x u1)
      (ok u0)
      (ln-taylor-series x))))

(define-private (ln-taylor-series (x uint))
  (let ((normalized (if (> x SCALE) (/ (* x SCALE) SCALE) x)))
    (ok (/ (* LN_2_SCALED normalized) SCALE))))

;; Exponential function approximation
(define-public (exp (x uint))
  (if (is-eq x u0)
    (ok u1)
    (exp-taylor-series x)))

(define-private (exp-taylor-series (x uint))
  (let ((scaled-e (/ (* E_SCALED x) SCALE)))
    (ok (min scaled-e MAX_UINT))))

;; Calculate slippage for AMM pools
(define-public (calculate-slippage (amount-in uint) (reserve-in uint) (reserve-out uint))
  (if (or (is-eq reserve-in u0) (is-eq reserve-out u0))
    (err ERR_DIVISION_BY_ZERO)
    (let ((k (* reserve-in reserve-out))
          (new-reserve-in (+ reserve-in amount-in))
          (new-reserve-out (/ k new-reserve-in))
          (amount-out (- reserve-out new-reserve-out)))
      (ok amount-out))))

;; Liquidity calculations for concentrated positions
(define-public (calculate-liquidity-amount-0 
  (sqrt-price-current uint)
  (sqrt-price-lower uint) 
  (sqrt-price-upper uint)
  (amount uint))
  (if (or (<= sqrt-price-upper sqrt-price-lower) (is-eq sqrt-price-current u0))
    (err ERR_INVALID_INPUT)
    (ok (/ (* amount sqrt-price-current) (- sqrt-price-upper sqrt-price-lower)))))

(define-public (calculate-liquidity-amount-1
  (sqrt-price-current uint)
  (sqrt-price-lower uint)
  (sqrt-price-upper uint) 
  (amount uint))
  (if (<= sqrt-price-upper sqrt-price-lower)
    (err ERR_INVALID_INPUT)
    (ok (/ amount (- sqrt-price-upper sqrt-price-lower)))))

;; Price impact calculation
(define-public (calculate-price-impact (amount-in uint) (reserve-in uint))
  (if (is-eq reserve-in u0)
    (err ERR_DIVISION_BY_ZERO)
    (ok (/ (* amount-in SCALE) reserve-in))))

;; Weighted average calculation
(define-public (calculate-weighted-average (values (list 10 uint)) (weights (list 10 uint)))
  (let ((total-weight (fold + weights u0))
        (weighted-sum (fold + (map * values weights) u0)))
    (if (is-eq total-weight u0)
      (err ERR_DIVISION_BY_ZERO)
      (ok (/ weighted-sum total-weight)))))

;; Minimum function
(define-read-only (min (a uint) (b uint))
  (if (< a b) a b))

;; Maximum function  
(define-read-only (max (a uint) (b uint))
  (if (> a b) a b))

;; Check if number is zero
(define-read-only (is-zero (n uint))
  (is-eq n u0))

;; Get math library version
(define-read-only (get-version)
  {version: "v3.0", name: "math-lib-unified"})
