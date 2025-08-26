;; Fixed-Point Mathematics Utility Contract
;; Provides precise arithmetic operations with configurable decimal precision
;; Implements rounding modes and conversion functions for DeFi calculations

;; Import advanced math library
(use-trait advanced-math-trait .math-lib-advanced.advanced-math-trait)

;; Precision constants
(define-constant PRECISION_18 u1000000000000000000) ;; 10^18
(define-constant PRECISION_8 u100000000) ;; 10^8
(define-constant PRECISION_6 u1000000) ;; 10^6
(define-constant HALF_PRECISION_18 u500000000000000000) ;; 0.5 * 10^18

;; Error constants
(define-constant ERR_DIVISION_BY_ZERO u1002)
(define-constant ERR_MATH_OVERFLOW u1000)
(define-constant ERR_INVALID_PRECISION u1006)
(define-constant ERR_ROUNDING_ERROR u1007)

;; Maximum safe values for different precisions
(define-constant MAX_UINT_128 u340282366920938463463374607431768211455)
(define-constant SAFE_MULTIPLIER_18 u18446744073709551615) ;; sqrt(MAX_UINT_128)

;; Rounding modes
(define-constant ROUND_DOWN u0)
(define-constant ROUND_UP u1)
(define-constant ROUND_NEAREST u2)

;; Precise multiplication with rounding down (conservative for user protection)
(define-public (mul-down (a uint) (b uint))
  (mul-down-precision a b PRECISION_18))

;; Precise multiplication with rounding up (conservative for protocol protection)
(define-public (mul-up (a uint) (b uint))
  (mul-up-precision a b PRECISION_18))

;; Multiplication with custom precision and round down
(define-public (mul-down-precision (a uint) (b uint) (precision uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (if (> a (/ MAX_UINT_128 b))
      (err ERR_MATH_OVERFLOW)
      (ok (/ (* a b) precision)))))

;; Multiplication with custom precision and round up
(define-public (mul-up-precision (a uint) (b uint) (precision uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (if (> a (/ MAX_UINT_128 b))
      (err ERR_MATH_OVERFLOW)
      (let ((product (* a b))
            (quotient (/ product precision))
            (remainder (mod product precision)))
        (ok (if (> remainder u0)
              (+ quotient u1) ;; Round up
              quotient))))))

;; Precise division with rounding down
(define-public (div-down (a uint) (b uint))
  (div-down-precision a b PRECISION_18))

;; Precise division with rounding up
(define-public (div-up (a uint) (b uint))
  (div-up-precision a b PRECISION_18))

;; Division with custom precision and round down
(define-public (div-down-precision (a uint) (b uint) (precision uint))
  (if (is-eq b u0)
    (err ERR_DIVISION_BY_ZERO)
    (if (is-eq a u0)
      (ok u0)
      (if (> a (/ MAX_UINT_128 precision))
        (err ERR_MATH_OVERFLOW)
        (ok (/ (* a precision) b))))))

;; Division with custom precision and round up
(define-public (div-up-precision (a uint) (b uint) (precision uint))
  (if (is-eq b u0)
    (err ERR_DIVISION_BY_ZERO)
    (if (is-eq a u0)
      (ok u0)
      (if (> a (/ MAX_UINT_128 precision))
        (err ERR_MATH_OVERFLOW)
        (let ((numerator (* a precision))
              (quotient (/ numerator b))
              (remainder (mod numerator b)))
          (ok (if (> remainder u0)
                (+ quotient u1) ;; Round up
                quotient)))))))

;; Conversion between different decimal precisions
(define-public (convert-precision (value uint) (from-precision uint) (to-precision uint))
  (if (is-eq from-precision to-precision)
    (ok value)
    (if (> from-precision to-precision)
      ;; Converting to lower precision (divide)
      (ok (/ value (/ from-precision to-precision)))
      ;; Converting to higher precision (multiply)
      (let ((multiplier (/ to-precision from-precision)))
        (if (> value (/ MAX_UINT_128 multiplier))
          (err ERR_MATH_OVERFLOW)
          (ok (* value multiplier)))))))

;; Convert from 18-decimal to 8-decimal precision
(define-public (to-precision-8 (value uint))
  (convert-precision value PRECISION_18 PRECISION_8))

;; Convert from 18-decimal to 6-decimal precision
(define-public (to-precision-6 (value uint))
  (convert-precision value PRECISION_18 PRECISION_6))

;; Convert from 8-decimal to 18-decimal precision
(define-public (from-precision-8 (value uint))
  (convert-precision value PRECISION_8 PRECISION_18))

;; Convert from 6-decimal to 18-decimal precision
(define-public (from-precision-6 (value uint))
  (convert-precision value PRECISION_6 PRECISION_18))

;; Floor function for fixed-point numbers
(define-public (floor-fixed (value uint))
  (floor-fixed-precision value PRECISION_18))

(define-public (floor-fixed-precision (value uint) (precision uint))
  (ok (/ (* (/ value precision) precision) u1)))

;; Ceiling function for fixed-point numbers
(define-public (ceil-fixed (value uint))
  (ceil-fixed-precision value PRECISION_18))

(define-public (ceil-fixed-precision (value uint) (precision uint))
  (let ((quotient (/ value precision))
        (remainder (mod value precision)))
    (ok (* (if (> remainder u0) (+ quotient u1) quotient) precision))))

;; Round function for fixed-point numbers (banker's rounding)
(define-public (round-fixed (value uint))
  (round-fixed-precision value PRECISION_18))

(define-public (round-fixed-precision (value uint) (precision uint))
  (let ((quotient (/ value precision))
        (remainder (mod value precision))
        (half-precision (/ precision u2)))
    (ok (* (if (> remainder half-precision)
             (+ quotient u1)
             (if (is-eq remainder half-precision)
               ;; Banker's rounding: round to even
               (if (is-eq (mod quotient u2) u0)
                 quotient ;; Even, round down
                 (+ quotient u1)) ;; Odd, round up
               quotient)) ;; Less than half, round down
           precision))))

;; Custom rounding with specified mode
(define-public (round-with-mode (value uint) (precision uint) (mode uint))
  (cond
    ((is-eq mode ROUND_DOWN) (floor-fixed-precision value precision))
    ((is-eq mode ROUND_UP) (ceil-fixed-precision value precision))
    ((is-eq mode ROUND_NEAREST) (round-fixed-precision value precision))
    (else (err ERR_INVALID_PRECISION))))

;; Comparison functions for fixed-point arithmetic
(define-read-only (fixed-equal (a uint) (b uint) (tolerance uint))
  (let ((diff (if (> a b) (- a b) (- b a))))
    (<= diff tolerance)))

(define-read-only (fixed-greater-than (a uint) (b uint))
  (> a b))

(define-read-only (fixed-less-than (a uint) (b uint))
  (< a b))

(define-read-only (fixed-greater-equal (a uint) (b uint))
  (>= a b))

(define-read-only (fixed-less-equal (a uint) (b uint))
  (<= a b))

;; Absolute difference between two fixed-point numbers
(define-read-only (fixed-abs-diff (a uint) (b uint))
  (if (> a b) (- a b) (- b a)))

;; Percentage calculation: (value * percentage) / 100
(define-public (calculate-percentage (value uint) (percentage uint))
  (mul-down-precision value percentage (/ PRECISION_18 u100)))

;; Basis points calculation: (value * bps) / 10000
(define-public (calculate-basis-points (value uint) (bps uint))
  (mul-down-precision value bps (/ PRECISION_18 u10000)))

;; Average of two fixed-point numbers
(define-read-only (fixed-average (a uint) (b uint))
  (/ (+ a b) u2))

;; Weighted average: (a * weight_a + b * weight_b) / (weight_a + weight_b)
(define-public (weighted-average (a uint) (weight-a uint) (b uint) (weight-b uint))
  (let ((total-weight (+ weight-a weight-b)))
    (if (is-eq total-weight u0)
      (err ERR_DIVISION_BY_ZERO)
      (match (mul-down a weight-a)
        weighted-a (match (mul-down b weight-b)
                     weighted-b (div-down (+ weighted-a weighted-b) total-weight)
                     error (err error))
        error (err error)))))

;; Minimum of two values
(define-read-only (fixed-min (a uint) (b uint))
  (if (< a b) a b))

;; Maximum of two values
(define-read-only (fixed-max (a uint) (b uint))
  (if (> a b) a b))

;; Clamp value between min and max
(define-read-only (fixed-clamp (value uint) (min-val uint) (max-val uint))
  (fixed-max min-val (fixed-min value max-val)))

;; Check if value is within a range (inclusive)
(define-read-only (in-range (value uint) (min-val uint) (max-val uint))
  (and (>= value min-val) (<= value max-val)))

;; Scale value from one range to another
(define-public (scale-range (value uint) (old-min uint) (old-max uint) (new-min uint) (new-max uint))
  (if (is-eq old-min old-max)
    (err ERR_DIVISION_BY_ZERO)
    (let ((old-range (- old-max old-min))
          (new-range (- new-max new-min))
          (normalized (- value old-min)))
      (match (mul-down normalized new-range)
        scaled (match (div-down scaled old-range)
                 result (ok (+ result new-min))
                 error (err error))
        error (err error)))))

;; Get precision constants
(define-read-only (get-precision-18) PRECISION_18)
(define-read-only (get-precision-8) PRECISION_8)
(define-read-only (get-precision-6) PRECISION_6)

;; Validate precision value
(define-read-only (is-valid-precision (precision uint))
  (or (is-eq precision PRECISION_18)
      (is-eq precision PRECISION_8)
      (is-eq precision PRECISION_6)))