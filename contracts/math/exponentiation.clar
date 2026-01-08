;; Exponentiation Library
;; Mathematical functions for exponentiation and power calculations

;; Basic exponentiation
(define-read-only (pow-base (base uint) (exponent uint))
  (pow base exponent)
)

;; Fast exponentiation using binary exponentiation
(define-read-only (fast-pow (base uint) (exponent uint))
  (begin
    (asserts! (>= base u0) (err 7001))
    (asserts! (>= exponent u0) (err 7002))
    
    (if (is-eq exponent u0)
        u1
        (if (is-eq (mod exponent u2) u0)
            ;; Even exponent
            (let ((half-power (fast-pow base (/ exponent u2))))
              (* half-power half-power)
            )
            ;; Odd exponent
            (* base (fast-pow base (- exponent u1)))
        )
    )
  )
)

;; Power of 2
(define-read-only (pow2 (exponent uint))
  (begin
    (asserts! (>= exponent u0) (err 7003))
    (if (is-eq exponent u0)
        u1
        (* u2 (pow2 (- exponent u1)))
    )
  )
)

;; Power of 10
(define-read-only (pow10 (exponent uint))
  (begin
    (asserts! (>= exponent u0) (err 7004))
    (if (is-eq exponent u0)
        u1
        (* u10 (pow10 (- exponent u1)))
    )
  )
)

;; Square function
(define-read-only (square (value uint))
  (* value value)
)

;; Cube function
(define-read-only (cube (value uint))
  (* (* value value) value)
)

;; Fourth power
(define-read-only (pow4 (value uint))
  (square (square value))
)

;; Eighth power
(define-read-only (pow8 (value uint))
  (pow4 (pow4 value))
)

;; Sixteenth power
(define-read-only (pow16 (value uint))
  (pow8 (pow8 value))
)

;; Power with modulus
(define-read-only (pow-mod (base uint) (exponent uint) (modulus uint))
  (begin
    (asserts! (> modulus u0) (err 7005))
    (asserts! (>= base u0) (err 7006))
    (asserts! (>= exponent u0) (err 7007))
    
    (if (is-eq exponent u0)
        u1
        (if (is-eq (mod exponent u2) u0)
            ;; Even exponent
            (let ((half-power (pow-mod base (/ exponent u2) modulus)))
              (mod (* half-power half-power) modulus)
            )
            ;; Odd exponent
            (mod (* base (pow-mod base (- exponent u1) modulus)) modulus)
        )
    )
  )
)

;; Exponential function (e^x approximation)
(define-read-only (exp-approx (x uint) (terms uint))
  (begin
    (asserts! (> terms u0) (err 7008))
    (asserts! (<= terms u20) (err 7009)) ;; Limit terms for performance
    
    ;; Taylor series approximation: e^x = 1 + x + x^2/2! + x^3/3! + ...
    (let ((result (fold (range u1 (+ terms u1)) u1
      (lambda ((sum uint) (n uint))
        (+ sum (/ (fast-pow x n) (factorial n)))
      ))))
      result
    )
  )
)

;; Natural logarithm approximation
(define-read-only (log-approx (value uint) (iterations uint))
  (begin
    (asserts! (> value u0) (err 7010))
    (asserts! (> iterations u0) (err 7011))
    
    ;; Newton's method for ln(value)
    (let ((initial-guess (/ value u2)))
      (fold (range u0 iterations) initial-guess
        (lambda ((guess uint) (i uint))
          (+ guess (- (/ (- value (exp-approx guess u10)) (exp-approx guess u10))))
        )
      )
    )
  )
)

;; Log base 2 approximation
(define-read-only (log2-approx (value uint))
  (begin
    (asserts! (> value u0) (err 7012))
    
    ;; Use change of base formula: log2(x) = ln(x) / ln(2)
    (/ (log-approx value u5) (log-approx u2 u5))
  )
)

;; Log base 10 approximation
(define-read-only (log10-approx (value uint))
  (begin
    (asserts! (> value u0) (err 7013))
    
    ;; Use change of base formula: log10(x) = ln(x) / ln(10)
    (/ (log-approx value u5) (log-approx u10 u5))
  )
)

;; Root calculations
(define-read-only (nth-root (value uint) (n uint))
  (begin
    (asserts! (> value u0) (err 7014))
    (asserts! (> n u0) (err 7015))
    
    ;; Newton's method for nth root
    (let ((initial-guess (/ value n)))
      (fold (range u0 u10) initial-guess
        (lambda ((guess uint) (i uint))
          (+ guess (/ (- (/ value (fast-pow guess (- n u1))) guess) n))
        )
      )
    )
  )
)

;; Square root
(define-read-only (square-root (value uint))
  (nth-root value u2)
)

;; Cube root
(define-read-only (cube-root (value uint))
  (nth-root value u3)
)

;; Fourth root
(define-read-only (fourth-root (value uint))
  (nth-root value u4)
)

;; Helper function: factorial
(define-private (factorial (n uint))
  (if (<= n u1)
      u1
      (* n (factorial (- n u1)))
  )
)

;; Geometric progression
(define-read-only (geometric-sum (first-term uint) (ratio uint) (terms uint))
  (begin
    (asserts! (> terms u0) (err 7016))
    
    (if (is-eq ratio u1)
        (* first-term terms)
        (/ (* first-term (- (fast-pow ratio terms) u1)) (- ratio u1))
    )
  )
)

;; Geometric mean
(define-read-only (geometric-mean (values (list 10 uint)))
  (begin
    (asserts! (> (len values) u0) (err 7017))
    
    (let ((product (fold values u1 *)))
      (nth-root product (len values))
    )
  )
)

;; Compound interest calculation
(define-read-only (compound-interest (principal uint) (rate uint) (periods uint) (compound-frequency uint))
  (begin
    (asserts! (> principal u0) (err 7018))
    (asserts! (> rate u0) (err 7019))
    (asserts! (> periods u0) (err 7020))
    (asserts! (> compound-frequency u0) (err 7021))
    
    (let ((effective-rate (/ rate compound-frequency))
          (total-periods (* periods compound-frequency)))
      (* principal (fast-pow (+ u1 effective-rate) total-periods))
    )
  )
)

;; Continuous compound interest
(define-read-only (continuous-compound (principal uint) (rate uint) (periods uint))
  (begin
    (asserts! (> principal u0) (err 7022))
    (asserts! (> rate u0) (err 7023))
    (asserts! (> periods u0) (err 7024))
    
    (* principal (exp-approx (/ (* rate periods) u10000) u10))
  )
)

;; Present value calculation
(define-read-only (present-value (future-value uint) (rate uint) (periods uint))
  (begin
    (asserts! (> future-value u0) (err 7025))
    (asserts! (> rate u0) (err 7026))
    (asserts! (> periods u0) (err 7027))
    
    (/ future-value (fast-pow (+ u1 rate) periods))
  )
)

;; Future value calculation
(define-read-only (future-value (present-value uint) (rate uint) (periods uint))
  (begin
    (asserts! (> present-value u0) (err 7028))
    (asserts! (> rate u0) (err 7029))
    (asserts! (> periods u0) (err 7030))
    
    (* present-value (fast-pow (+ u1 rate) periods))
  )
)

;; Annuity present value
(define-read-only (annuity-present-value (payment uint) (rate uint) (periods uint))
  (begin
    (asserts! (> payment u0) (err 7031))
    (asserts! (> rate u0) (err 7032))
    (asserts! (> periods u0) (err 7033))
    
    (* payment (/ (- u1 (/ u1 (fast-pow (+ u1 rate) periods))) rate))
  )
)

;; Annuity future value
(define-read-only (annuity-future-value (payment uint) (rate uint) (periods uint))
  (begin
    (asserts! (> payment u0) (err 7034))
    (asserts! (> rate u0) (err 7035))
    (asserts! (> periods u0) (err 7036))
    
    (* payment (/ (- (fast-pow (+ u1 rate) periods) u1) rate))
  )
)

;; Power series sum
(define-read-only (power-series-sum (coefficients (list 10 uint)) (x uint) (terms uint))
  (begin
    (asserts! (> terms u0) (err 7037))
    (asserts! (<= terms (len coefficients)) (err 7038))
    
    (fold (range u0 terms) u0
      (lambda ((sum uint) (n uint))
        (+ sum (* (get coefficients n) (fast-pow x n)))
      )
    )
  )
)

;; Binomial coefficient (simplified)
(define-read-only (binomial-coefficient (n uint) (k uint))
  (begin
    (asserts! (>= n k) (err 7039))
    
    (if (or (is-eq k u0) (is-eq k n))
        u1
        (/ (factorial n) (* (factorial k) (factorial (- n k))))
    )
  )
)

;; Power with validation
(define-public (safe-pow (base uint) (exponent uint) (max-result uint))
  (begin
    (asserts! (>= base u0) ERR_INVALID_AMOUNT)
    (asserts! (>= exponent u0) ERR_INVALID_AMOUNT)
    
    (let ((result (fast-pow base exponent)))
      (asserts! (<= result max-result) ERR_INVALID_AMOUNT)
      (ok result)
    )
  )
)
