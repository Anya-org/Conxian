;; office-manager.clar
;; "The Payroll" - Coordinates the Office Workers and their incentives.

(impl-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_UNKNOWN_WORKER u1001)
(define-constant ERR_INSUFFICIENT_FUNDS u1002)
(define-constant ERR_INVALID_JOB u1003)
(define-constant ERR_PASSKEY_NOT_SUPPORTED u1004)
(define-constant ERR_OWNER_NOT_SET u1005)

;; Worker Registry
(define-map workers principal bool)
(define-data-var payroll-balance uint u0)
(define-data-var initial-owner principal tx-sender)

;; Authorization
(define-private (is-owner-principal (user principal))
  (match (contract-call? .operational-treasury get-protocol-principal "office-manager-owner")
    owner (is-eq user owner)
    (is-eq user (var-get initial-owner))
  )
)

(define-private (is-owner)
  (is-owner-principal tx-sender)
)

(define-map authorized-agents principal bool)
(define-map roles { user: principal, role: uint } bool)

(define-public (set-agent-status (agent principal) (active bool))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set authorized-agents agent active)
    (ok true)
  )
)

(define-read-only (is-authorized-agent (agent principal))
  (default-to false (map-get? authorized-agents agent))
)

(define-public (register-worker (worker principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set workers worker true)
    (print { event: "worker-registered", worker: worker })
    (ok true)
  )
)

(define-public (remove-worker (worker principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete workers worker)
    (ok true)
  )
)

(define-read-only (is-worker-active (worker principal))
  (default-to false (map-get? workers worker))
)

(define-public (fund-payroll (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set payroll-balance (+ (var-get payroll-balance) amount))
    (print { event: "payroll-funded", amount: amount, new-balance: (var-get payroll-balance) })
    (ok true)
  )
)

(define-public (withdraw-payroll (amount uint))
  (let (
    (owner (match (contract-call? .operational-treasury get-protocol-principal "office-manager-owner") o o (var-get initial-owner)))
  )
    (begin
      (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
      (asserts! (<= amount (var-get payroll-balance)) (err ERR_INSUFFICIENT_FUNDS))
      (try! (as-contract (stx-transfer? amount tx-sender owner)))
      (var-set payroll-balance (- (var-get payroll-balance) amount))
      (ok true)
    )
  )
)

(define-public (payout (worker principal) (amount uint))
  (begin
    (asserts! (is-authorized-agent contract-caller) (err ERR_UNAUTHORIZED))
    (asserts! (is-worker-active worker) (err ERR_UNKNOWN_WORKER))
    (asserts! (<= amount (var-get payroll-balance)) (err ERR_INSUFFICIENT_FUNDS))
    (try! (as-contract (stx-transfer? amount tx-sender worker)))
    (var-set payroll-balance (- (var-get payroll-balance) amount))
    (print { event: "worker-paid", job-contract: contract-caller, worker: worker, amount: amount })
    (ok true)
  )
)

(define-public (has-role (user principal) (role-id uint))
  (ok (or (default-to false (map-get? roles { user: user, role: role-id })) (is-owner-principal user)))
)

(define-public (grant-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set roles { user: user, role: role-id } true)
    (ok true)
  )
)

(define-public (revoke-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete roles { user: user, role: role-id })
    (ok true)
  )
)

(define-public (verify-passkey-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (err ERR_PASSKEY_NOT_SUPPORTED)
)

(define-read-only (is-agent-authorized (agent principal))
  (is-authorized-agent agent)
)
