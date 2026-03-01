;; opex-vault.clar
(define-constant ERR_UNAUTHORIZED u1000)
(define-public (deposit (token principal) (amount uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)
