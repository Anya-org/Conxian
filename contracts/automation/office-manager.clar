;; office-manager.clar
;; "The Payroll" - Coordinates the Office Workers and their incentives.
;; Verifies registered workers and handles payment for completed jobs.

(impl-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_UNKNOWN_WORKER u1001)
(define-constant ERR_INSUFFICIENT_FUNDS u1002)
(define-constant ERR_INVALID_JOB u1003)

;; State
(define-data-var contract-owner principal tx-sender)

;; Worker Registry
;; Maps worker principal to their active status
(define-map workers principal bool)

;; Payroll Balance
;; Total funds available for paying workers (in uSTX for now, can be generic)
(define-data-var payroll-balance uint u0)

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Authorization check for Agents (The Staff)
;; Only whitelisted agents can trigger payouts
(define-map authorized-agents principal bool)

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

;; --- Worker Management ---

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

;; --- Payroll Management ---

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

(define-public (withdraw-payroll (amount uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (<= amount (var-get payroll-balance)) (err ERR_INSUFFICIENT_FUNDS))
    (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
    (var-set payroll-balance (- (var-get payroll-balance) amount))
    (ok true)
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
      job-contract: tx-sender,
      worker: worker,
      amount: amount
    })
    (ok true)
  )
)

;; --- RBAC Trait Implementation ---

(define-public (has-role (user principal) (role-id uint))
  (ok (is-owner)) ;; Simplified implementation for office-manager
)

(define-public (grant-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-public (revoke-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-public (verify-passkey-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok true)
)
