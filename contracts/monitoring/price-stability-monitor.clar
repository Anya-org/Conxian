;; price-stability-monitor.clar
;; Monitors CXD peg stability and PID health

(define-read-only (check-peg-status)
  (let (
    (intel (unwrap-panic (contract-call? .agent-risk get-cybernetic-intel)))
    (pid-fee (get operational-fee intel))
    (gcr (get financial-gcr intel))
  )
    (ok {
      stable: (and (<= pid-fee u500) (>= gcr u130)),
      pid-fee: pid-fee,
      gcr: gcr,
      timestamp: burn-block-height
    })
  )
)
