;; route-manager.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(define-constant ERR_NON_COMPLIANT u2003)
(define-public (swap-route (amount-in uint) (amount-out-min uint) (token-in <sip-010-trait>) (token-out <sip-010-trait>) (route (list 5 principal)))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok true)
  )
)
