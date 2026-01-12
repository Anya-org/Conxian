;; dao-treasury.clar
;; Central Treasury for Conxian DAO
;; Implements standard vault traits for compatibility

(impl-trait .traits.vault-traits .vault-trait)
(use-trait sip-010-trait .traits.sip-standards .sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))

;; Data Vars
(define-data-var owner principal tx-sender)

;; Authorization
(define-read-only (is-owner)
    (is-eq tx-sender (var-get owner))
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set owner new-owner)
        (ok true)
    )
)

;; Vault Trait Implementation
(define-public (deposit (amount uint) (token <sip-010-trait>))
    (contract-call? token transfer amount tx-sender (as-contract tx-sender) none)
)

(define-public (withdraw (amount uint) (token <sip-010-trait>))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (as-contract (contract-call? token transfer amount tx-sender (var-get owner) none))
    )
)

(define-read-only (get-balance (token <sip-010-trait>))
    (contract-call? token get-balance (as-contract tx-sender))
)

;; Additional Treasury Functions
(define-public (withdraw-to (amount uint) (token <sip-010-trait>) (recipient principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (as-contract (contract-call? token transfer amount tx-sender recipient none))
    )
)
