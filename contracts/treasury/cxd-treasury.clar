;; cxd-treasury.clar
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-public (withdraw-stx (amount uint) (recipient principal))
  (begin (asserts! (is-eq tx-sender (var-get admin)) (err u1000)) (as-contract (stx-transfer? amount tx-sender recipient)))
)
