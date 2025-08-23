;; Trait for vault initialization (token principal only)
(define-trait vault-init-trait
  (
    (initialize-token (principal) (response bool uint))
  )
)
