;; admin-facade.clar
;; Administrative Facade for RBAC and Emergency Controls
;; COMPATIBILITY MODE

(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_INVALID_OPERATION u1001)
(define-constant ERR_BATCH_LIMIT_EXCEEDED u1002)

;; Role Definitions
(define-constant ROLE_GLOBAL_ADMIN u0)
(define-constant ROLE_EMERGENCY_PAUSE u1)
(define-constant ROLE_PROTOCOL_ADMIN u2)
(define-constant ROLE_TREASURY_ADMIN u3)
(define-constant ROLE_OPERATOR u4)

;; State
(define-data-var rbac-contract principal .conxian-access)
(define-constant CONTRACT_OWNER tx-sender)
;; Default dev admin for simnet/devnet
(define-data-var global-admin principal 'ST3C8EC3V7WPG05Y3C3XAJ2ZDG89B3ZPBXDRQ6BW8)
(define-data-var emergency-pause bool false)
(define-data-var max-batch-size uint u100)

(define-map role-cache { user: principal, role: uint } bool)

;; Helper Functions for Batch Operations
(define-private (execute-role-grant (user principal) (role uint))
  (match (contract-call? .conxian-access grant-role user role)
    success (ok success)
    error (err error)
  )
)

(define-private (execute-role-revoke (user principal) (role uint))
  (match (contract-call? .conxian-access revoke-role user role)
    success (ok success)
    error (err error)
  )
)

(define-private (batch-update-role-helper
    (update { user: principal, role: uint, active: bool })
    (result (response bool uint))
  )
  (match result
    ok-val
    (if (get active update)
      (begin
        (try! (contract-call? .conxian-access grant-role (get user update) (get role update)))
        (map-set role-cache { user: (get user update), role: (get role update) } true)
        (ok true)
      )
      (begin
        (try! (contract-call? .conxian-access revoke-role (get user update) (get role update)))
        (map-delete role-cache { user: (get user update), role: (get role update) })
        (ok true)
      )
    )
    err-val (err err-val)
  )
)

;; Authorization
(define-private (has-role (user principal) (role uint))
  (default-to false (map-get? role-cache { user: user, role: role }))
)

(define-read-only (is-global-admin)
  (or (is-eq tx-sender (var-get global-admin)) (is-eq tx-sender CONTRACT_OWNER))
)

(define-public (is-authorized (role uint))
  (ok (or (is-global-admin) (has-role tx-sender role)))
)

(define-read-only (is-authorized-to-pause (sender principal))
  (or (is-eq sender (var-get global-admin)) (is-eq sender CONTRACT_OWNER)
      (has-role sender ROLE_EMERGENCY_PAUSE))
)

;; Core Functions

(define-public (set-role
    (user principal)
    (role uint)
    (enabled bool)
  )
  (begin
    (asserts! (is-global-admin) (err ERR_NOT_AUTHORIZED))
    (if enabled
      (begin
        (try! (contract-call? .conxian-access grant-role user role))
        (map-set role-cache { user: user, role: role } true)
      )
      (begin
        (try! (contract-call? .conxian-access revoke-role user role))
        (map-delete role-cache { user: user, role: role })
      )
    )
    (ok true)
  )
)

;; Batch Role Management
(define-public (batch-update-roles (updates (list 100 {
  user: principal,
  role: uint,
  active: bool,
})))
  (begin
    (asserts! (is-global-admin) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= (len updates) (var-get max-batch-size)) (err ERR_BATCH_LIMIT_EXCEEDED))
    (fold batch-update-role-helper updates (ok true))
  )
)

(define-public (set-global-admin (new-admin principal))
  (begin
    (asserts! (is-global-admin) (err ERR_NOT_AUTHORIZED))
    (var-set global-admin new-admin)
    (ok true)
  )
)

(define-public (set-emergency-pause (paused bool))
  (begin
    (asserts! (is-authorized-to-pause tx-sender) (err ERR_NOT_AUTHORIZED))
    (var-set emergency-pause paused)
    (print { event: "emergency-pause", paused: paused, sender: tx-sender, block: burn-block-height })
    (ok true)
  )
)
