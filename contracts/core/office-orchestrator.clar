;; office-manager.clar
;; Manages worker registration payroll funding and agent authorization.

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1001))

(define-data-var admin principal tx-sender)
(define-data-var payroll-balance uint u0)

(define-map workers principal bool)
(define-map authorized-agents principal bool)

(define-read-only (is-worker-active (worker principal))
  (default-to false (map-get? workers worker))
)

(define-public (register-worker (worker principal))
  (begin
    (asserts! (is-standard? worker) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set workers worker true)
    (ok true)
  )
)

(define-public (fund-payroll (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set payroll-balance (+ (var-get payroll-balance) amount))
    (ok true)
  )
)

(define-public (set-agent-status (agent principal) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-agents agent active)
    (ok true)
  )
)

(define-read-only (get-payroll-balance)
  (ok (var-get payroll-balance))
)

(define-read-only (is-agent-authorized (agent principal))
  (default-to false (map-get? authorized-agents agent))
)
