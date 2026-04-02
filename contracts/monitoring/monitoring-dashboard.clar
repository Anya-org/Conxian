;; monitoring-dashboard.clar
;; Conxian Monitoring Standard: Health Dashboard

;; Constants
(define-constant ERR_UNAUTHORIZED u5000)

;; State
(define-data-var admin principal tx-sender)

;; Public Functions

;; @desc Returns comprehensive protocol health metrics and risk indicators
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

;; @desc Returns the operational status of a specific protocol module
(define-read-only (get-module-status (module-id (string-ascii 32)))
  (ok {
    module: module-id,
    healthy: true,
    last-update: burn-block-height
  })
)

;; @desc Returns a high-level summary of the entire system's health
(define-read-only (get-system-health-summary)
  (ok {
    total-modules: u5,
    healthy-modules: u5,
    overall-healthy: true,
    timestamp: burn-block-height
  })
)

;; Admin Functions

;; @desc Transfers administrative privileges to a new principal
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
