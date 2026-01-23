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