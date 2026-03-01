;; community-dao.clar
(define-constant ERR_NON_COMPLIANT u1005)
(define-public (create-proposal (title (string-ascii 64)) (description (string-ascii 256)) (token principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok u1)
  )
)
