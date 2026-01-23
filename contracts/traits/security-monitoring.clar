;; security-monitoring.clar
;; Centralized trait for security monitoring and circuit breaker functionality

(define-trait circuit-breaker-trait
  (
    (is-circuit-breaker-active () (response bool uint))
    (trigger-circuit-breaker () (response bool uint))
    (reset-circuit-breaker () (response bool uint))
    (get-circuit-breaker-status () (response { active: bool, last-triggered: uint, trigger-count: uint } uint))
  )
)
