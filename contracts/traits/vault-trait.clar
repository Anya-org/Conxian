;; File: contracts/traits/vault-trait.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-trait vault-trait
  (
    (deposit (uint <sip-010-trait>) (response bool uint))
    (withdraw (uint <sip-010-trait>) (response bool uint))
    (allocate-to-strategy (principal uint) (response bool uint))
  )
)
