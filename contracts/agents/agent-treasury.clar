;; agent-treasury.clar
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-public (deposit-stx (amount uint)) (stx-transfer? amount tx-sender (as-contract tx-sender)))
