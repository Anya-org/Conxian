;; Conxian Protocol Math Library
;; Core mathematical functions for the Conxian DeFi protocol

(define-constant PRECISION u1000000)
(define-constant BASIS_POINTS u10000)

;; Basic arithmetic with precision
(define-public (add-precision (a uint) (b uint))
  (ok (+ a b))
)

(define-public (sub-precision (a uint) (b uint))
  (begin
    (asserts! (>= a b) (err 2001))
    (ok (- a b))
  )
)

(define-public (mul-precision (a uint) (b uint))
  (ok (/ (* a b) PRECISION))
)

(define-public (div-precision (a uint) (b uint))
  (begin
    (asserts! (> b u0) (err 2002))
    (ok (/ (* a PRECISION) b))
  )
)

;; Percentage calculations
(define-public (percentage-of (amount uint) (percentage uint))
  (ok (/ (* amount percentage) BASIS_POINTS))
)

(define-public (apply-fee (amount uint) (fee-bps uint))
  (ok (- amount (/ (* amount fee-bps) BASIS_POINTS)))
)

(define-public (add-fee (amount uint) (fee-bps uint))
  (ok (+ amount (/ (* amount fee-bps) BASIS_POINTS)))
)

;; Power and root functions
(define-public (power (base uint) (exponent uint))
  (ok (pow base exponent))
)

(define-public (square-root (value uint))
  (begin
    (asserts! (>= value u0) (err 2003))
    (ok (sqrt value))
  )
)

;; Logarithmic functions
(define-public (natural-log (value uint))
  (begin
    (asserts! (> value u0) (err 2004))
    (ok (log value))
  )
)

(define-public (log-base-2 (value uint))
  (begin
    (asserts! (> value u0) (err 2005))
    (ok (log2 value))
  )
)

(define-public (log-base-10 (value uint))
  (begin
    (asserts! (> value u0) (err 2006))
    (ok (log10 value))
  )
)

;; Exponential functions
(define-public (exp-natural (value uint))
  (ok (exp value))
)

;; Trigonometric functions (if available)
(define-public (sine (value uint))
  (ok (sin value))
)

(define-public (cosine (value uint))
  (ok (cos value))
)

;; Min/Max functions
(define-public (max-value (a uint) (b uint))
  (ok (if (> a b) a b))
)

(define-public (min-value (a uint) (b uint))
  (ok (if (< a b) a b))
)

;; Clamp function
(define-public (clamp-value (value uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (<= min-val max-val) (err 2007))
    (ok (if (< value min-val) min-val (if (> value max-val) max-val value)))
  )
)

;; Absolute value
(define-public (absolute-value (value int))
  (ok (if (< value 0) (- value) value))
)

;; Rounding functions
(define-public (round-up (value uint))
  (ok (ceil value))
)

(define-public (round-down (value uint))
  (ok (floor value))
)

(define-public (round-nearest (value uint))
  (ok (round value))
)

;; Comparison functions
(define-public (is-equal-within-tolerance (a uint) (b uint) (tolerance uint))
  (ok (<= (absolute-value (- (to-int a) (to-int b))) (to-int tolerance)))
)

;; Interest rate calculations
(define-public (compound-interest (principal uint) (rate uint) (periods uint))
  (ok (* principal (pow (+ u1 (/ rate BASIS_POINTS)) periods)))
)

(define-public (simple-interest (principal uint) (rate uint) (periods uint))
  (ok (+ principal (/ (* principal rate periods) BASIS_POINTS)))
)

;; Yield calculations
(define-public (apy-to-rate (apy uint))
  (ok (- (pow (+ u1 (/ apy u36500)) u365) u1))
)

(define-public (rate-to-apy (rate uint))
  (ok (* (- (pow (+ u1 rate) u365) u1) u36500))
)

;; Liquidity calculations
(define-public (calculate-liquidity (amount0 uint) (amount1 uint) (price uint))
  (begin
    (asserts! (> price u0) (err 2008))
    (ok (min amount0 (* amount1 price)))
  )
)

;; Price calculations
(define-public (calculate-price (amount0 uint) (amount1 uint))
  (begin
    (asserts! (> amount0 u0) (err 2009))
    (ok (/ amount1 amount0))
  )
)

;; Slippage calculations
(define-public (calculate-slippage (expected-price uint) (actual-price uint))
  (begin
    (asserts! (> expected-price u0) (err 2010))
    (ok (/ (* (- expected-price actual-price) BASIS_POINTS) expected-price))
  )
)

;; Weighted average
(define-public (weighted-average (values (list 10 uint)) (weights (list 10 uint)))
  (begin
    (asserts! (is-eq (len values) (len weights)) (err 2011))
    (let ((total-weight (fold weights u0 +))
          (weighted-sum (fold2 values weights u0 
            (lambda ((sum uint) (value uint) (weight uint))
              (+ sum (/ (* value weight) BASIS_POINTS))))))
      (ok (/ (* weighted-sum BASIS_POINTS) total-weight))
    )
  )
)

;; Standard deviation (simplified)
(define-public (standard-deviation (values (list 10 uint)))
  (begin
    (asserts! (> (len values) u0) (err 2012))
    (let ((mean (fold values u0 +))
          (variance (fold values u0 
            (lambda ((sum uint) (value uint))
              (+ sum (* (- value mean) (- value mean)))))))
      (ok (sqrt (/ variance (len values))))
    )
  )
)

;; Helper function for fold2 (zip-like operation)
(define-private (fold2 
  (list1 (list 10 uint)) 
  (list2 (list 10 uint)) 
  (initial uint) 
  (func (function 3 uint uint uint uint))
)
  (begin
    (asserts! (is-eq (len list1) (len list2)) (err 2013))
    (let ((len (len list1)))
      (fold (range u0 len) initial
        (lambda ((acc uint) (i uint))
          (func acc (get i list1) (get i list2))))
    )
  )
)
