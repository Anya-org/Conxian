;; office-manager.clar
;; "The Payroll" - Coordinates the Office Workers and their incentives.
;; Verifies registered workers and handles payment for completed jobs.
;; Remediated April 2026: Dynamic contract-owner fetching

(impl-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_UNKNOWN_WORKER u1001)
(define-constant ERR_INSUFFICIENT_FUNDS u1002)
(define-constant ERR_INVALID_JOB u1003)
(define-constant ERR_PASSKEY_NOT_SUPPORTED u1004)
(define-constant ERR_OWNER_NOT_SET u1005)

;; Worker Registry
;; Maps worker principal to their active status
(define-map workers principal bool)

;; Payroll Balance
;; Total funds available for paying workers (in uSTX for now, can be generic)
(define-data-var payroll-balance uint u0)

;; Authorization
(define-private (is-owner)
  (match (contract-call? .operational-treasury get-protocol-principal "office-manager-owner")
    owner (is-eq tx-sender owner)
    false
  )
)

;; Authorization check for Agents (The Staff)
;; Only whitelisted agents can trigger payouts
(define-map authorized-agents principal bool)

;; Roles
(define-map roles { user: principal, role: uint } bool)

;; @desc Updates the authorization status of an agent. Owner only.
;; @param agent: The principal of the agent to update.
;; @param active: The active status to set.
(define-public (set-agent-status (agent principal) (active bool))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set authorized-agents agent active)
    (ok true)
  )
)

;; @desc Checks if an agent is authorized to trigger payouts.
;; @param agent: The principal of the agent to check.
(define-read-only (is-authorized-agent (agent principal))
  (default-to false (map-get? authorized-agents agent))
)

;; --- Worker Management ---

;; @desc Registers a new worker in the payroll system. Owner only.
;; @param worker: The principal of the worker to register.
(define-public (register-worker (worker principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set workers worker true)
    (print {
      event: "worker-registered",
      worker: worker
    })
    (ok true)
  )
)

;; @desc Removes a worker from the payroll system. Owner only.
;; @param worker: The principal of the worker to remove.
(define-public (remove-worker (worker principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete workers worker)
    (ok true)
  )
)

;; @desc Checks if a worker is currently active in the registry.
;; @param worker: The principal of the worker to check.
(define-read-only (is-worker-active (worker principal))
  (default-to false (map-get? workers worker))
)

;; --- Payroll Management ---

;; @desc Deposits STX into the payroll balance for future worker payments.
;; @param amount: The amount of STX to deposit.
(define-public (fund-payroll (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set payroll-balance (+ (var-get payroll-balance) amount))
    (print {
      event: "payroll-funded",
      amount: amount,
      new-balance: (var-get payroll-balance)
    })
    (ok true)
  )
)

;; @desc Withdraws STX from the payroll balance to the owner's account. Owner only.
;; @param amount: The amount of STX to withdraw.
(define-public (withdraw-payroll (amount uint))
  (match (contract-call? .operational-treasury get-protocol-principal "office-manager-owner")
    owner
      (begin
        (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
        (asserts! (<= amount (var-get payroll-balance)) (err ERR_INSUFFICIENT_FUNDS))
        (try! (as-contract (stx-transfer? amount tx-sender owner)))
        (var-set payroll-balance (- (var-get payroll-balance) amount))
        (ok true)
      )
    (err ERR_OWNER_NOT_SET)
  )
)

;; --- Payout Execution ---

;; @desc Called by an Authorized Agent (Staff) to pay the Worker who did the job.
;; @param worker: The address of the off-chain worker (tx-sender of the transaction usually)
;; @param amount: The fee to pay the worker
(define-public (payout (worker principal) (amount uint))
  (begin
    ;; 1. Caller must be an Authorized Agent (e.g., agent-risk)
    (asserts! (is-authorized-agent contract-caller) (err ERR_UNAUTHORIZED))

    ;; 2. Worker must be registered
    (asserts! (is-worker-active worker) (err ERR_UNKNOWN_WORKER))

    ;; 3. Check funds
    (asserts! (<= amount (var-get payroll-balance)) (err ERR_INSUFFICIENT_FUNDS))

    ;; 4. Transfer funds to Worker
    (try! (as-contract (stx-transfer? amount tx-sender worker)))

    ;; 5. Update Balance
    (var-set payroll-balance (- (var-get payroll-balance) amount))

    (print {
      event: "worker-paid",
      job-contract: contract-caller,
      tx-sender: tx-sender,
      worker: worker,
      amount: amount
    })
    (ok true)
  )
)

;; --- RBAC Trait Implementation ---

;; @desc Checks if a user has a specific role.
;; @param user: The principal to check.
;; @param role-id: The ID of the role to verify.
(define-public (has-role (user principal) (role-id uint))
  (ok
    (or
      (match (contract-call? .operational-treasury get-protocol-principal "office-manager-owner")
        owner (is-eq user owner)
        false
      )
      (default-to false (map-get? roles { user: user, role: role-id }))
    )
  )
)

;; @desc Grants a role to a user. Owner only.
;; @param user: The principal to grant the role to.
;; @param role-id: The ID of the role to grant.
;; @param message: Authorization message.
;; @param signature: Authorization signature.
;; @param public-key: Authorized public key.
(define-public (grant-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set roles { user: user, role: role-id } true)
    (ok true)
  )
)

;; @desc Revokes a role from a user. Owner only.
;; @param user: The principal to revoke the role from.
;; @param role-id: The ID of the role to revoke.
;; @param message: Authorization message.
;; @param signature: Authorization signature.
;; @param public-key: Authorized public key.
(define-public (revoke-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete roles { user: user, role: role-id })
    (ok true)
  )
)

;; @desc Verifies a passkey/biometric signature.
;; @param message: Authorization message.
;; @param signature: Authorization signature.
;; @param public-key: Authorized public key.
;; @note Passkey/WebAuthn verification is not supported directly in Clarity today.
;;       This returns (err ERR_PASSKEY_NOT_SUPPORTED) so callers cannot treat it as an authorization primitive.
(define-public (verify-passkey-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (err ERR_PASSKEY_NOT_SUPPORTED)
)
