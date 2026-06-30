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

(define-constant TIMELOCK_DELAY u144) ;; 24 hours in blocks (Clarity 4 standard)

;; Data Vars
(define-data-var owner principal tx-sender)
(define-data-var pending-owner (optional principal) none)
(define-data-var transfer-delay-end uint u0)
(define-data-var contract-address principal (as-contract tx-sender))

;; Authorization
(define-read-only (is-owner)
    (is-eq tx-sender (var-get owner))
)

;; Ownership Timelock Functions

;; @desc Initiates the transfer of contract ownership.
;; @param new-owner: The new owner principal.
;; @return (response bool uint)
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
;; @return (response bool uint)
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

;; Vault Trait Implementation

;; @desc Deposits tokens into the treasury.
;; @param amount: The amount to deposit.
;; @param token: The SIP-010 token being deposited.
;; @return (response bool uint)
(define-public (deposit (amount uint) (token <sip-010-trait>))
    (contract-call? token transfer amount tx-sender (as-contract tx-sender) none)
)

;; @desc Withdraws tokens from the treasury to the owner.
;; @param amount: The amount to withdraw.
;; @param token: The SIP-010 token being withdrawn.
;; @return (response bool uint)
(define-public (withdraw (amount uint) (token <sip-010-trait>))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (as-contract (contract-call? token transfer amount tx-sender (var-get owner) none))
    )
)

;; @desc Returns the balance of a token held by the treasury.
;; @param token: The SIP-010 token.
;; @return (response uint uint)
(define-public (get-balance (token <sip-010-trait>))
    (contract-call? token get-balance (var-get contract-address))
)

;; Additional Treasury Functions

;; @desc Withdraws tokens from the treasury to a specific recipient.
;; @param amount: The amount to withdraw.
;; @param token: The SIP-010 token.
;; @param recipient: The recipient principal.
;; @return (response bool uint)
(define-public (withdraw-to (amount uint) (token <sip-010-trait>) (recipient principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (as-contract (contract-call? token transfer amount tx-sender recipient none))
    )
)

;; Vault Trait Implementation - allocate-to-strategy
(define-map strategy-allocations principal uint)
(define-data-var total-allocated uint u0)

;; @desc Allocates treasury funds to a specific strategy.
;; @param strategy: The strategy contract principal.
;; @param amount: The amount to allocate.
;; @return (response bool uint)
(define-public (allocate-to-strategy (strategy principal) (amount uint))
    (let (
        (current-allocation (default-to u0 (map-get? strategy-allocations strategy)))
        (new-allocation (+ current-allocation amount))
    )
        (begin
            (asserts! (is-owner) (err ERR_UNAUTHORIZED))
            (map-set strategy-allocations strategy new-allocation)
            (var-set total-allocated (+ (var-get total-allocated) amount))
            (print {
                event: "strategy-allocated",
                strategy: strategy,
                amount: amount,
                new-total: new-allocation,
                total-allocated: (var-get total-allocated)
            })
            (ok true)
        )
    )
)

;; @desc Get allocation for a specific strategy
;; @param strategy: The strategy contract principal.
;; @return (response uint uint)
(define-read-only (get-strategy-allocation (strategy principal))
    (ok (default-to u0 (map-get? strategy-allocations strategy)))
)

;; @desc Get total allocated across all strategies
;; @return (response uint uint)
(define-read-only (get-total-allocated)
    (ok (var-get total-allocated))
)

;; @desc Deallocate from a strategy
;; @param strategy: The strategy contract principal.
;; @param amount: The amount to deallocate.
;; @return (response bool uint)
(define-public (deallocate-from-strategy (strategy principal) (amount uint))
    (let (
        (current-allocation (default-to u0 (map-get? strategy-allocations strategy)))
    )
        (begin
            (asserts! (is-owner) (err ERR_UNAUTHORIZED))
            (asserts! (>= current-allocation amount) (err ERR_INSUFFICIENT_BALANCE))
            (map-set strategy-allocations strategy (- current-allocation amount))
            (var-set total-allocated (- (var-get total-allocated) amount))
            (print {
                event: "strategy-deallocated",
                strategy: strategy,
                amount: amount,
                remaining: (- current-allocation amount)
            })
            (ok true)
        )
    )
)

;; @desc Finalizes a withdrawal process.
;; @return (response bool uint)
(define-public (complete-withdrawal)
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (ok true)
    )
)
