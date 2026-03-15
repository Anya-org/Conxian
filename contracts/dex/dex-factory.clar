;; dex-factory.clar
(define-map csf-registry principal { name: (string-ascii 256)  active: bool })
(define-public (register-csf-protocol (protocol principal) (name (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err u1000))
    (map-set csf-registry protocol { name: name  active: true })
    (ok true)
  )
)
(define-read-only (get-csf-protocol (protocol principal)) (ok (map-get? csf-registry protocol)))
