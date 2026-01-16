;; dex-factory-v2.clar
;; Enhanced DEX Factory supporting multiple pool types
;; Implements registration and discovery of pools

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_POOL_TYPE (err u2001))
(define-constant ERR_POOL_EXISTS (err u2002))
(define-constant ERR_INVALID_PAIR (err u2003))

;; Pool Types
(define-constant POOL_TYPE_CONSTANT_PRODUCT u1)
(define-constant POOL_TYPE_STABLE_SWAP u2)
(define-constant POOL_TYPE_CONCENTRATED u3)

;; Data vars
(define-data-var contract-owner principal tx-sender)

;; Map of pool details
;; Key: { token0, token1, type } -> Value: pool-contract
(define-map pools 
    { token0: principal, token1: principal, type: uint } 
    principal
)

;; Map of all pools list for discovery
(define-map pool-by-id
    uint
    { token0: principal, token1: principal, type: uint, pool: principal }
)

(define-data-var pool-count uint u0)

;; Read-only functions

(define-read-only (get-pool (token0 principal) (token1 principal) (type uint))
    (map-get? pools { token0: token0, token1: token1, type: type })
)

(define-read-only (get-pool-count)
    (var-get pool-count)
)

(define-read-only (get-pool-by-id (id uint))
    (map-get? pool-by-id id)
)

;; Public functions

(define-public (register-pool 
    (token-a principal) 
    (token-b principal) 
    (type uint) 
    (pool-contract principal))
    
    (let
        (
            (token0 (if (is-less-than token-a token-b) token-a token-b))
            (token1 (if (is-less-than token-a token-b) token-b token-a))
            (current-count (var-get pool-count))
        )
        ;; Check authorization (only owner or whitelisted factories can register)
        ;; For now, simplified to owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        
        ;; Check if pool exists
        (asserts! (is-none (map-get? pools { token0: token0, token1: token1, type: type })) ERR_POOL_EXISTS)
        
        ;; Register pool
        (map-set pools { token0: token0, token1: token1, type: type } pool-contract)
        (map-set pool-by-id (+ current-count u1) {
            token0: token0,
            token1: token1,
            type: type,
            pool: pool-contract
        })
        (var-set pool-count (+ current-count u1))
        
        (ok true)
    )
)

(define-private (is-less-than (a principal) (b principal))
    (let (
        (buff-a (unwrap-panic (to-consensus-buff? a)))
        (buff-b (unwrap-panic (to-consensus-buff? b)))
    )
        (if (is-eq buff-a buff-b)
            false
            (< (buff-to-uint-be (unwrap-panic (slice? buff-a u0 u16))) (buff-to-uint-be (unwrap-panic (slice? buff-b u0 u16))))
        )
    )
)
