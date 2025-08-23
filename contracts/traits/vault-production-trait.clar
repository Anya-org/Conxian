;; Trait representing the production vault interface (token principal variants)
(define-trait vault-production-trait
  (
    (deposit (uint principal) (response uint uint))
    (withdraw (uint principal) (response uint uint))
  )
)
