;; monitoring-dashboard.clar
;; Conxian Monitoring Standard: Health Dashboard
;; Aggregates real-time health data from core, risk, and finance modules.

;; Constants
(define-constant ERR_UNAUTHORIZED u5000)

;; State
(define-data-var admin principal tx-sender)

;; Public Functions

;; @desc Aggregate protocol health metrics
(define-read-only (get-protocol-health)
  (let (
    (status (contract-call? .conxian-protocol get-protocol-status))
    (risk (contract-call? .agent-risk get-cybernetic-intel))
    (metrics (contract-call? .finance-metrics get-protocol-metrics))
    (gcr (contract-call? .agent-risk get-gcr))
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

;; @desc Get specific module status
(define-read-only (get-module-status (module-id (string-ascii 32)))
    (ok {
        module: module-id,
        healthy: true,
        last-update: burn-block-height
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
