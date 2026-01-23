;; math-utilities.clar
;; Conxian Protocol: Basic mathematical utilities and helper functions

;; Constants
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant HALF_PRECISION u500000) ;; 0.5
(define-constant PRECISION_SQUARED u1000000000000) ;; PRECISION^2
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; Basic arithmetic helpers

;; Safe addition with overflow check
(define-read-only (safe-add (a uint) (b uint))
  (begin
    (asserts! (<= (+ a b) MAX_UINT) (err 15001))
    (+ a b)
  )
)

;; Safe subtraction with underflow check
(define-read-only (safe-sub (a uint) (b uint))
  (begin
    (asserts! (>= a b) (err 15002))
    (- a b)
  )
)

;; Safe multiplication with overflow check
(define-read-only (safe-mul (a uint) (b uint))
  (begin
    (asserts! (<= b u0) (err 15003))
    (asserts! (<= a (/ MAX_UINT b)) (err 15004))
    (* a b)
  )
)

;; Safe division with division by zero check
(define-read-only (safe-div (a uint) (b uint))
  (begin
    (asserts! (> b u0) (err 15005))
    (/ a b)
  )
)

;; Modulo operation with zero check
(define-read-only (safe-mod (a uint) (b uint))
  (begin
    (asserts! (> b u0) (err 15006))
    (mod a b)
  )
)

;; Power function with overflow check
(define-read-only (safe-pow (base uint) (exponent uint))
  (begin
    (asserts! (>= base u0) (err 15007))
    (asserts! (>= exponent u0) (err 15008))
    (asserts! (<= exponent u20) (err 15009)) ;; Limit exponent for performance
    
    (pow base exponent)
  )
)

;; Comparison helpers

;; Minimum of two values
(define-read-only (min (a uint) (b uint))
  (if (< a b) a b)
)

;; Maximum of two values
(define-read-only (max (a uint) (b uint))
  (if (> a b) a b)
)

;; Clamp value between min and max
(define-read-only (clamp (value uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (<= min-val max-val) (err 15010))
    (if (< value min-val) min-val (if (> value max-val) max-val value))
  )
)

;; Absolute value
(define-read-only (abs (value int))
  (if (< value 0) (- value) value)
)

;; Sign function
(define-read-only (sign (value int))
  (if (< value 0) -1 (if (> value 0) 1 0))
)

;; Percentage calculations

;; Calculate percentage of total
(define-read-only (percentage-of (part uint) (total uint))
  (begin
    (asserts! (> total u0) (err 15011))
    (/ (* part u10000) total)
  )
)

;; Apply percentage to value
(define-read-only (apply-percentage (value uint) (percentage uint))
  (/ (* value percentage) u10000)
)

;; Calculate percentage change
(define-read-only (percentage-change (old-value uint) (new-value uint))
  (begin
    (asserts! (> old-value u0) (err 15012))
    (/ (* (- new-value old-value) u10000) old-value)
  )
)

;; Rounding functions

;; Round to nearest integer
(define-read-only (round (value uint))
  (if (>= (mod value PRECISION) HALF_PRECISION)
      (+ value (- PRECISION (mod value PRECISION)))
      (- value (mod value PRECISION))
  )
)

;; Round down (floor)
(define-read-only (floor (value uint))
  (- value (mod value PRECISION)))

;; Round up (ceil)
(define-read-only (ceil (value uint))
  (if (is-eq (mod value PRECISION) u0)
      value
      (+ value (- PRECISION (mod value PRECISION)))
  )
)

;; Round to specified precision
(define-read-only (round-to-precision (value uint) (precision uint))
  (begin
    (let ((factor (/ precision PRECISION)))
      (round (/ (* value factor) precision))
    )
  )
)

;; Division and multiplication helpers

;; Divide with rounding
(define-read-only (div-round (numerator uint) (denominator uint))
  (round (/ (* numerator PRECISION) denominator))
)

;; Multiply with rounding
(define-read-only (mul-round (a uint) (b uint))
  (round (/ (* a b) PRECISION))
)

;; Square function
(define-read-only (square (value uint))
  (* value value)
)

;; Cube function
(define-read (cube (value uint))
  (* (* value value) value)
)

;; Fourth power
(define-read-only (fourth-power (value uint))
  (square (square value))
)

;; Range helpers

;; Check if value is in range [min, max]
(define-read-only (in-range (value uint) (min-val uint) (max-val uint))
  (and (>= value min-val) (<= value max-val))
)

;; Check if value is in range (min, max)
(define-read-only (in-range-exclusive (value uint) (min-val uint) (max-val uint))
  (and (> value min-val) (< value max-val))
)

;; Scale value from one range to another
(define-read-only (scale-range (value uint) (from-min uint) (from-max uint) (to-min uint) (to-max uint))
  (begin
    (asserts! (> (- from-max from-min) u0) (err 15013))
    (asserts! (> (- to-max to-min) u0) (err 15014))
    (asserts! (in-range value from-min from-max) (err 15015))
    
    (let ((normalized (/ (- value from-min) (- from-max from-min))))
      (+ to-min (* normalized (- to-max to-min)))
    )
  )
)

;; Interpolation

;; Linear interpolation between two points
(define-read-only (lerp (x0 uint) (y0 uint) (x1 uint) (y1 uint) (x uint))
  (begin
    (asserts! (or (<= x0 x) (<= x1 x)) (err 15016))
    
    (if (is-eq x0 x1)
        y0
        (+ y0 (* (/ (- x x0) (- x1 x0)) (- y1 y0)))
    )
  )
)

;; Bilinear interpolation
(define-read-only (bilerp (x0 uint) (y0 uint) (x1 uint) (y1 uint) (x2 uint) (y2 uint) (x3 uint) (y3 uint) (x uint) (y uint))
  (begin
    (let ((y01 (lerp x0 y0 x1 y1 x))
          (y23 (lerp x2 y2 x3 y3 x)))
      (lerp x y01 y23 x y)
    )
  )
)

;; Statistical helpers

;; Sum of values
(define-read-only (sum (values (list 50 uint)))
  (fold values u0 +)
)

;; Average of values
(define-read-only (average (values (list 50 uint)))
  (begin
    (asserts! (> (len values) u0) (err 15017))
    (/ (sum values) (len values))
  )
)

;; Weighted average
(define-read-only (weighted-average (values (list 50 uint)) (weights (list 50 uint)))
  (begin
    (asserts! (is-eq (len values) (len weights)) (err 15018))
    
    (let ((weighted-sum (fold2 values weights u0
      (lambda ((sum uint) (value uint) (weight uint))
        (+ sum (* value weight))
      )))
        (total-weight (sum weights)))
      
      (if (> total-weight u0)
          (/ weighted-sum total-weight)
          u0
      )
    )
  )
)

;; Helper function for fold2
(define-private (fold2 
  (list1 (list 50 uint)) 
  (list2 (list 50 uint)) 
  (initial uint) 
  (func (function 3 uint uint uint uint))
)
  (begin
    (asserts! (is-eq (len list1) (len list2)) (err 15019))
    (let ((len (len list1)))
      (fold (range u0 len) initial
        (lambda ((acc uint) (i uint))
          (func acc (get list1 i) (get list2 i)))
      )
    )
  )
)

;; Number theory helpers

;; Check if number is even
(define-read-only (is-even (n uint))
  (is-eq (mod n u2) u0)
)

;; Check if number is odd
(define-read-only (is-odd (n uint))
  (is-eq (mod n u2) u1)
)

;; Check if number is divisible by another
(define-read-only (is-divisible-by (n uint) (divisor uint))
  (is-eq (mod n divisor) u0)
)

;; Greatest common divisor (Euclidean algorithm)
(define-read-only (gcd (a uint) (b uint))
  (if (is-eq b u0)
      a
      (gcd b (mod a b))
  )
)

;; Least common multiple
(define-read-only (lcm (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
      u0
      (/ (* a b) (gcd a b))
  )
)

;; Prime number helpers

;; Check if number is prime (simplified)
(define-read-only (is-prime (n uint))
  (begin
    (asserts! (> n u1) (err 15020))
    
    (if (<= n u3)
        (or (is-eq n u2) (is-eq n u3))
        (not (has-small-divisor n))
    )
  )
)

;; Helper function to check for small divisors
(define-private (has-small-divisor (n uint))
  (fold (range u2 (+ (sqrt n) u1)) false
    (lambda ((has-divisor uint) (divisor uint))
      (or has-divisor (is-eq (mod n divisor) u0))
    )
  )
)

;; Square root (integer)
(define-read-only (int-sqrt (n uint))
  (begin
    (asserts! (>= n u0) (err 15021))
    
    (if (is-eq n u0)
        u0
        (int-sqrt-iter n (/ n u2))
    )
  )
)

;; Helper function for integer square root iteration
(define-private (int-sqrt-iter (n uint) (guess uint))
  (if (<= (* guess guess) n)
      guess
      (int-sqrt-iter n (/ (+ guess (/ n guess)) u2))
  )
)

;; Conversion helpers

;; Convert between units
(define-read-only (stx-to-micro-stx (amount uint))
  (* amount u1000000)
)

(define-read-only (micro-stx-to-stx (amount uint))
  (/ amount u1000000)
)

;; Convert to basis points
(define-read-only (to-basis-points (value uint))
  (/ (* value u10000) PRECISION)
)

;; Convert from basis points
(define-read-only (from-basis-points (basis-points uint))
  (/ (* basis-points PRECISION) u10000)
)

;; String helpers

;; Convert uint to string
(define-read-only (uint-to-string (value uint))
  (to-uint value)
)

;; Format uint with decimal places
(define-read-only (format-uint (value uint) (decimal-places uint))
  (begin
    (let ((integer-part (/ value PRECISION))
          (decimal-part (mod value PRECISION)))
      (concat (concat (uint-to-string integer-part) ".") 
                    (uint-to-string decimal-part))
    )
  )
)

;; Validation helpers

;; Validate positive number
(define-read-only (validate-positive (value uint))
  (asserts! (> value u0) (err 15022))
)

;; Validate non-negative number
(define-read-only (validate-non-negative (value uint))
  (asserts! (>= value u0) (err 15023))
)

;; Validate range
(define-read-only (validate-range (value uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (>= value min-val) (err 15024))
    (asserts! (<= value max-val) (err 15025))
  )
)

;; Validate percentage (0-10000)
(define-read-only (validate-percentage (percentage uint))
  (begin
    (asserts! (<= percentage u10000) (err 15026))
  )
)

;; Error constants for math utilities
(define-constant ERR_INVALID_INPUT (err u15027))
(define-constant ERR_OVERFLOW (err u15028))
(define-constant ERR_UNDERFLOW (err u15029))
(define-constant ERR_DIVISION_BY_ZERO (err u15030))
(define-constant ERR_NEGATIVE_INPUT (err u15031))
(define-constant ERR_INVALID_RANGE (err u15032))
(define-constant ERR_INVALID_PERCENTAGE (err u15033))
(define-constant ERR_MAX_ITERATIONS (err u15034))
