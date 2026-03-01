;; sbtc-vault.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(define-constant ERR_NON_COMPLIANT u2003)
(define-public (deposit (token <sip-010-trait>) (amount uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (ok true)
  )
)
