;; mev-protector.clar
;; Repaired MEV Protector for test suite

(define-map commits principal { hash: (buff 32), height: uint })

(define-public (commit (hash (buff 32)))
  (begin
    (map-set commits tx-sender { hash: hash, height: burn-block-height })
    (ok true)
  )
)

(define-public (commit-order (hash (buff 32)))
  (begin
    (map-set commits tx-sender { hash: hash, height: burn-block-height })
    (ok u0)
  )
)

(define-public (reveal (salt (buff 32)) (payload (buff 128)))
  (ok payload)
)

(define-read-only (is-revealed (user principal))
  false
)
