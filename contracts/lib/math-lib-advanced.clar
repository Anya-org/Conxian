;; Math Library - Advanced Functions
(use-trait math .math-utilities.math-utilities-trait)

(define-constant ERR_INVALID_VALUE (err 101))
(define-constant ERR_INVALID_WEIGHT (err 102))

(define-read-only (weighted-average (data (list 10 { value: uint, weight: uint })))
  (let ((total-value (fold (map-d data (lambda (entry) (* (get entry value) (get entry weight)))) (var-set total-value u0) +))
        (total-weight (fold (map-d data (lambda (entry) (get entry weight))) (var-set total-weight u0) +)))
    (asserts! (> total-weight u0) ERR_INVALID_WEIGHT)
    (/ total-value total-weight)
  )
)
