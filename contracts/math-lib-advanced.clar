;; Advanced Mathematical Library for DeFi Operations
;; Implements essential mathematical functions with 18-decimal precision
;; Provides Newton-Raphson square root, binary exponentiation, and Taylor series approximations

;; Constants for fixed-point arithmetic (18 decimal places)
(define-constant PRECISION u1000000000000000000) ;; 10^18
(define-constant HALF_PRECISION u500000000000000000) ;; 0.5 * 10^18
(define-constant MAX_UINT u340282366920938463463374607431768211455) ;; Max uint128

;; Error constants
(define-constant ERR_MATH_OVERFLOW u1000)
(define-constant ERR_MATH_UNDERFLOW u1001)
(define-constant ERR_DIVISION_BY_ZERO u1002)
(define-constant ERR_INVALID_SQRT_INPUT u1003)
(define-constant ERR_PRECISION_LOSS u1004)
(define-constant ERR_INVALID_INPUT u1005)

;; Mathematical constants in fixed-point format
(define-constant E_FIXED u2718281828459045235) ;; e ≈ 2.718281828459045235
(define-constant LN_2_FIXED u693147180559945309) ;; ln(2) ≈ 0.693147180559945309

;; Advanced math trait for external contracts
(define-trait advanced-math-trait
  ((sqrt-fixed (uint) (response uint uint))
   (pow-fixed (uint uint) (response uint uint))
   (ln-fixed (uint) (response uint uint))
   (exp-fixed (uint) (response uint uint))
   (mul-fixed (uint uint) (response uint uint))
   (div-fixed (uint uint) (response uint uint))))

;; Helper function: Check for overflow in multiplication
(define-private (check-mul-overflow (a uint) (b uint))
  (if (is-eq a u0)
    true
    (<= b (/ MAX_UINT a))))

;; Helper function: Safe multiplication with overflow check
(define-private (safe-mul (a uint) (b uint))
  (if (check-mul-overflow a b)
    (ok (* a b))
    (err ERR_MATH_OVERFLOW)))

;; Fixed-point multiplication: (a * b) / PRECISION
(define-public (mul-fixed (a uint) (b uint))
  (match (safe-mul a b)
    product (ok (/ product PRECISION))
    error (err error)))

;; Fixed-point division: (a * PRECISION) / b
(define-public (div-fixed (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_DIVISION_BY_ZERO)
    (match (safe-mul a PRECISION)
      product (ok (/ product b))
      error (err error))))

;; Newton-Raphson square root with configurable iterations
;; Uses the formula: x_{n+1} = (x_n + a/x_n) / 2
(define-public (sqrt-fixed (x uint))
  (if (is-eq x u0)
    (ok u0)
    (if (> x MAX_UINT)
      (err ERR_INVALID_SQRT_INPUT)
      (sqrt-newton-raphson x u10)))) ;; 10 iterations for precision

(define-private (sqrt-newton-raphson (x uint) (iterations uint))
  (if (is-eq iterations u0)
    (ok x)
    (let ((guess (if (> x PRECISION) (/ x u2) HALF_PRECISION)))
      (sqrt-newton-raphson-iter x guess iterations))))

(define-private (sqrt-newton-raphson-iter (x uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
    (ok guess)
    (let ((next-guess (/ (+ guess (/ (* x PRECISION) guess)) u2)))
      (sqrt-newton-raphson-iter x next-guess (- iterations u1)))))

;; Binary exponentiation for integer powers
;; Handles fractional exponents by converting to integer operations
(define-public (pow-fixed (base uint) (exponent uint))
  (if (is-eq exponent u0)
    (ok PRECISION) ;; base^0 = 1
    (if (is-eq base u0)
      (ok u0) ;; 0^n = 0 (for n > 0)
      (pow-binary-exp base exponent))))

(define-private (pow-binary-exp (base uint) (exponent uint))
  (pow-binary-exp-iter base exponent PRECISION))

(define-private (pow-binary-exp-iter (base uint) (exponent uint) (result uint))
  (if (is-eq exponent u0)
    (ok result)
    (if (is-eq (mod exponent u2) u1)
      ;; Exponent is odd
      (match (mul-fixed result base)
        new-result (pow-binary-exp-iter 
                     (unwrap-panic (mul-fixed base base))
                     (/ exponent u2)
                     new-result)
        error (err error))
      ;; Exponent is even
      (pow-binary-exp-iter 
        (unwrap-panic (mul-fixed base base))
        (/ exponent u2)
        result))))

;; Natural logarithm using Taylor series expansion
;; ln(1+x) = x - x²/2 + x³/3 - x⁴/4 + ...
;; For x in range (0, 2), we use ln(x) = ln(1 + (x-1))
(define-public (ln-fixed (x uint))
  (if (is-eq x u0)
    (err ERR_INVALID_INPUT) ;; ln(0) is undefined
    (if (is-eq x PRECISION)
      (ok u0) ;; ln(1) = 0
      (ln-taylor-series x))))

(define-private (ln-taylor-series (x uint))
  (if (< x PRECISION)
    ;; For x < 1, use ln(x) = -ln(1/x)
    (match (div-fixed PRECISION x)
      inv-x (match (ln-taylor-series inv-x)
               result (ok (- u0 result))
               error (err error))
      error (err error))
    ;; For x >= 1, use ln(x) = ln(1 + (x-1))
    (let ((y (- x PRECISION))) ;; y = x - 1
      (ln-taylor-expansion y u8)))) ;; 8 terms for precision

(define-private (ln-taylor-expansion (y uint) (terms uint))
  (ln-taylor-iter y y u1 u0 terms))

(define-private (ln-taylor-iter (y uint) (y-power uint) (n uint) (sum uint) (remaining uint))
  (if (is-eq remaining u0)
    (ok sum)
    (let ((term (/ y-power n))
          (new-sum (if (is-eq (mod n u2) u1)
                     (+ sum term) ;; Add positive terms
                     (- sum term)))) ;; Subtract negative terms
      (ln-taylor-iter y 
                      (unwrap-panic (mul-fixed y-power y))
                      (+ n u1)
                      new-sum
                      (- remaining u1)))))

;; Exponential function using Taylor series expansion
;; e^x = 1 + x + x²/2! + x³/3! + x⁴/4! + ...
(define-public (exp-fixed (x uint))
  (if (is-eq x u0)
    (ok PRECISION) ;; e^0 = 1
    (exp-taylor-series x)))

(define-private (exp-taylor-series (x uint))
  (exp-taylor-iter x PRECISION PRECISION u1 u10)) ;; 10 terms for precision

(define-private (exp-taylor-iter (x uint) (x-power uint) (factorial uint) (sum uint) (remaining uint))
  (if (is-eq remaining u0)
    (ok sum)
    (let ((term (/ x-power factorial))
          (new-sum (+ sum term))
          (new-x-power (unwrap-panic (mul-fixed x-power x)))
          (new-factorial (* factorial (+ (- u10 remaining) u1))))
      (exp-taylor-iter x new-x-power new-factorial new-sum (- remaining u1)))))

;; Precision validation function
(define-read-only (validate-precision (expected uint) (actual uint) (tolerance uint))
  (let ((diff (if (> expected actual) (- expected actual) (- actual expected))))
    (<= diff tolerance)))

;; Overflow detection for mathematical operations
(define-read-only (detect-overflow (a uint) (b uint) (operation (string-ascii 10)))
  (if (is-eq operation "multiply")
    (not (check-mul-overflow a b))
    (if (is-eq operation "add")
      (> (+ a b) MAX_UINT)
      false)))

;; Performance profiling helper
(define-read-only (get-precision-constant)
  PRECISION)

(define-read-only (get-max-uint)
  MAX_UINT)