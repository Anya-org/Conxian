;; @desc Get the borrow rate for a given utilization level
(define-read-only (get-borrow-rate (utilization uint)) (ok u1000))
;; @desc Get the supply rate for a given utilization level
(define-read-only (get-supply-rate (utilization uint)) (ok u800))
