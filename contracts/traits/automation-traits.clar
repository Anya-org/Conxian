;; automation-traits.clar
(define-trait office-job-trait (
  (check-work-needed () (response bool uint))
  (do-work ((buff 2048)) (response bool uint))
))
