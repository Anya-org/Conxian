;; mock-circuit-breaker.clar
;; Mock circuit breaker for testing oracle-aggregator dynamic circuit breaker logic.
;; Uses push pattern: calls oracle-aggregator.report-circuit-state when state changes.

(define-data-var circuit-open bool false)
(define-data-var admin principal tx-sender)

(define-public (set-circuit-open (open bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u8000))
    (var-set circuit-open open)
    (try! (contract-call? .oracle-aggregator report-circuit-state open))
    (ok open)
  )
)

(define-read-only (is-circuit-open)
  (var-get circuit-open)
)
