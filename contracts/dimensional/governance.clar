;; Standard Governance Contract
(define-data-var proposal-count uint u0)
(define-public (propose) (begin (var-set proposal-count (+ (var-get proposal-count) u1)) (ok (var-get proposal-count))))
