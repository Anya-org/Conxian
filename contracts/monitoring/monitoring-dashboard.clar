;; monitoring-dashboard.clar
;; Conxian Monitoring Standard: Health Dashboard

;; Constants
(define-constant ERR_UNAUTHORIZED u5000)

;; State
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

;; Public Functions

(define-read-only (get-protocol-health)
  (let (
    (status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
    (risk (unwrap-panic (contract-call? .agent-risk get-cybernetic-intel)))
    (metrics (unwrap-panic (contract-call? .finance-metrics get-protocol-metrics)))
    (gcr (unwrap-panic (contract-call? .agent-risk get-gcr)))
  )
    (ok {
        status: status,
        risk: risk,
        metrics: metrics,
        gcr: gcr,
        uptime: burn-block-height
    })
  )
)

(define-read-only (get-module-status (module-id (string-ascii 32)))
  (ok {
    module: module-id,
    healthy: true,
    last-update: burn-block-height
  })
)

(define-read-only (get-system-health-summary)
  (ok {
    total-modules: u5,
    healthy-modules: u5,
    overall-healthy: true,
    timestamp: burn-block-height
  })
)

;; Admin Functions
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
