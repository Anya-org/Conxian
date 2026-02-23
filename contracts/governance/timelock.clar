;; timelock.clar
;; Conxian Protocol Standard Contract

;; timelock.clar
;; Time-delayed execution controller for critical protocol changes
;; Aligned with Nakamoto 5s block times
;; Decentralized: Uses Unified RBAC via .conxian-access
;;
;; REPAIRED: Added proper proposal execution, admin transfer, and sovereign handoff support

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant MIN_DELAY u100) ;; 100 blocks minimum (~500s)
(define-constant MAX_DELAY u10000) ;; 10000 blocks maximum
(define-constant GRACE_PERIOD u1000) ;; 1000 blocks grace period
(define-constant ERR_NOT_QUEUED u1000)
(define-constant ERR_INVALID_DELAY u1001)
(define-constant ERR_TOO_EARLY u1002)
(define-constant ERR_EXPIRED u1003)
(define-constant ERR_UNAUTHORIZED u1004)
(define-constant ERR_ALREADY_EXECUTED u1005)
(define-constant ERR_EXECUTION_FAILED u1006)

;; Roles from conxian-access
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_GOVERNANCE u2)

;; State
(define-data-var delay uint u1000)
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var governance-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Queued proposals: principal -> {eta, executed}
(define-map queued-proposals
    principal
    {
        eta: uint,
        executed: bool,
        target: principal
    }
)

;; Events
(define-private (emit-queued (proposal principal) (eta uint) (target principal))
    (print {
        event: "proposal-queued",
        proposal: proposal,
        eta: eta,
        target: target,
        timestamp: burn-block-height
    })
)

(define-private (emit-executed (proposal principal) (target principal))
    (print {
        event: "proposal-executed",
        proposal: proposal,
        target: target,
        timestamp: burn-block-height
    })
)

(define-private (emit-cancelled (proposal principal))
    (print {
        event: "proposal-cancelled",
        proposal: proposal,
        timestamp: burn-block-height
    })
)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

(define-private (is-governance)
    (or 
        (is-admin)
        (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_GOVERNANCE))
    )
)

;; Governance Configuration

;; @desc Set governance contract
;; @returns (response bool uint)
(define-public (set-governance-contract (new-governance principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set governance-contract new-governance)
        (ok true)
    )
)

;; Proposal Management

;; @desc Queue proposal
;; @returns (response bool uint)
(define-public (queue-proposal (proposal-principal principal) (target principal))
    (begin
        (asserts! (is-governance) (err ERR_UNAUTHORIZED))
        ;; Check not already queued
        (asserts! (is-none (map-get? queued-proposals proposal-principal)) (err ERR_ALREADY_EXECUTED))
        
        (let ((eta (+ burn-block-height (var-get delay))))
            (map-set queued-proposals proposal-principal {
                eta: eta,
                executed: false,
                target: target
            })
            (emit-queued proposal-principal eta target)
            (ok eta)
        )
    )
)

;; Execute Proposal - Can be called by anyone once timelock expires (permissionless execution)

;; @desc Execute proposal
;; @returns (response bool uint)
(define-public (execute-proposal (proposal-principal principal) (proposal-contract <proposal-trait>))
    (let (
        (proposal (unwrap! (map-get? queued-proposals proposal-principal) (err ERR_NOT_QUEUED)))
        (eta (get eta proposal))
        (executed (get executed proposal))
        (target (get target proposal))
    )
        ;; Checks
        (asserts! (not executed) (err ERR_ALREADY_EXECUTED))
        (asserts! (>= burn-block-height eta) (err ERR_TOO_EARLY))
        (asserts! (<= burn-block-height (+ eta GRACE_PERIOD)) (err ERR_EXPIRED))
        (asserts! (is-eq (contract-of proposal-contract) proposal-principal) (err ERR_UNAUTHORIZED))
        
        ;; Mark as executed BEFORE calling to prevent reentrancy
        (map-set queued-proposals proposal-principal (merge proposal { executed: true }))
        
        ;; Execute the proposal
        (try! (contract-call? proposal-contract execute target))
        
        (emit-executed proposal-principal target)
        (ok true)
    )
)

;; Cancel Proposal - Only governance can cancel

;; @desc Cancel proposal
;; @returns (response bool uint)
(define-public (cancel-proposal (proposal-principal principal))
    (begin
        (asserts! (is-governance) (err ERR_UNAUTHORIZED))
        (asserts! (is-some (map-get? queued-proposals proposal-principal)) (err ERR_NOT_QUEUED))
        
        (map-delete queued-proposals proposal-principal)
        (emit-cancelled proposal-principal)
        (ok true)
    )
)

;; Sovereign Handoff: Transfer admin to another principal (e.g., DAO or new timelock)

;; @desc Transfer admin
;; @returns (response bool uint)
(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set admin new-admin)
        (print {
            event: "admin-transferred",
            old-admin: tx-sender,
            new-admin: new-admin,
            timestamp: burn-block-height
        })
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-delay)
    (ok (var-get delay))
)

(define-read-only (get-admin)
    (var-get admin)
)

(define-read-only (get-proposal-status (proposal principal))
    (map-get? queued-proposals proposal)
)

(define-read-only (is-executable (proposal principal))
    (match (map-get? queued-proposals proposal)
        proposal-data 
        (and 
            (not (get executed proposal-data))
            (>= burn-block-height (get eta proposal-data))
            (<= burn-block-height (+ (get eta proposal-data) GRACE_PERIOD))
        )
        false
    )
)

;; Verify this timelock is ready for sovereign handoff
(define-read-only (is-sovereign-ready)
    {
        admin: (var-get admin),
        has-valid-delay: (and (>= (var-get delay) MIN_DELAY) (<= (var-get delay) MAX_DELAY)),
        governance-contract: (var-get governance-contract),
        timestamp: burn-block-height
    }
)

