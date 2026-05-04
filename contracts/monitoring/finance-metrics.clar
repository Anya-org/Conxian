;; finance-metrics.clar
;; Conxian Protocol: Core Financial Telemetry and Health Metrics

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var total-value-locked uint u0)
(define-data-var global-collateral-ratio uint u0)
(define-data-var admin principal tx-sender)

(define-read-only (get-tvl) (ok (var-get total-value-locked)))
(define-read-only (get-protocol-tvl) (ok (var-get total-value-locked)))
(define-read-only (get-gcr) (ok (var-get global-collateral-ratio)))

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", tvl: (var-get total-value-locked) gcr: (var-get global-collateral-ratio) })
)

(define-public (update-metrics (new-tvl uint) (new-gcr uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set total-value-locked new-tvl)
    (var-set global-collateral-ratio new-gcr)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
