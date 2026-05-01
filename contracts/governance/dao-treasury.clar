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
(define-data-var owner principal tx-sender)
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
(define-map strategy-allocations principal uint)
(define-data-var total-allocated uint u0)

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
                event: "strategy-allocated", strategy: strategy, amount: amount, new-total: new-allocation, total-allocated: (var-get total-allocated)
            })
            (ok true)
        )
    )
)

;; @desc Get allocation for a specific strategy
(define-read-only (get-strategy-allocation (strategy principal))
    (ok (default-to u0 (map-get? strategy-allocations strategy)))
)

;; @desc Get total allocated across all strategies
(define-read-only (get-total-allocated)
    (ok (var-get total-allocated))
)

;; @desc Deallocate from a strategy
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
                event: "strategy-deallocated", strategy: strategy, amount: amount, remaining: (- current-allocation amount)
            })
            (ok true)
        )
    )
)

(define-public (complete-withdrawal)
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (ok true)
    )
)
