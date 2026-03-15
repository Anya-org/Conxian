;; circuit-breaker.clar
;; Conxian Security: Circuit Breaker
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(impl-trait .security-monitoring.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u7000))

(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map paused-contracts principal bool)

(define-read-only (is-contract-paused (target principal))
  (ok (default-to false (map-get? paused-contracts target)))
)

(define-public (toggle-contract-pause (target principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? paused-contracts target))))
      (map-set paused-contracts target (not current))
      (ok (not current))
    )
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
