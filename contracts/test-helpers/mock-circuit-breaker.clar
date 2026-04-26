;; mock-circuit-breaker.clar
(impl-trait .sip-standards.simple-circuit-breaker-trait)

(define-data-var admin principal tx-sender)
(define-data-var circuit-open bool false)

(define-public (set-circuit-open (open bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u8000))
    (var-set circuit-open open)
    (ok true)
  )
)

(define-read-only (is-circuit-open)
  (ok (var-get circuit-open))
)
