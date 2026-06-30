;; price-stability-monitor.clar
;; Monitors CXD peg stability and PID health

(use-trait finance-metrics-trait .security-monitoring.finance-metrics-trait)

(define-public (check-peg-status (metrics-ref <finance-metrics-trait>))
  (let (
    (intel (unwrap-panic (contract-call? .agent-risk get-cybernetic-intel)))
    (pid-fee (get operational-fee intel))
    (gcr (get financial-gcr intel))
  )
    (ok {
      stable: (and (<= pid-fee u500) (>= gcr u130)),
      pid-fee: pid-fee,
      gcr: gcr,
      metrics-ref: (contract-of metrics-ref)
    })
  )
)
