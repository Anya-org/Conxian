;; community-voting-engine.clar
(define-constant ERR_NON_COMPLIANT u2001)
(define-public (create-proposal (start-time uint) (end-time uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok u1)
  )
)
