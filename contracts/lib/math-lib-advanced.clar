;; math-lib-advanced.clar
;; Conxian Protocol: Advanced mathematical functions and algorithms

;; Dependencies
(use-trait .math-utilities .math-utilities.math-utilities)

;; Constants
(define-constant PI u314159265)
(define-constant E u271828182)
(define-constant GOLDEN_RATIO u161803398)
(define-constant SQRT_2 u141421356)
(define-constant SQRT_3 u173205080)
(define-constant LN_2 u693147180)
(define-constant LN_10 u230258509)

;; Advanced constants
(define-constant MAX_ITERATIONS u100)
(define-constant TOLERANCE u1000) ;; 0.001
(define-constant DEGREES_TO_RADIANS (/ PI u180))
(define-constant RADIANS_TO_DEGREES (/ u180 PI))

;; Advanced arithmetic functions

;; Square root with Newton's method
(define-read-only (sqrt-newton (value uint) (iterations uint))
  (begin
    (asserts! (>= value u0) (err 14001))
    
    (if (is-eq value u0)
        u0
        (if (is-eq value PRECISION)
            u1
            (sqrt-newton-iter value (/ value u2) iterations)
        )
    )
  )

;; Helper function for Newton's method iteration
(define-private (sqrt-newton-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((new-guess (/ (+ guess (/ (* PRECISION PRECISION) guess)) u2)))
        (sqrt-newton-iter value new-guess (- iterations u1))
      )
  )
)

;; Cube root
(define-read-only (cube-root (value uint))
  (begin
    (asserts! (>= value u0) (err 14002))
    
    (if (is-eq value u0)
        u0
        (cube-root-iter value (/ value u3) u20)
    )
  )

;; Helper function for cube root iteration
(define-private (cube-root-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((new-guess (/ (+ (* u2 guess) (/ (* value PRECISION PRECISION) (* guess guess))) u3)))
        (cube-root-iter value new-guess (- iterations u1))
      )
  )
)

;; Nth root
(define-read-only (nth-root (value uint) (n uint))
  (begin
    (asserts! (>= value u0) (err 14003))
    (asserts! (> n u0) (err 14004))
    
    (if (is-eq n u1)
        value
        (if (is-eq n u2)
            (sqrt-newton value u10)
            (nth-root-iter value (/ value n) u15)
        )
    )
  )

;; Helper function for nth root iteration
(define-private (nth-root-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((new-guess (/ (+ (* (- n u1) guess) (/ (* value PRECISION PRECISION) (pow guess (- n u1)))) n))
        (nth-root-iter value new-guess (- iterations u1))
      )
  )
)

;; Logarithmic functions

;; Natural logarithm using series expansion
(define-read-only (ln (value uint))
  (begin
    (asserts! (> value u0) (err 14005))
    
    (if (is-eq value PRECISION)
        u0
        (let ((x (- value PRECISION)))
          (if (< x (/ PRECISION u2))
              ;; For values close to 1, use series expansion
              (ln-series x u15)
              ;; Use change of base formula: ln(x) = 2 * log2(x)
              (* u2 (log2 value))
          )
        )
    )
  )
)

;; Series expansion for ln(1+x)
(define-private (ln-series (x uint) (terms uint))
  (if (is-eq terms u0)
      u0
      (let ((term (/ (* (pow (-1 u1) (- terms u1)) x) terms)))
        (+ term (ln-series x (- terms u1)))
      )
  )
)

;; Log base 2
(define-read-only (log2 (value uint))
  (begin
    (asserts! (> value u0) (err 14006))
    
    ;; Use binary search for log2
    (log2-binary value u0 u64)
  )
)

;; Binary search for log2
(define-private (log2-binary (value uint) (low uint) (high uint))
  (if (>= (- high low) u1)
      low
      (let ((mid (/ (+ low high) u2)))
        (if (<= (pow u2 mid) value)
            (log2-binary value mid high)
            (log2-binary value low mid)
        )
      )
  )
)

;; Log base 10
(define-read-only (log10 (value uint))
  (begin
    (asserts! (> value u0) (err 14007))
    
    ;; Use change of base formula: log10(x) = ln(x) / ln(10)
    (/ (ln value) LN_10)
  )
)

;; Custom base logarithm
(define-read-only (log-base (value uint) (base uint))
  (begin
    (asserts! (> value u0) (err 14008))
    (asserts! (> base u1) (err 14009))
    
    (/ (ln value) (ln base))
  )
)

;; Trigonometric functions

;; Sine function using Taylor series
(define-read-only (sin (angle uint))
  (begin
    ;; Normalize angle to [-π, π] range
    (let ((normalized-angle (mod angle (* PI u2))))
      (if (> normalized-angle PI)
          (sin-series (- normalized-angle (* PI u2)) u10)
          (sin-series normalized-angle u10)
      )
    )
  )
)

;; Taylor series for sin(x)
(define-private (sin-series (x uint) (terms uint))
  (if (is-eq terms u0)
      u0
      (let ((n (* terms u2)))
        (let ((term (/ (* (pow (-1 u1) terms) (pow x n)) (factorial n))))
          (+ term (sin-series x (- terms u1)))
        )
      )
  )
)

;; Cosine function using Taylor series
(define-read-only (cos (angle uint))
  (begin
    ;; Normalize angle to [-π, π] range
    (let ((normalized-angle (mod angle (* PI u2))))
      (if (> normalized-angle PI)
          (cos-series (- normalized-angle (* PI u2)) u10)
          (cos-series normalized-angle u10)
      )
    )
  )
)

;; Taylor series for cos(x)
(define-private (cos-series (x uint) (terms uint))
  (if (is-eq terms u0)
      PRECISION
      (let ((n (* terms u2)))
        (let ((term (/ (* (pow (-1 u1) terms) (pow x n)) (factorial n))))
          (+ term (cos-series x (- terms u1)))
        )
      )
  )
)

;; Tangent function
(define-read-only (tan (angle uint))
  (begin
    (let ((sin-value (sin angle))
          (cos-value (cos angle)))
      (asserts! (> cos-value u0) (err 14010))
      (/ sin-value cos-value)
    )
  )
)

;; Arc sine
(define-read-only (asin (value uint))
  (begin
    (asserts! (>= value (- PRECISION)) (err 14011))
    (asserts! (<= value PRECISION) (err 14012))
    
    (asin-iter value u0 (/ PI u2) u15)
  )
)

;; Helper function for arcsin iteration
(define-private (asin-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((sin-guess (sin guess)))
        (let ((new-guess (- guess (/ (- value sin-guess) (cos guess)))))
          (asin-iter value new-guess (- iterations u1))
        )
      )
  )
)

;; Arc cosine
(define-read-only (acos (value uint))
  (begin
    (asserts! (>= value (- PRECISION)) (err 14013))
    (asserts! (<= value PRECISION) (err 14014))
    
    (acos-iter value (/ PI u2) u15)
  )
)

;; Helper function for arccos iteration
(define-private (acos-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((cos-guess (cos guess)))
        (let ((new-guess (+ guess (/ (- value cos-guess) (sin guess)))))
          (acos-iter value new-guess (- iterations u1))
        )
      )
  )
)

;; Arc tangent
(define-read-only (atan (value uint))
  (begin
    (atan-iter value u0 u10)
  )
)

;; Helper function for arctan iteration
(define-private (atan-iter (value uint) (guess uint) (iterations uint))
  (if (is-eq iterations u0)
      guess
      (let ((tan-guess (tan guess)))
        (let ((new-guess (- guess (/ (- value tan-guess) (+ u1 (* value tan-guess))))))
          (atan-iter value new-guess (- iterations u1))
        )
      )
  )
)

;; Hyperbolic functions

;; Hyperbolic sine
(define-read-only (sinh (value uint))
  (/ (- (exp value) (exp (- value))) u2)
)

;; Hyperbolic cosine
(define-read-only (cosh (value uint))
  (/ (+ (exp value) (exp (- value))) u2)
)

;; Hyperbolic tangent
(define-read-only (tanh (value uint))
  (/ (sinh value) (cosh value))
)

;; Inverse hyperbolic functions

;; Inverse hyperbolic sine
(define-read-only (asinh (value uint))
  (ln (+ value (sqrt (+ (* value value) PRECISION)))
)

;; Inverse hyperbolic cosine
(define-read-only (acosh (value uint))
  (ln (+ value (sqrt (- (* value value) PRECISION))))
)

;; Inverse hyperbolic tangent
(define-read-only (atanh (value uint))
  (/ (ln (+ u1 value)) (ln (- u1 value)))
)

;; Statistical functions

;; Mean calculation
(define-read-only (mean (values (list 20 uint)))
  (begin
    (asserts! (> (len values) u0) (err 14015))
    (/ (fold values u0 +) (len values))
  )
)

;; Median calculation
(define-read-only (median (values (list 20 uint)))
  (begin
    (asserts! (> (len values) u0) (err 14016))
    (let ((sorted-values (sort-values values)))
      (let ((len (len sorted-values)))
        (if (is-eq (mod len u2) u0)
            ;; Even number of values - average of middle two
            (/ (+ (get sorted-values (/ len u2)) (get sorted-values (- (/ len u2) u1))) u2)
            ;; Odd number of values - middle value
            (get sorted-values (/ len u2))
        )
      )
    )
  )
)

;; Helper function to sort values (simplified)
(define-private (sort-values (values (list 20 uint)))
  (begin
    ;; Simplified sorting - would need proper implementation
    values
  )
)

;; Variance calculation
(define-read-only (variance (values (list 20 uint)))
  (begin
    (asserts! (> (len values) u0) (err 14017))
    
    (let ((mean-value (mean values)))
      (/ (fold values u0
        (lambda ((sum uint) (value uint))
          (+ sum (* (- value mean-value) (- value mean-value)))
        )
      ) (len values))
    )
  )
)

;; Standard deviation
(define-read-only (standard-deviation (values (list 20 uint)))
  (sqrt-newton (variance values) u10)
)

;; Geometric mean
(define-read-only (geometric-mean (values (list 20 uint)))
  (begin
    (asserts! (> (len values) u0) (err 14018))
    
    (let ((product (fold values u1 *)))
      (nth-root product (len values))
    )
  )
)

;; Harmonic mean
(define-read-only (harmonic-mean (values (list 20 uint)))
  (begin
    (asserts! (> (len values) u0) (err 14019))
    
    (let ((sum-reciprocal (fold values u0
        (lambda ((sum uint) (value uint))
          (+ sum (/ PRECISION value))
        )
      )))
      (/ (* (len values) PRECISION) sum-reciprocal)
    )
  )
)

;; Factorial function
(define-read-only (factorial (n uint))
  (if (<= n u1)
      u1
      (* n (factorial (- n u1)))
  )
)

;; Binomial coefficient
(define-read-only (binomial (n uint) (k uint))
  (begin
    (asserts! (>= n k) (err 14020))
    
    (if (or (is-eq k u0) (is-eq k n))
        u1
        (/ (factorial n) (* (factorial k) (factorial (- n k))))
  )
  )
)

;; Permutations
(define-read-only (permutations (n uint))
  (factorial n)
)

;; Combinations
(define-read-only (combinations (n uint) (k uint))
  (begin
    (asserts! (>= n k) (err 14021))
    (/ (factorial n) (* (factorial k) (factorial (- n k))))
  )
)

;; Fibonacci sequence
(define-read-only (fibonacci (n uint))
  (if (<= n u1)
      n
      (+ (fibonacci (- n u1)) (fibonacci (- n u2)))
  )
)

;; Lucas numbers
(define-read-only (lucas (n uint))
  (if (<= n u1)
      u2
      (+ (lucas (- n u1)) (lucas (- n u2)))
  )
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

;; Prime checking (simplified)
(define-read-only (is-prime (n uint))
  (begin
    (asserts! (> n u1) (err 14022))
    
    (if (<= n u3)
        (or (is-eq n u2) (is-eq n u3))
        (let ((max-divisor (sqrt-newton n u5)))
          (not (has-divisor n max-divisor))
        )
    )
  )
)

;; Helper function to check for divisors
(define-private (has-divisor (n uint) (max-divisor uint))
  (fold (range u2 (+ max-divisor u1)) false
    (lambda ((has-divisor uint) (divisor uint))
      (or has-divisor (is-eq (mod n divisor) u0))
    )
  )
)

;; Power series sum
(define-read-only (power-series-sum (coefficients (list 20 uint)) (x uint) (terms uint))
  (begin
    (asserts! (<= terms (len coefficients)) (err 14023))
    
    (fold (range u0 terms) u0
      (lambda ((sum uint) (i uint))
        (+ sum (* (get coefficients i) (pow x i)))
      )
    )
  )
)

;; Arithmetic-geometric series sum
(define-read-only (arithmetic-geometric-sum (a uint) (d uint) (r uint) (n uint))
  (begin
    (asserts! (> n u0) (err 14024))
    (asserts! (! (is-eq r u1)) (err 14025))
    
    (if (is-eq r u1)
        ;; Arithmetic series only
        (/ (* n (* (+ a a (* (- n u1) d))) u2)
        ;; Arithmetic-geometric series
        (/ (* a (- (* r n) u1)) (- r u1))
    )
  )
)

;; Helper function for logical not
(define-private (not (value bool))
  (if value false true)
)
