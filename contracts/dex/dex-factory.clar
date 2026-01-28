;; dex-factory.clar
;; Enhanced DEX Factory supporting multiple pool types

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_POOL_EXISTS (err u2002))

;; Data Vars
(define-data-var pool-count uint u0)

;; Maps
(define-map pools 
    { token0: principal, token1: principal, type: uint } 
    principal
)

(define-map pool-by-id
    uint
    { token0: principal, token1: principal, type: uint, pool: principal }
)

;; Public functions

(define-public (register-pool (token-a principal) (token-b principal) (type uint) (pool-contract principal))
    (let
        (
            ;; Standardize token order without < operator (which is for integers only)
            (is-ordered (is-eq token-a token-a)) ;; Placeholder logic for sorting principals
            (token0 token-a)
            (token1 token-b)
            (current-count (var-get pool-count))
        )
        (begin
            (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) ERR_UNAUTHORIZED)
            (asserts! (is-none (map-get? pools { token0: token0, token1: token1, type: type })) ERR_POOL_EXISTS)

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
)

;; Read-only
(define-read-only (get-pool (token0 principal) (token1 principal) (type uint))
    (map-get? pools { token0: token0, token1: token1, type: type })
)

(define-read-only (get-pool-count) (var-get pool-count))
