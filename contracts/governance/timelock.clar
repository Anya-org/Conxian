;; timelock.clar
;; Time-delayed execution controller for critical protocol changes
;; Aligned with Nakamoto 5s block times
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait proposal-trait .traits.proposal-trait)

;; Constants
(define-constant MIN_DELAY u17280) ;; 1 day (at 5s/block)
(define-constant MAX_DELAY u241920) ;; 14 days (at 5s/block)
(define-constant GRACE_PERIOD u120960) ;; 7 days (at 5s/block)

;; Errors
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_DELAY (err u1001))
(define-constant ERR_NOT_QUEUED (err u1002))
(define-constant ERR_ALREADY_QUEUED (err u1003))
(define-constant ERR_TOO_EARLY (err u1004))
(define-constant ERR_EXPIRED (err u1005))

;; Roles from conxian-access
(define-constant ROLE_ADMIN u1)

;; State
(define-map queued-proposals
    principal ;; proposal contract address
    uint ;; eta
)

(define-data-var delay uint MIN_DELAY)

;; Governance
(define-public (set-delay (new-delay uint))
    (begin
        (asserts! (is-eq tx-sender (contract-of .conxian-access)) ERR_UNAUTHORIZED)
        (asserts! (>= new-delay MIN_DELAY) ERR_INVALID_DELAY)
        (asserts! (<= new-delay MAX_DELAY) ERR_INVALID_DELAY)
        (var-set delay new-delay)
        (ok true)
    )
)

(define-public (queue (proposal-principal principal))
    (let
      (
        (eta (+ block-height (var-get delay)))
      )
        (asserts! (is-none (map-get? queued-proposals proposal-principal)) ERR_ALREADY_QUEUED)
        (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_ADMIN)) ERR_UNAUTHORIZED)
        (map-set queued-proposals proposal-principal eta)
        (print { event: "queue", proposal: proposal-principal, eta: eta })
        (ok eta)
    )
)

(define-public (execute (proposal <proposal-trait>))
    (let (
        (proposal-principal (contract-of proposal))
        (queued-eta (unwrap! (map-get? queued-proposals proposal-principal) ERR_NOT_QUEUED))
    )
        (asserts! (>= block-height queued-eta) ERR_TOO_EARLY)
        (asserts! (<= block-height (+ queued-eta GRACE_PERIOD)) ERR_EXPIRED)

        (map-delete queued-proposals proposal-principal)
        
        ;; Execute as the Timelock Contract
        ;; This sets 'tx-sender' to .timelock in the proposal execution context
        (as-contract (contract-call? proposal execute tx-sender))
    )
)

(define-read-only (get-delay)
    (ok (var-get delay))
)

(define-read-only (get-eta (proposal principal))
    (map-get? queued-proposals proposal)
)
