;; Trait for admin calls on enhanced-caller
(define-trait enhanced-caller-admin-trait
  (
    (authorize-contract (principal bool) (response bool uint))
  )
)
