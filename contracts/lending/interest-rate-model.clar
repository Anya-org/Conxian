;; interest-rate-model.clar
;; Mathematical curves for interest rate calculations
;; Conxian Protocol Standard Contract

;; @desc Get the borrow rate for a given utilization level.
;; @param utilization: The market utilization in basis points (0-10000).
;; @returns (response uint uint)
(define-read-only (get-borrow-rate (utilization uint)) (ok u1000))

;; @desc Get the supply rate for a given utilization level.
;; @param utilization: The market utilization in basis points (0-10000).
;; @returns (response uint uint)
(define-read-only (get-supply-rate (utilization uint)) (ok u800))
