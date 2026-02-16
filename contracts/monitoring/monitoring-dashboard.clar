;; monitoring-dashboard.clar
;; Real-time Health Monitor for Conxian Protocol

(define-read-only (get-protocol-health)
  (let (
    (protocol-status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
    (risk-intel (contract-call? .agent-risk get-cybernetic-intel))
  )
    (ok {
      status: protocol-status,
      risk: risk-intel,
      uptime: burn-block-height
    })
  )
)
