;; automation-traits.clar
;; Traits for autonomous agents and automation

(define-trait office-job-trait (
    (check-work-needed () (response bool uint))
    (do-work ((buff 2048)) (response bool uint))
))

(define-trait ops-agent-trait (
    (run-fiscal-strategy () (response bool uint))
    (update-pid-rates () (response bool uint))
    (update-volatility-fees () (response uint uint))
))
