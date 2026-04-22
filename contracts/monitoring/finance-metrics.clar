;; finance-metrics.clar
;; Unified protocol telemetry and health metrics
(impl-trait .security-monitoring.finance-metrics-trait)

(define-data-var mock-tvl uint u1000000)
(define-data-var mock-gcr uint u150)
(define-data-var mock-active-positions uint u10)
(define-data-var mock-volume uint u50000)

(define-read-only (get-protocol-tvl) (ok (var-get mock-tvl)))
(define-read-only (get-protocol-gcr) (ok (var-get mock-gcr)))
(define-read-only (get-protocol-metrics)
  (ok {
    tvl: (var-get mock-tvl),
    solvency-ratio: (var-get mock-gcr),
    active-positions: (var-get mock-active-positions),
    volume-24h: (var-get mock-volume)
  })
)
(define-read-only (get-protocol-status) (ok { compliant: true }))

;; Mock setters for testing
(define-public (set-mock-tvl (new-tvl uint))
  (begin
    (var-set mock-tvl new-tvl)
    (ok true)
  )
)

(define-public (set-mock-gcr (new-gcr uint))
  (begin
    (var-set mock-gcr new-gcr)
    (ok true)
  )
)
