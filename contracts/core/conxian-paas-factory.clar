;; conxian-paas-factory.clar
(define-constant ERR_UNAUTHORIZED u10000)
(define-public (register-new-sab (name (string-ascii 64)) (treasury principal) (gov principal) (tok (optional principal)) (stk (optional principal)))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)
