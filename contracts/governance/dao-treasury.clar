;; dao-treasury.clar
;; Central Treasury for Conxian DAO
;; Implements standard vault traits for compatibility

(impl-trait .vault-traits.vault-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)
(define-constant ERR_TIMELOCK_ACTIVE u1002)
(define-constant ERR_NO_PENDING_OWNER u1003)

(define-constant TIMELOCK_DELAY u86400) ;; 24 hours in seconds (Clarity 4 burn-block-height)

;; Data Vars
(define-data-var owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var pending-owner (optional principal) none)
(define-data-var transfer-delay-end uint u0)

;; Authorization
(define-read-only (is-owner)
    (is-eq tx-sender (var-get owner))
)

;; Ownership Timelock Functions

;; @desc Initiates the transfer of contract ownership.
;; @param new-owner principal
(define-public (request-ownership-transfer (new-owner principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set pending-owner (some new-owner))
        (var-set transfer-delay-end (+ burn-block-height TIMELOCK_DELAY))
        (print { event: "ownership-transfer-requested", new-owner: new-owner, delay-end: (var-get transfer-delay-end) })
        (ok true)
    )
)

;; @desc Completes the transfer of contract ownership after the timelock expires.
(define-public (claim-ownership)
    (let (
        (new-owner (unwrap! (var-get pending-owner) (err ERR_NO_PENDING_OWNER)))
    )
        (asserts! (is-eq tx-sender new-owner) (err ERR_UNAUTHORIZED))
        (asserts! (>= burn-block-height (var-get transfer-delay-end)) (err ERR_TIMELOCK_ACTIVE))
        (var-set owner new-owner)
        (var-set pending-owner none)
        (var-set transfer-delay-end u0)
        (print { event: "ownership-transfer-completed", new-owner: new-owner })
        (ok true)
    )
)

;; @desc Legacy setter for compatibility (now restricted)
(define-public (set-owner (new-owner principal))
    (request-ownership-transfer new-owner)
)

;; Vault Trait Implementation
(define-public (deposit (amount uint) (token <sip-010-trait>))
    (contract-call? token transfer amount tx-sender (as-contract tx-sender) none)
)

(define-public (withdraw (amount uint) (token <sip-010-trait>))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (as-contract (contract-call? token transfer amount tx-sender (var-get owner) none))
    )
)

(define-public (get-balance (token <sip-010-trait>))
    (ok (contract-call? token get-balance (as-contract tx-sender)))
)

;; Additional Treasury Functions
(define-public (withdraw-to (amount uint) (token <sip-010-trait>) (recipient principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (as-contract (contract-call? token transfer amount tx-sender recipient none))
    )
)

;; Vault Trait Implementation - allocate-to-strategy
(define-public (allocate-to-strategy (strategy principal) (amount uint))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        ;; Placeholder for strategy allocation logic
        (ok true)
    )
)

(define-public (complete-withdrawal)
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        ;; Placeholder for withdrawal completion logic
        (ok true)
    )
)
