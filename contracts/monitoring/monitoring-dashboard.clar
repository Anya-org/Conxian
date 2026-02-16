;; monitoring-dashboard.clar
;; Real-time Health Monitoring for Conxian Protocol
;; Consolidates Risk Agent, Protocol Registry, and Financial Metrics

(define-read-only (get-system-status)
  (let (
    (protocol-status (match (contract-call? .conxian-protocol get-protocol-status) status status { paused: true, compliant: false, tenure-id: none, version: "C4", timestamp: u0 }))
    (risk-intel (contract-call? .agent-risk get-cybernetic-intel))
    (is-paused (get paused protocol-status))
    (risk-score (get health-score risk-intel))
  )
    (if is-paused
      (ok "PAUSED")
      (if (>= risk-score u5000)
        (ok "CRISIS")
        (if (>= risk-score u2000)
          (ok "DEFENSIVE")
          (ok "HEALTHY")
        )
      )
    )
  )
)

(define-read-only (get-detailed-health)
  (let (
    (protocol-status (match (contract-call? .conxian-protocol get-protocol-status) status status { paused: true, compliant: false, tenure-id: none, version: "C4", timestamp: u0 }))
    (risk-intel (contract-call? .agent-risk get-cybernetic-intel))
    (financial-metrics (match (contract-call? .finance-metrics get-protocol-metrics) metrics metrics { total-value-locked: u0, cxd-total-supply: u0, timestamp: u0 }))
  )
    (ok {
      protocol-status: protocol-status,
      cybernetic-intel: risk-intel,
      financial-metrics: financial-metrics,
      timestamp: burn-block-height
    })
  )
)

;; @desc Returns a boolean indicating if the system is in a healthy state.
(define-read-only (is-system-healthy)
  (let (
    (status (unwrap-panic (get-system-status)))
  )
    (ok (is-eq status "HEALTHY"))
  )
)
