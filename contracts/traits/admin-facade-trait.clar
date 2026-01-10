;; admin-facade-trait.clar
(define-trait admin-facade-trait
  (
    (pause-contract (principal) (response bool uint))
    (unpause-contract (principal) (response bool uint))
    (set-role (principal uint bool) (response bool uint))
    (set-rbac-contract (principal) (response bool uint))
  )
)
