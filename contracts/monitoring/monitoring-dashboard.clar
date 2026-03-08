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

;; @desc Get specific module status with real health check
(define-read-only (get-module-status (module-id (string-ascii 32)))
  (let (
    (is-healthy (check-module-health module-id))
  )
    (ok {
      module: module-id,
      healthy: is-healthy,
      last-update: burn-block-height
    })
  )
)

;; @desc Check health of a specific module
(define-private (check-module-health (module-id (string-ascii 32)))
  (if (is-eq module-id "dimensional-core")
    (match (contract-call? .dimensional-core calculate-tvl)
      success true
      err-val false)
  (if (is-eq module-id "risk-manager")
    (match (contract-call? .risk-manager is-liquidatable u0)
      success true
      err-val false)
  (if (is-eq module-id "oracle-aggregator")
    (match (contract-call? .oracle-aggregator get-price .cxd-token)
      success true
      err-val false)
  (if (is-eq module-id "agent-risk")
    (match (contract-call? .agent-risk assess-system-risk)
      success true
      err-val false)
  (if (is-eq module-id "swap-router")
    (match (contract-call? .swap-router get-protocol-status)
      success true
      err-val false)
  ;; Default: unknown module
  false
  ))))))

;; @desc Get overall system health summary
(define-read-only (get-system-health-summary)
  (let (
    (modules (list "dimensional-core" "risk-manager" "oracle-aggregator" "agent-risk" "swap-router"))
  )
    (ok {
      total-modules: u5,
      healthy-modules: (count-healthy-modules modules),
      overall-healthy: (>= (count-healthy-modules modules) u3),
      timestamp: burn-block-height
    })
  )
)

;; @desc Count healthy modules
(define-private (count-healthy-modules (modules (list 5 (string-ascii 32))))
  (let (
    (dimensional-healthy (check-module-health "dimensional-core"))
    (risk-healthy (check-module-health "risk-manager"))
    (oracle-healthy (check-module-health "oracle-aggregator"))
    (agent-healthy (check-module-health "agent-risk"))
    (router-healthy (check-module-health "swap-router"))
  )
    (+ 
      (if dimensional-healthy u1 u0)
      (+ 
        (if risk-healthy u1 u0)
        (+ 
          (if oracle-healthy u1 u0)
          (+ 
            (if agent-healthy u1 u0)
            (if router-healthy u1 u0)
          )
        )
      )
    )
  )
)

;; Admin Functions
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
