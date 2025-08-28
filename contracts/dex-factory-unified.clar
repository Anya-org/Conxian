;; DEX Factory Unified - Consolidates all DEX factory functionality
;; Combines features from dex-factory-enhanced, dex-factory-v2, and dex-factory

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED u2000)
(define-constant ERR_POOL_EXISTS u2001)
(define-constant ERR_INVALID_POOL_TYPE u2002)
(define-constant ERR_INVALID_FEE_TIER u2003)
(define-constant ERR_POOL_NOT_FOUND u2004)
(define-constant ERR_INVALID_PARAMETERS u2005)
(define-constant ERR_TYPE_DISABLED u2006)

;; Constants
(define-constant DEFAULT_FEE_TIER u300) ;; 0.3%
(define-constant MAX_FEE_TIER u10000) ;; 10%

;; Pool types
(define-constant POOL_TYPE_CONSTANT_PRODUCT "constant-product")
(define-constant POOL_TYPE_STABLE "stable")
(define-constant POOL_TYPE_WEIGHTED "weighted")
(define-constant POOL_TYPE_CONCENTRATED "concentrated")

;; Data variables
(define-data-var contract-admin principal tx-sender)
(define-data-var next-pool-id uint u1)
(define-data-var paused bool false)

;; Pool registry
(define-map pools uint {
  pool-contract: principal,
  token-x: principal,
  token-y: principal,
  pool-type: (string-ascii 20),
  fee-tier: uint,
  enabled: bool,
  created-at: uint
})

(define-map pool-lookup {token-x: principal, token-y: principal, pool-type: (string-ascii 20), fee-tier: uint} uint)
(define-map pool-implementations (string-ascii 20) {contract: principal, enabled: bool})
(define-map fee-tiers uint bool)

;; Performance tracking
(define-map pool-metrics uint {
  volume-24h: uint,
  fees-24h: uint,
  liquidity: uint,
  transactions: uint
})

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set contract-admin new-admin)
    (ok true)))

(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set paused false)
    (ok true)))

(define-public (set-pool-implementation (pool-type (string-ascii 20)) (contract-address principal) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (map-set pool-implementations pool-type {contract: contract-address, enabled: enabled})
    (ok true)))

(define-public (set-fee-tier (fee-tier uint) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= fee-tier MAX_FEE_TIER) (err ERR_INVALID_FEE_TIER))
    (map-set fee-tiers fee-tier enabled)
    (ok true)))

;; Core factory functions
(define-public (create-pool-typed 
  (token-x <sip-010-trait>)
  (token-y <sip-010-trait>)
  (pool-type (string-ascii 20))
  (fee-tier uint)
  (optional-params (optional {amplification: uint, weights: (list 8 uint)})))
  (let ((pool-id (var-get next-pool-id))
        (token-x-principal (contract-of token-x))
        (token-y-principal (contract-of token-y))
        (lookup-key {token-x: token-x-principal, token-y: token-y-principal, pool-type: pool-type, fee-tier: fee-tier}))
    
    (asserts! (not (var-get paused)) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-none (map-get? pool-lookup lookup-key)) (err ERR_POOL_EXISTS))
    (asserts! (is-valid-pool-type pool-type) (err ERR_INVALID_POOL_TYPE))
    (asserts! (is-valid-fee-tier fee-tier) (err ERR_INVALID_FEE_TIER))
    (asserts! (is-type-enabled pool-type) (err ERR_TYPE_DISABLED))
    
    ;; Create pool record
    (map-set pools pool-id {
      pool-contract: tx-sender, ;; Placeholder - would be actual pool contract
      token-x: token-x-principal,
      token-y: token-y-principal,
      pool-type: pool-type,
      fee-tier: fee-tier,
      enabled: true,
      created-at: stacks-block-height
    })
    
    ;; Set lookup mapping
    (map-set pool-lookup lookup-key pool-id)
    
    ;; Initialize metrics
    (map-set pool-metrics pool-id {
      volume-24h: u0,
      fees-24h: u0,
      liquidity: u0,
      transactions: u0
    })
    
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)))

;; Legacy compatibility function
(define-public (create-pool 
  (token-x <sip-010-trait>)
  (token-y <sip-010-trait>))
  (create-pool-typed token-x token-y POOL_TYPE_CONSTANT_PRODUCT DEFAULT_FEE_TIER none))

;; Pool lookup functions
(define-public (get-pool 
  (token-x <sip-010-trait>)
  (token-y <sip-010-trait>)
  (pool-type (string-ascii 20))
  (fee-tier uint))
  (let ((lookup-key {token-x: (contract-of token-x), token-y: (contract-of token-y), pool-type: pool-type, fee-tier: fee-tier}))
    (match (map-get? pool-lookup lookup-key)
      pool-id (match (map-get? pools pool-id)
        pool-info (ok (some {pool: (get pool-contract pool-info)}))
        (ok none))
      (ok none))))

;; Legacy two-parameter get-pool function
(define-public (get-pool-legacy
  (token-x <sip-010-trait>)
  (token-y <sip-010-trait>))
  (get-pool token-x token-y POOL_TYPE_CONSTANT_PRODUCT DEFAULT_FEE_TIER))

;; Pool management
(define-public (enable-pool (pool-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (match (map-get? pools pool-id)
      pool-info (begin
        (map-set pools pool-id (merge pool-info {enabled: true}))
        (ok true))
      (err ERR_POOL_NOT_FOUND))))

(define-public (disable-pool (pool-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (match (map-get? pools pool-id)
      pool-info (begin
        (map-set pools pool-id (merge pool-info {enabled: false}))
        (ok true))
      (err ERR_POOL_NOT_FOUND))))

;; Metrics updates
(define-public (update-pool-metrics 
  (pool-id uint)
  (volume-delta uint)
  (fees-delta uint)
  (liquidity-new uint))
  (begin
    (asserts! (is-some (map-get? pools pool-id)) (err ERR_POOL_NOT_FOUND))
    (match (map-get? pool-metrics pool-id)
      current-metrics (begin
        (map-set pool-metrics pool-id {
          volume-24h: (+ (get volume-24h current-metrics) volume-delta),
          fees-24h: (+ (get fees-24h current-metrics) fees-delta),
          liquidity: liquidity-new,
          transactions: (+ (get transactions current-metrics) u1)
        })
        (ok true))
      (err ERR_POOL_NOT_FOUND))))

;; Validation functions
(define-private (is-valid-pool-type (pool-type (string-ascii 20)))
  (or (is-eq pool-type POOL_TYPE_CONSTANT_PRODUCT)
      (is-eq pool-type POOL_TYPE_STABLE)
      (is-eq pool-type POOL_TYPE_WEIGHTED)
      (is-eq pool-type POOL_TYPE_CONCENTRATED)))

(define-private (is-valid-fee-tier (fee-tier uint))
  (default-to false (map-get? fee-tiers fee-tier)))

(define-private (is-type-enabled (pool-type (string-ascii 20)))
  (match (map-get? pool-implementations pool-type)
    impl-info (get enabled impl-info)
    false))

;; Read-only functions
(define-read-only (get-pool-info (pool-id uint))
  (map-get? pools pool-id))

(define-read-only (get-pool-metrics (pool-id uint))
  (map-get? pool-metrics pool-id))

(define-read-only (get-factory-info)
  {
    admin: (var-get contract-admin),
    next-pool-id: (var-get next-pool-id),
    paused: (var-get paused)
  })

(define-read-only (get-pool-implementation (pool-type (string-ascii 20)))
  (map-get? pool-implementations pool-type))

(define-read-only (is-fee-tier-enabled (fee-tier uint))
  (default-to false (map-get? fee-tiers fee-tier)))

;; Initialize default configurations
(map-set fee-tiers u50 true)   ;; 0.05%
(map-set fee-tiers u300 true)  ;; 0.30%
(map-set fee-tiers u1000 true) ;; 1.00%
(map-set fee-tiers u3000 true) ;; 3.00%
(map-set fee-tiers u5000 true) ;; 5.00%

(map-set pool-implementations POOL_TYPE_CONSTANT_PRODUCT {contract: tx-sender, enabled: true})
(map-set pool-implementations POOL_TYPE_STABLE {contract: tx-sender, enabled: true})
(map-set pool-implementations POOL_TYPE_WEIGHTED {contract: tx-sender, enabled: true})
(map-set pool-implementations POOL_TYPE_CONCENTRATED {contract: tx-sender, enabled: false}) ;; Phase 2
