;; bme-engine.clar
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map authorized-activity-reporters principal bool)
(define-public (add-activity-reporter (reporter principal))
  (begin (asserts! (is-eq tx-sender (var-get admin)) (err u1000)) (map-set authorized-activity-reporters reporter true) (ok true))
)
(define-public (register-fee-activity (pool principal) (amount uint))
  (begin (asserts! (default-to false (map-get? authorized-activity-reporters contract-caller)) (err u1000)) (ok true))
)
