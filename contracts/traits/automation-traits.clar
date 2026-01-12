;; automation-traits.clar
;; Traits for Automation Systems (Keepers, etc.)

(define-trait office-job-trait (
  (check-work-needed
    ()
    (response bool uint)
  )
  (do-work
    ((buff 2048))
    (response bool uint)
  )
))

(define-trait executable-trait (
  (execute
    ()
    (response bool uint)
  )
))
