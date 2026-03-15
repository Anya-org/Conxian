;; security-monitoring.clar
(define-trait circuit-breaker-trait (
  (is-contract-paused (principal) (response bool uint))
  (toggle-contract-pause (principal) (response bool uint))
))
