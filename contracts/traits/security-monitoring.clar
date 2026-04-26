;; security-monitoring.clar
;; Traits for Security Systems (Circuit Breakers etc.)

(define-trait circuit-breaker-trait (
  (is-contract-paused (principal) (response bool uint))
  (toggle-contract-pause (principal) (response bool uint))
))

(define-trait monitor-trait (
  (report-anomaly (principal (buff 256)) (response bool uint))
))

(define-trait finance-metrics-trait (
  (get-protocol-metrics () (response { tvl: uint solvency-ratio: uint active-positions: uint volume-24h: uint } uint))
  (get-protocol-tvl () (response uint uint))
  (get-protocol-gcr () (response uint uint))
))
