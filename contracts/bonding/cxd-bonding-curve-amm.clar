;; cxd-bonding-curve-amm.clar
(define-constant ERR_NON_COMPLIANT u1002)
(define-public (buy (amount-cxd uint) (max-spend-stx uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok true)
  )
)
