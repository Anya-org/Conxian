;; office-manager.clar
;; Manages worker registration, payroll funding, and agent authorization.

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1001))

(define-data-var admin principal tx-sender)
(define-data-var payroll-balance uint u0)

(define-map workers principal bool)
(define-map authorized-agents principal bool)

;; @desc Check if a worker is currently active
(define-read-only (is-worker-active (worker principal))
  (default-to false (map-get? workers worker))
)

;; @desc Register a new worker in the office system
(define-public (register-worker (worker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set workers worker true)
    (ok true)
  )
)

;; @desc Add funds to the protocol's payroll pool
(define-public (fund-payroll (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set payroll-balance (+ (var-get payroll-balance) amount))
    (ok true)
  )
)

;; @desc Set the authorization status for a protocol agent
(define-public (set-agent-status (agent principal) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-agents agent active)
    (ok true)
  )
)

;; @desc Get the current balance of the payroll pool
(define-read-only (get-payroll-balance)
  (ok (var-get payroll-balance))
)

;; @desc Check if an agent is authorized by the office manager
(define-read-only (is-agent-authorized (agent principal))
  (default-to false (map-get? authorized-agents agent))
)
