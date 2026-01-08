;; Comparison Helpers Library
;; Provides utility functions for comparing values in Clarity

(define-public (is-greater-than (a uint) (b uint))
  (begin
    (asserts! (> a b) (err 100))
    (ok true)
  )
)

(define-public (is-less-than (a uint) (b uint))
  (begin
    (asserts! (< a b) (err 101))
    (ok true)
  )
)

(define-public (is-equal (a uint) (b uint))
  (begin
    (asserts! (is-eq a b) (err 102))
    (ok true)
  )
)

(define-public (is-greater-or-equal (a uint) (b uint))
  (begin
    (asserts! (>= a b) (err 103))
    (ok true)
  )
)

(define-public (is-less-or-equal (a uint) (b uint))
  (begin
    (asserts! (<= a b) (err 104))
    (ok true)
  )
)

(define-public (max-value (a uint) (b uint))
  (if (> a b) a b)
)

(define-public (min-value (a uint) (b uint))
  (if (< a b) a b)
)

(define-public (clamp (value uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (<= min-val max-val) (err 105))
    (if (< value min-val) 
        min-val
        (if (> value max-val) max-val value))
  )
)

(define-public (is-in-range (value uint) (min-val uint) (max-val uint))
  (and (>= value min-val) (<= value max-val))
)

(define-public (percentage-of (value uint) (percentage uint))
  (/ (* value percentage) u10000)
)

(define-public (is-within-percentage (value uint) (target uint) (percent-tolerance uint))
  (let 
    ((tolerance (percentage-of target percent-tolerance))
     (diff (if (> value target) (- value target) (- target value))))
    (<= diff tolerance)
  )
)
