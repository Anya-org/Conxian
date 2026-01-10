;; timelock.clar
;; Time-delayed execution controller for critical protocol changes
;; Aligned with Nakamoto 5s block times
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant MIN_DELAY u100) ;; 100 blocks minimum
(define-constant MAX_DELAY u10000) ;; 10000 blocks maximum
(define-constant GRACE_PERIOD u1000) ;; 1000 blocks grace period
(define-constant ERR_NOT_QUEUED (err u1000))
(define-constant ERR_INVALID_DELAY (err u1001))
(define-constant ERR_TOO_EARLY (err u1002))
(define-constant ERR_EXPIRED (err u1003))
(define-constant ERR_UNAUTHORIZED (err u1004))

;; Roles from conxian-access
(define-constant ROLE_ADMIN u1)

;; State
(define-data-var delay uint u1000)
(define-data-var admin principal tx-sender)

(define-map queued-proposals
    principal ;; proposal contract address
    uint ;; eta
)

;; Governance
(define-public (set-delay (new-delay uint))
    (begin
        (asserts! (>= new-delay MIN_DELAY) ERR_INVALID_DELAY)
        (asserts! (<= new-delay MAX_DELAY) ERR_INVALID_DELAY)
        (var-set delay new-delay)
        (ok true)
    )
)

(define-public (queue-proposal (proposal-principal principal) (target principal))
    (begin
        ;; Only Admin/Governance can queue
        (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_ADMIN)) ERR_UNAUTHORIZED)
        (let ((eta (+ block-height (var-get delay))))
            (map-set queued-proposals proposal-principal eta)
            (print {
                event: "queue",
                proposal: proposal-principal,
                eta: eta,
            })
(ok eta)
        )
    )
)

(define-public (execute-proposal (proposal-principal principal))
    (let (
        (queued-eta (unwrap! (map-get? queued-proposals proposal-principal) ERR_NOT_QUEUED))
    )
        (asserts! (>= block-height queued-eta) ERR_TOO_EARLY)
        (asserts! (<= block-height (+ queued-eta GRACE_PERIOD)) ERR_EXPIRED)

        (map-delete queued-proposals proposal-principal)
        
        (begin
            (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
            
            (as-contract (contract-call? proposal-principal execute tx-sender))
        )
        (ok true)
    )
)

(define-read-only (get-delay)
    (ok (var-get delay))
)

(define-read-only (get-eta (proposal principal))
    (map-get? queued-proposals proposal)
)

