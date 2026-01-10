;; File: contracts/traits/vault-trait.clar
(define-trait vault-trait
  (
    (deposit (uint principal) (response uint uint))
    (withdraw (uint principal) (response uint uint))
  )
)
