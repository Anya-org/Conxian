;; governance-traits.clar
;; Standard traits for Conxian Governance

(define-trait proposal-trait (
  (execute
    (principal)
    (response bool uint)
  )
))

(define-trait proposal-executor-trait (
  (execute
    (uint <proposal-trait> uint)
    (response bool uint)
  )
))

(define-trait voting-trait (
  (vote
    (uint bool)
    (response bool uint)
  )
))

(define-trait reputation-engine-trait (
  (get-weighted-voting-power
    (principal uint)
    (response uint uint)
  )
  (update-activity-score
    (principal)
    (response bool uint)
  )
))
