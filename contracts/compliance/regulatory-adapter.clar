;; regulatory-adapter.clar simplified
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-read-only (check-clean-hands-compliance (user principal))
  true
)
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u6000))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
