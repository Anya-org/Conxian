;; =============================================================================
;; MULTI-HOP ROUTER V2 - ADVANCED ROUTING WITH OPTIMIZATION
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
(use-trait pool-trait .pool-trait.pool-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_ROUTE (err u401))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u402))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u403))
(define-constant ERR_EXPIRED (err u404))
(define-constant ERR_INVALID_POOLS (err u405))
(define-constant ERR_INVALID_PATH (err u406))

;; Constants
(define-constant MAX_HOPS u4) ;; Maximum number of hops in a route
(define-constant FEE_TIER_0_05 u5) ;; 0.05%
(define-constant FEE_TIER_0_3 u30) ;; 0.3%
(define-constant FEE_TIER_1_0 u100) ;; 1.0%

;; State variables
(define-data-var contract-owner principal tx-sender)
(define-data-var protocol-fee-bps uint u0)

;; Route registry
(define-map routes
  {token-in: principal, token-out: principal}
  {
    pools: (list 4 principal),
    pool-types: (list 4 (string-ascii 20)),
    estimated-gas: uint,
    active: bool
  })

;; Pool registry for routing
(define-map pool-registry
  principal
  {
    token-a: principal,
    token-b: principal,
    pool-type: (string-ascii 20),
    fee-tier: uint,
    active: bool
  })

;; Fee tier configurations
(define-map fee-tier-config
  uint
  {
    fee-bps: uint,
    active: bool
  })

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; =============================================================================
;; CORE ROUTING FUNCTIONS
;; =============================================================================

;; Execute exact input multi-hop swap
(define-public (swap-exact-in-multi-hop
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-in uint)
  (min-amount-out uint)
  (deadline uint))
  (begin
    (asserts! (< block-height deadline) ERR_EXPIRED)
    (asserts! (> amount-in u0) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (and (>= (len path) u2) (<= (len path) u5)) ERR_INVALID_PATH)
    (asserts! (is-eq (len pools) (- (len path) u1)) ERR_INVALID_POOLS)
    
    ;; Execute the multi-hop swap
    (let ((result (execute-multi-hop-swap-simple path pools amount-in)))
      (asserts! (>= result min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (ok {amount-out: result}))))

;; Trait-based multi-hop execution over pools
(define-private (execute-multi-hop-swap-simple
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-in uint))
  (let ((initial (ok {i: u0, path: path, current: amount-in})))
    (let ((result (fold process-hop-simple pools initial)))
      (get current (unwrap-panic result)))))

;; Process a single hop via pool-trait.swap-exact-in
(define-private (process-hop-simple
  (pool <pool-trait>)
  (acc (response {i: uint, path: (list 5 principal), current: uint} uint)))
  (let ((state (unwrap-panic acc))
        (pool-principal (contract-of pool))
        (i (get i (unwrap-panic acc)))
        (token-in (unwrap-panic (element-at (get path (unwrap-panic acc)) (get i (unwrap-panic acc)))))
        (token-out (unwrap-panic (element-at (get path (unwrap-panic acc)) (+ (get i (unwrap-panic acc)) u1))))
        (info (unwrap-panic (map-get? pool-registry (contract-of pool)))))
    ;; Validate and determine direction
    (asserts! (or (and (is-eq token-in (get token-a info)) (is-eq token-out (get token-b info)))
                  (and (is-eq token-in (get token-b info)) (is-eq token-out (get token-a info)))) ERR_INVALID_ROUTE)
    (let ((x-to-y (is-eq token-in (get token-a info))))
      (match (contract-call? pool swap-exact-in (get current (unwrap-panic acc)) u0 x-to-y block-height)
        ok-res (ok {i: (+ i u1), path: (get path (unwrap-panic acc)), current: (get amount-out ok-res)})
        err-code (err err-code)))))
;; zip removed; fold operates directly with index tracking

;; =============================================================================
;; ROUTE MANAGEMENT
;; =============================================================================

;; Register a new pool
(define-public (register-pool
  (pool principal)
  (token-a principal)
  (token-b principal)
  (pool-type (string-ascii 20))
  (fee-tier uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set pool-registry pool {
      token-a: token-a,
      token-b: token-b,
      pool-type: pool-type,
      fee-tier: fee-tier,
      active: true
    })
    (ok true)))

;; Register a route
(define-public (register-route
  (token-in principal)
  (token-out principal)
  (pools (list 4 principal))
  (pool-types (list 4 (string-ascii 20))))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set routes {token-in: token-in, token-out: token-out} {
      pools: pools,
      pool-types: pool-types,
      estimated-gas: u1000, ;; Default gas estimate
      active: true
    })
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

;; Get route information
(define-read-only (get-route (token-in principal) (token-out principal))
  (map-get? routes {token-in: token-in, token-out: token-out}))

;; Get pool information
(define-read-only (get-pool-info (pool principal))
  (map-get? pool-registry pool))

;; Calculate output amounts for a path (simplified)
(define-read-only (get-amounts-out-simple
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (if (and (>= (len path) u2) (is-eq (len pools) (- (len path) u1)))
    ;; Calculate amounts without state changes
    (ok amount-in) ;; Simplified for now - just return input amount
    (err ERR_INVALID_PATH)))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-protocol-fee (fee-bps uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (<= fee-bps u1000) ERR_UNAUTHORIZED) ;; Max 10%
    (var-set protocol-fee-bps fee-bps)
    (ok true)))

(define-public (configure-fee-tier (tier uint) (fee-bps uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set fee-tier-config tier {
      fee-bps: fee-bps,
      active: true
    })
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

;; =============================================================================
;; INITIALIZATION
;; =============================================================================

;; Initialize fee tiers
(define-private (init-fee-tiers)
  (begin
    (map-set fee-tier-config FEE_TIER_0_05 {fee-bps: u5, active: true})
    (map-set fee-tier-config FEE_TIER_0_3 {fee-bps: u30, active: true})
    (map-set fee-tier-config FEE_TIER_1_0 {fee-bps: u100, active: true})
    true))

;; Initialize on deployment
(begin (init-fee-tiers))
