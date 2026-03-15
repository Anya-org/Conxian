;; oracle-aggregator.clar
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map asset-registry principal { tier: uint  is-yield-bearing: bool })
(define-public (register-asset (asset principal) (tier uint) (is-yield-bearing bool))
  (begin (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err u1000)) (map-set asset-registry asset { tier: tier  is-yield-bearing: is-yield-bearing }) (ok true))
)
(define-read-only (get-price (asset principal)) (ok u100000000))
(define-read-only (get-asset-info (asset principal)) (ok (map-get? asset-registry asset)))
