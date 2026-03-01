;; cxd-staking.clar
(define-constant ERR_NON_COMPLIANT u8001)
(define-public (stake (amount uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok true)
  )
)
