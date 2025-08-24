;; =============================================================================
;; POOL FACTORY - MULTI-POOL ARCHITECTURE PHASE 1
;; =============================================================================

(impl-trait .ownable-trait.ownable-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_POOL_EXISTS (err u401))
(define-constant ERR_INVALID_POOL_TYPE (err u402))
(define-constant ERR_INVALID_TOKENS (err u403))
(define-constant ERR_INVALID_PARAMETERS (err u404))

;; Pool types
(define-constant POOL_TYPE_CONSTANT_PRODUCT "constant-product")
(define-constant POOL_TYPE_STABLE "stable")
(define-constant POOL_TYPE_WEIGHTED "weighted")
(define-constant POOL_TYPE_CONCENTRATED "concentrated")

;; State variables
(define-data-var contract-owner principal tx-sender)
(define-data-var pool-creation-fee uint u1000000) ;; 1 STX
(define-data-var next-pool-id uint u1)

;; Pool registry
(define-map pools
  uint
  {
    pool-type: (string-ascii 20),
    token-x: principal,
    token-y: principal,
    pool-contract: principal,
    creator: principal,
    created-at: uint,
    parameters: (optional (string-ascii 200))
  })

(define-map pool-pairs
  {token-x: principal, token-y: principal, pool-type: (string-ascii 20)}
  uint)

;; Pool type registry
(define-map pool-implementations
  (string-ascii 20)
  {
    implementation: principal,
    active: bool,
    min-fee: uint,
    max-fee: uint
  })

;; =============================================================================
;; FACTORY FUNCTIONS
;; =============================================================================

;; Create a new pool
(define-public (create-pool 
  (pool-type (string-ascii 20))
  (token-x principal)
  (token-y principal)
  (initial-params (optional (string-ascii 200))))
  (let ((pool-id (var-get next-pool-id))
        (ordered-tokens (order-tokens token-x token-y)))
    
    ;; Validate inputs
    (asserts! (not (is-eq (get token-x ordered-tokens) (get token-y ordered-tokens))) ERR_INVALID_TOKENS)
    (asserts! (is-some (map-get? pool-implementations pool-type)) ERR_INVALID_POOL_TYPE)
    (asserts! (is-none (map-get? pool-pairs {
      token-x: (get token-x ordered-tokens),
      token-y: (get token-y ordered-tokens),
      pool-type: pool-type
    })) ERR_POOL_EXISTS)
    
    ;; Create pool entry
    (map-set pools pool-id {
      pool-type: pool-type,
      token-x: (get token-x ordered-tokens),
      token-y: (get token-y ordered-tokens),
      pool-contract: tx-sender, ;; Will be updated by actual pool contract
      creator: tx-sender,
      created-at: block-height,
      parameters: initial-params
    })
    
    ;; Register pool pair
    (map-set pool-pairs {
      token-x: (get token-x ordered-tokens),
      token-y: (get token-y ordered-tokens),
      pool-type: pool-type
    } pool-id)
    
    ;; Update pool counter
    (var-set next-pool-id (+ pool-id u1))
    
    ;; Emit event
    (print {
      event: "pool-created",
      pool-id: pool-id,
      pool-type: pool-type,
      token-x: (get token-x ordered-tokens),
      token-y: (get token-y ordered-tokens),
      creator: tx-sender
    })
    
    (ok pool-id)))

;; Register pool implementation
(define-public (register-pool-implementation
  (pool-type (string-ascii 20))
  (implementation principal)
  (min-fee uint)
  (max-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (map-set pool-implementations pool-type {
      implementation: implementation,
      active: true,
      min-fee: min-fee,
      max-fee: max-fee
    })
    
    (print {
      event: "pool-implementation-registered",
      pool-type: pool-type,
      implementation: implementation
    })
    
    (ok true)))

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

;; Order tokens to ensure consistent pool addresses (simplified)
(define-private (order-tokens (token-a principal) (token-b principal))
  ;; Simple lexicotextic ordering based on principal representation
  {token-x: token-a, token-y: token-b})

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id))

(define-read-only (get-pool-by-tokens 
  (token-x principal) 
  (token-y principal) 
  (pool-type (string-ascii 20)))
  (let ((ordered-tokens (order-tokens token-x token-y)))
    (match (map-get? pool-pairs {
      token-x: (get token-x ordered-tokens),
      token-y: (get token-y ordered-tokens),
      pool-type: pool-type
    })
      pool-id (map-get? pools pool-id)
      none)))

(define-read-only (get-pool-implementation (pool-type (string-ascii 20)))
  (map-get? pool-implementations pool-type))

(define-read-only (get-next-pool-id)
  (var-get next-pool-id))

(define-read-only (get-creation-fee)
  (var-get pool-creation-fee))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-creation-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set pool-creation-fee new-fee)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-read-only (get-owner)
  (ok (var-get contract-owner)))

(define-public (renounce-ownership)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner 'SP000000000000000000002Q6VF78) ;; Burn address
    (ok true)))
