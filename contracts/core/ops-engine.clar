;; ops-engine.clar
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-public (trigger-epoch-update) (begin (asserts! (is-eq tx-sender (var-get admin)) (err u1000)) (ok true)))
