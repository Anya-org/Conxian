;; cxd-staking.clar
(define-constant ERR_NON_COMPLIANT u8001)

;; @desc Stake CXD tokens to earn protocol yield
(define-public (stake (amount uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok true)
  )
)
