;; monitoring-dashboard.clar
;; Real-time Health Monitoring for Conxian Protocol
;; Consolidates Risk Agent and Protocol Registry status

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
  (ok {
    protocol-status: (match (contract-call? .conxian-protocol get-protocol-status) status status { paused: true, compliant: false, tenure-id: none, version: "C4", timestamp: u0 }),
    cybernetic-intel: (contract-call? .agent-risk get-cybernetic-intel),
    timestamp: burn-block-height
  })
)
