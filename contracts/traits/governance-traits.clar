;; governance-traits.clar
;; Standard traits for Conxian Governance

(define-trait proposal-trait (
  (execute
    (principal)
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
    (principal principal)
    (balance uint)
    (response uint uint)
  )
  (update-activity-score
    (principal principal)
    (response bool uint)
  )
))
