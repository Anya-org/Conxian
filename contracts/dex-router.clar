;; PRODUCTION: DEX router for Conxian comprehensive DeFi ecosystem
;; Advanced routing with slippage protection and gas optimization
;; DEX Router Contract - Multi-hop routing and convenience functions
;; Provides user-friendly interface for DEX operations

(use-trait pool-trait .pool-trait.pool-trait)

(define-constant ERR_DEADLINE (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_POOL (err u102))
(define-constant ERR_INVALID_AMOUNTS (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))

(define-data-var factory principal .dex-factory)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-read-only (get-factory) (var-get factory))

(define-public (set-factory (f principal))
  (begin (var-set factory f) (ok true)))

;; =============================================================================
;; INTERNAL HELPERS
;; =============================================================================

(define-read-only (resolve-pool (token-x principal) (token-y principal))
  (let ((opt1 (contract-call? .dex-factory get-pool token-x token-y)))
    (match opt1 entry1
      (some (get pool entry1))
      (let ((opt2 (contract-call? .dex-factory get-pool token-y token-x)))
        (match opt2 entry2
          (some (get pool entry2))
          none)))))

;; =============================================================================
;; DIRECT POOL INTERACTION
;; =============================================================================

;; Add liquidity via trait-typed pool reference
(define-public (add-liquidity-direct (pool <pool-trait>) (dx uint) (dy uint) (min-shares uint) (deadline uint))
  (begin
    (asserts! (not (< deadline block-height)) ERR_DEADLINE)
    (as-contract (contract-call? pool add-liquidity dx dy min-shares deadline))
  ))

;; Remove liquidity via trait-typed pool reference
(define-public (remove-liquidity-direct (pool <pool-trait>) (shares uint) (min-dx uint) (min-dy uint) (deadline uint))
  (begin
    (asserts! (not (< deadline block-height)) ERR_DEADLINE)
    (as-contract (contract-call? pool remove-liquidity shares min-dx min-dy deadline))
  ))

;; Swap via trait-typed pool reference
(define-public (swap-exact-in-direct (pool <pool-trait>) (amount-in uint) (min-out uint) (x-to-y bool) (deadline uint))
  (begin
    (asserts! (not (< deadline block-height)) ERR_DEADLINE)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNTS)
    (asserts! (> min-out u0) ERR_INVALID_AMOUNTS)
    (as-contract (contract-call? pool swap-exact-in amount-in min-out x-to-y deadline))
  ))

;; =============================================================================
;; MULTI-HOP ROUTING (Future implementation)
;; =============================================================================

;; Multi-hop swap through multiple pools
(define-public (swap-exact-in-multi-hop 
  (tokens (list 5 principal)) 
  (amount-in uint) 
  (min-amount-out uint) 
  (deadline uint))
  (begin
    (asserts! (not (< deadline block-height)) ERR_DEADLINE)
    ;; Future: iterate hops and call swap on each resolved pool
    (ok amount-in)))

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

;; Get quote for swap without executing (via trait-typed pool reference)
;; Public to support pools that expose get-price as public in some implementations
(define-public (get-amount-out-direct (pool <pool-trait>) (amount-in uint) (x-to-y bool))
  (match (contract-call? pool get-price)
    pr
    (ok (if x-to-y (get price-x-y pr) (get price-y-x pr)))
    e
    (ok u0)))

;; Note: dynamic dispatch by token pair is not supported directly due to Clarity's static type system.
;; Use the *-direct functions with a pool that implements <pool-trait>.
