;; Fixed Point Math Library
;; Mathematical operations with fixed-point precision

;; Precision constants
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant HALF_PRECISION u500000) ;; 0.5
(define-constant PRECISION_SQUARED u1000000000000) ;; PRECISION^2

;; Basic arithmetic with fixed-point precision

;; Addition
(define-read-only (fixed-add (a uint) (b uint))
  (+ a b)
)

;; Subtraction
(define-read-only (fixed-sub (a uint) (b uint))
  (begin
    (asserts! (>= a b) (err 10001))
    (- a b)
  )
)

;; Multiplication
(define-read-only (fixed-mul (a uint) (b uint))
  (/ (* a b) PRECISION)
)

;; Division
(define-read-only (fixed-div (a uint) (b uint))
  (begin
    (asserts! (> b u0) (err 10002))
    (/ (* a PRECISION) b)
  )
)

;; Comparison operations
(define-read-only (fixed-eq (a uint) (b uint))
  (is-eq a b)
)

(define-read-only (fixed-lt (a uint) (b uint))
  (< a b)
)

(define-read-only (fixed-le (a uint) (b uint))
  (<= a b)
)

(define-read-only (fixed-gt (a uint) (b uint))
  (> a b)
)

(define-read-only (fixed-ge (a uint) (b uint))
  (>= a b)
)

;; Min/Max functions
(define-read-only (fixed-min (a uint) (b uint))
  (if (< a b) a b)
)

(define-read-only (fixed-max (a uint) (b uint))
  (if (> a b) a b)
)

;; Clamp function
(define-read-only (fixed-clamp (value uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (<= min-val max-val) (err 10003))
    (if (< value min-val) min-val (if (> value max-val) max-val value))
  )
)

;; Absolute value
(define-read-only (fixed-abs (value int))
  (if (< value 0) (- value) value)
)

;; Round functions
(define-read-only (fixed-round (value uint))
  (if (>= (mod value PRECISION) HALF_PRECISION)
      (+ value (- PRECISION (mod value PRECISION)))
      (- value (mod value PRECISION))
  )
)

(define-read-only (fixed-floor (value uint))
  (- value (mod value PRECISION))
)

(define-read-only (fixed-ceil (value uint))
  (if (is-eq (mod value PRECISION) u0)
      value
      (+ value (- PRECISION (mod value PRECISION)))
  )
)

;; Percentage calculations
(define-read-only (fixed-percentage (value uint) (percentage uint))
  (/ (* value percentage) u10000)
)

(define-read-only (fixed-percentage-of (total uint) (percentage uint))
  (/ (* total percentage) u10000)
)

;; Power functions
(define-read-only (fixed-pow (base uint) (exponent uint))
  (begin
    (asserts! (>= base u0) (err 10004))
    (if (is-eq exponent u0)
        PRECISION
        (if (is-eq (mod exponent u2) u0)
            ;; Even exponent
            (let ((half-power (fixed-pow base (/ exponent u2))))
              (fixed-mul half-power half-power)
            )
            ;; Odd exponent
            (fixed-mul base (fixed-pow base (- exponent u1)))
        )
    )
  )
)

;; Square root using Newton's method
(define-read-only (fixed-sqrt (value uint))
  (begin
    (asserts! (>= value u0) (err 10005))
    
    (if (is-eq value u0)
        u0
        (if (is-eq value PRECISION)
            u1
            ;; Newton's method iteration
            (let ((initial-guess (/ (+ value PRECISION) u2)))
              (fixed-sqrt-iter value initial-guess u10)
            )
        )
    )
  )
)

;; Helper function for square root iteration
(define-private (fixed-sqrt-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((new-guess (/ (+ guess (/ (* PRECISION PRECISION) guess)) u2)))
        (fixed-sqrt-iter value new-guess (- iterations u1))
      )
  )
)

;; Logarithm approximation
(define-read-only (fixed-ln (value uint))
  (begin
    (asserts! (> value u0) (err 10006))
    
    ;; Natural logarithm approximation using series expansion
    (if (is-eq value PRECISION)
        u0
        (let ((x (- value PRECISION)))
          (if (< x (/ PRECISION u2))
              ;; For values close to 1, use series expansion
              (fixed-ln-series x u10)
              ;; For other values, use log properties
              (let ((n (fixed-log2 value)))
                (* n (fixed-ln u2))
              )
          )
        )
    )
  )
)

;; Series expansion for ln(1+x)
(define-private (fixed-ln-series (x uint) (terms uint))
  (begin
    (asserts! (> x (- PRECISION)) (err 10007)) ;; x > -1
    (asserts! (< x PRECISION) (err 10008)) ;; x < 1
    
    (if (is-eq terms u0)
        u0
        (let ((term (/ (* (fixed-pow (-1 u1) (- terms u1)) x) terms)))
          (+ term (fixed-ln-series x (- terms u1)))
        )
    )
  )
)

;; Log base 2
(define-read-only (fixed-log2 (value uint))
  (begin
    (asserts! (> value u0) (err 10009))
    
    ;; Use binary search to find log2
    (fixed-log2-binary value u0 u64)
  )
)

;; Binary search for log2
(define-private (fixed-log2-binary (value uint) (low uint) (high uint))
  (begin
    (if (>= (- high low) u1)
        low
        (let ((mid (/ (+ low high) u2)))
          (if (<= (fixed-pow u2 mid) value)
              (fixed-log2-binary value mid high)
              (fixed-log2-binary value low mid)
          )
        )
    )
  )
)

;; Exponential function approximation
(define-read-only (fixed-exp (x uint))
  (begin
    ;; Taylor series approximation: e^x = 1 + x + x^2/2! + x^3/3! + ...
    (fixed-exp-series x u15)
  )
)

;; Series expansion for exp(x)
(define-private (fixed-exp-series (x uint) (terms uint))
  (if (is-eq terms u0)
      PRECISION
      (let ((term (/ (fixed-pow x terms) (factorial terms))))
        (+ term (fixed-exp-series x (- terms u1)))
      )
  )
)

;; Factorial function
(define-private (factorial (n uint))
  (if (<= n u1)
      u1
      (* n (factorial (- n u1)))
  )
)

;; Trigonometric functions (approximations)
(define-read-only (fixed-sin (x uint))
  (begin
    ;; Normalize x to [-π, π] range
    (let ((normalized-x (fixed-mod x (* PRECISION u314)) ;; π ≈ 3.14
          (pi (* PRECISION u314))))
      (fixed-sin-series normalized-x u10)
    )
  )
)

;; Series expansion for sin(x)
(define-private (fixed-sin-series (x uint) (terms uint))
  (if (is-eq terms u0)
      u0
      (let ((n (* terms u2)))
        (let ((term (/ (* (fixed-pow (-1 u1) terms) (fixed-pow x n)) (factorial n))))
          (+ term (fixed-sin-series x (- terms u1)))
        )
      )
  )
)

;; Cosine function
(define-read-only (fixed-cos (x uint))
  (begin
    ;; Normalize x to [-π, π] range
    (let ((normalized-x (fixed-mod x (* PRECISION u314))) ;; π ≈ 3.14
          (pi (* PRECISION u314)))
      (fixed-cos-series normalized-x u10)
    )
  )
)

;; Series expansion for cos(x)
(define-private (fixed-cos-series (x uint) (terms uint))
  (if (is-eq terms u0)
      PRECISION
      (let ((n (* terms u2)))
        (let ((term (/ (* (fixed-pow (-1 u1) terms) (fixed-pow x n)) (factorial n))))
          (+ term (fixed-cos-series x (- terms u1)))
        )
      )
  )
)

;; Modulo operation for fixed-point numbers
(define-private (fixed-mod (a uint) (b uint))
  (mod a b)
)

;; Interest rate calculations
(define-read-only (fixed-compound-interest (principal uint) (rate uint) (periods uint))
  (begin
    (asserts! (>= principal u0) (err 10010))
    (asserts! (>= rate u0) (err 10011))
    (asserts! (>= periods u0) (err 10012))
    
    (fixed-mul principal (fixed-pow (+ PRECISION rate) periods))
  )
)

;; Simple interest
(define-read-only (fixed-simple-interest (principal uint) (rate uint) (periods uint))
  (begin
    (asserts! (>= principal u0) (err 10013))
    (asserts! (>= rate u0) (err 10014))
    (asserts! (>= periods u0) (err 10015))
    
    (+ principal (fixed-mul principal (fixed-mul rate periods)))
  )
)

;; Present value calculation
(define-read-only (fixed-present-value (future-value uint) (rate uint) (periods uint))
  (begin
    (asserts! (>= future-value u0) (err 10016))
    (asserts! (> rate u0) (err 10017))
    (asserts! (>= periods u0) (err 10018))
    
    (fixed-div future-value (fixed-pow (+ PRECISION rate) periods))
  )
)

;; Annuity calculations
(define-read-only (fixed-annuity-present-value (payment uint) (rate uint) (periods uint))
  (begin
    (asserts! (>= payment u0) (err 10019))
    (asserts! (> rate u0) (err 10020))
    (asserts! (>= periods u0) (err 10021))
    
    (let ((discount-factor (fixed-div PRECISION (+ PRECISION rate)))
          (annuity-factor (fixed-div (- PRECISION (fixed-pow discount-factor periods)) rate)))
      (fixed-mul payment annuity-factor)
    )
  )
)

;; Weighted average
(define-read-only (fixed-weighted-average (values (list 10 uint)) (weights (list 10 uint)))
  (begin
    (asserts! (is-eq (len values) (len weights)) (err 10022))
    
    (let ((weighted-sum (fold2 values weights u0
      (lambda ((sum uint) (value uint) (weight uint))
        (+ sum (fixed-mul value weight))
      )))
        (total-weight (fold weights u0 +)))
        
        (if (> total-weight u0)
            (fixed-div weighted-sum total-weight)
            u0
        )
    )
  )
)

;; Standard deviation (simplified)
(define-read-only (fixed-standard-deviation (values (list 10 uint)))
  (begin
    (asserts! (> (len values) u0) (err 10023))
    
    (let ((mean (fixed-div (fold values u0 +) (len values)))
          (variance (fold values u0 
            (lambda ((sum uint) (value uint))
              (+ sum (fixed-mul (fixed-sub value mean) (fixed-sub value mean)))
            ))))
      (fixed-sqrt (fixed-div variance (len values)))
    )
  )
)

;; Helper function for fold2
(define-private (fold2 
  (list1 (list 10 uint)) 
  (list2 (list 10 uint)) 
  (initial uint) 
  (func (function 3 uint uint uint uint))
)
  (begin
    (asserts! (is-eq (len list1) (len list2)) (err 10024))
    (let ((len (len list1)))
      (fold (range u0 len) initial
        (lambda ((acc uint) (i uint))
          (func acc (get list1 i) (get list2 i)))
      )
    )
  )
)

;; Conversion functions
(define-read-only (uint-to-fixed (value uint))
  (* value PRECISION)
)

(define-read-only (fixed-to-uint (value uint))
  (/ value PRECISION)
)

(define-read-only (fixed-to-string (value uint))
  (begin
    (let ((integer-part (/ value PRECISION))
          (decimal-part (mod value PRECISION)))
      (concat (concat (to-uint integer-part) ".") (to-uint decimal-part))
    )
  )
)
