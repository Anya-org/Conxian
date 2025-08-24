;; =============================================================================
;; MULTI-HOP ROUTER - PHASE 2 IMPLEMENTATION
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
(use-trait pool-trait .pool-trait.pool-trait)

;; Error codes
(define-constant ERR_INVALID_PATH (err u600))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u601))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u602))
(define-constant ERR_INVALID_ROUTE (err u603))
(define-constant ERR_NO_LIQUIDITY (err u604))
(define-constant ERR_EXPIRED (err u605))
(define-constant ERR_UNAUTHORIZED (err u606))

;; Constants
(define-constant MAX_HOPS u5) ;; Maximum number of hops in a route
(define-constant FEE_DENOMINATOR u10000)

;; Route information
(define-map routes
  {token-in: principal, token-out: principal}
  {
    pools: (list 5 principal),
    pool-types: (list 5 (string-ascii 20)),
    estimated-gas: uint,
    active: bool
  })

;; Pool registry for routing
(define-map pool-registry
  principal
  {
    token-x: principal,
    token-y: principal,
    pool-type: (string-ascii 20),
    fee-tier: uint,
    active: bool
  })

;; Fee tier configurations
(define-map fee-tiers
  uint
  {
    fee-bps: uint,
    tick-spacing: uint,
    enabled: bool
  })

;; State variables
(define-data-var router-admin principal tx-sender)
(define-data-var routing-fee-bps uint u0) ;; Router fee in basis points
(define-data-var max-slippage-bps uint u1000) ;; 10% max slippage

;; =============================================================================
;; CORE ROUTING FUNCTIONS
;; =============================================================================

;; Helper and pool execution functions defined before core router to avoid forward references
;; Execute constant product swap (conforms to pool-trait: (swap-exact-in (uint uint bool uint)))
(define-private (execute-cp-swap
  (pool <pool-trait>)
  (amount-in uint)
  (x-to-y bool))
  (match (contract-call? pool swap-exact-in
                         amount-in
                         u0            ;; min-amount-out handled at router level
                         x-to-y
                         block-height) ;; satisfy pool deadline
    success (ok (get amount-out success))
    error ERR_NO_LIQUIDITY))

;; Execute stable swap
(define-private (execute-stable-swap
  (pool <pool-trait>)
  (amount-in uint)
  (x-to-y bool))
  ;; Placeholder - would call stable pool specific function
  (execute-cp-swap pool amount-in x-to-y))

;; Execute weighted swap
(define-private (execute-weighted-swap
  (pool <pool-trait>)
  (amount-in uint)
  (x-to-y bool))
  ;; Placeholder - would call weighted pool specific function
  (execute-cp-swap pool amount-in x-to-y))

;; Execute concentrated liquidity swap
(define-private (execute-concentrated-swap
  (pool <pool-trait>)
  (amount-in uint)
  (x-to-y bool))
  ;; Placeholder - would call concentrated pool specific function
  (execute-cp-swap pool amount-in x-to-y))

;; Execute single hop in the route
(define-private (execute-single-hop
  (token-in principal)
  (token-out principal)
  (pool <pool-trait>)
  (amount-in uint))
  (let ((pool-info (unwrap! (map-get? pool-registry (contract-of pool)) ERR_INVALID_ROUTE)))
    ;; Verify pool tokens match route and derive direction
    (asserts! (or 
                (and (is-eq token-in (get token-x pool-info)) (is-eq token-out (get token-y pool-info)))
                (and (is-eq token-in (get token-y pool-info)) (is-eq token-out (get token-x pool-info))))
              ERR_INVALID_ROUTE)
    (let ((x-to-y (is-eq token-in (get token-x pool-info)))
          (ptype (get pool-type pool-info)))
      ;; Execute swap based on pool type (strings require nested ifs, not match)
      (if (is-eq ptype "constant-product")
        (execute-cp-swap pool amount-in x-to-y)
        (if (is-eq ptype "stable")
          (execute-stable-swap pool amount-in x-to-y)
          (if (is-eq ptype "weighted")
            (execute-weighted-swap pool amount-in x-to-y)
            (if (is-eq ptype "concentrated")
              (execute-concentrated-swap pool amount-in x-to-y)
              ERR_INVALID_ROUTE)))))))

;; Iterative multi-hop executor using fold (no recursion)
(define-private (process-hop-exec
  (pool <pool-trait>)
  (acc (response {i: uint, path: (list 5 principal), current: uint} uint)))
  (let ((state (try! acc))
        (pool-info (unwrap! (map-get? pool-registry (contract-of pool)) ERR_INVALID_ROUTE))
        (token-in (unwrap! (element-at (get path state) (get i state)) ERR_INVALID_PATH))
        (token-out (unwrap! (element-at (get path state) (+ (get i state) u1)) ERR_INVALID_PATH)))
    (let ((x-to-y (is-eq token-in (get token-x pool-info))))
      (match (contract-call? pool swap-exact-in (get current state) u0 x-to-y block-height)
        success (ok {i: (+ (get i state) u1), path: (get path state), current: (get amount-out success)})
        error ERR_NO_LIQUIDITY))))

(define-private (execute-multi-hop-swap
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-in uint))
  (let ((initial (ok {i: u0, path: path, current: amount-in})))
    (let ((result (fold process-hop-exec pools initial)))
      (ok (get current (try! result))))))

;; Calculate required input for exact output (defined before public functions)
(define-private (calculate-required-input
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-out uint))
  ;; Simplified - would implement reverse calculation
  (ok amount-out))

;; Multi-hop swap with exact input
(define-public (swap-exact-in-multi-hop
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-in uint)
  (min-amount-out uint)
  (deadline uint))
  (begin
    (asserts! (>= deadline block-height) ERR_EXPIRED)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (is-eq (len pools) (- (len path) u1)) ERR_INVALID_PATH)
    (asserts! (> amount-in u0) ERR_INVALID_ROUTE)
    
    ;; Execute multi-hop swap
    (let ((final-amount (try! (execute-multi-hop-swap path pools amount-in))))
      (asserts! (>= final-amount min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      
      ;; Emit routing event
      (print {
        event: "multi-hop-swap",
        path: path,
        amount-in: amount-in,
        amount-out: final-amount,
        pools-used: (len pools),
        trader: tx-sender
      })
      
      (ok final-amount))))

;; Multi-hop swap with exact output
(define-public (swap-exact-out-multi-hop
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-out uint)
  (max-amount-in uint)
  (deadline uint))
  (begin
    (asserts! (>= deadline block-height) ERR_EXPIRED)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (is-eq (len pools) (- (len path) u1)) ERR_INVALID_PATH)
    
    ;; Calculate required input through reverse path
    (let ((required-input (unwrap! (calculate-required-input path pools amount-out) ERR_INVALID_ROUTE)))
      (asserts! (<= required-input max-amount-in) ERR_SLIPPAGE_EXCEEDED)
      
      ;; Execute swap
      (let ((final-amount (try! (execute-multi-hop-swap path pools required-input))))
        
        (print {
          event: "multi-hop-swap-exact-out",
          path: path,
          amount-in: required-input,
          amount-out: final-amount,
          pools-used: (len pools),
          trader: tx-sender
        })
        
        (ok required-input)))))

;; =============================================================================
;; PATH EXECUTION LOGIC
;; =============================================================================

;; moved above to resolve forward references (execute-single-hop)

;; =============================================================================
;; POOL-SPECIFIC SWAP EXECUTION
;; =============================================================================

;; moved above to resolve forward references (pool swap helpers)

;; =============================================================================
;; ROUTING OPTIMIZATION
;; =============================================================================

;; Find optimal route between two tokens
(define-read-only (find-optimal-route
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (match (map-get? routes {token-in: token-in, token-out: token-out})
    direct-route (ok direct-route)
    ;; Try reverse route
    (match (map-get? routes {token-in: token-out, token-out: token-in})
      reverse-route (ok {
        pools: (get pools reverse-route),
        pool-types: (get pool-types reverse-route),
        estimated-gas: (get estimated-gas reverse-route),
        active: (get active reverse-route)
      })
      ;; No direct route found - would implement pathfinding here
      (err ERR_INVALID_ROUTE))))

;; Pricing helper defined before recursive calculator to avoid forward reference
;; Get output amount for single hop (simplified)
(define-private (get-single-hop-output
  (pool-principal principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  ;; Simplified calculation - would query actual pool
  (/ (* amount-in u997) u1000)) ;; Assume 0.3% fee

;; Iterative amounts-out calculator using fold (no recursion)
(define-private (process-hop-amounts
  (pool-principal principal)
  (acc {i: uint, path: (list 5 principal), current: uint, amounts: (list 5 uint)}))
  (let ((token-in (unwrap-panic (element-at (get path acc) (get i acc))))
        (token-out (unwrap-panic (element-at (get path acc) (+ (get i acc) u1))))
        (next-amount (get-single-hop-output pool-principal
                                           (unwrap-panic (element-at (get path acc) (get i acc)))
                                           (unwrap-panic (element-at (get path acc) (+ (get i acc) u1)))
                                           (get current acc))))
    {
      i: (+ (get i acc) u1),
      path: (get path acc),
      current: next-amount,
      amounts: (unwrap-panic (as-max-len? (append (get amounts acc) next-amount) u5))
    }))

(define-private (calculate-amounts-out-fold
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (let ((initial {i: u0,
                  path: path,
                  current: amount-in,
                  amounts: (unwrap-panic (as-max-len? (list amount-in) u5))}))
    (let ((result (fold process-hop-amounts pools initial)))
      (ok (get amounts result)))))

;; Calculate output for a given route (read-only)
(define-read-only (get-amounts-out
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (calculate-amounts-out-fold path pools amount-in))

;; =============================================================================
;; PRICING AND ESTIMATION
;; =============================================================================

;; moved above to resolve forward reference (get-single-hop-output)

;; moved above to resolve forward reference (calculate-required-input)

;; =============================================================================
;; ROUTE MANAGEMENT
;; =============================================================================

;; Register a new route
(define-public (register-route
  (token-in principal)
  (token-out principal)
  (pools (list 5 principal))
  (pool-types (list 5 (string-ascii 20)))
  (estimated-gas uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    
    (map-set routes {token-in: token-in, token-out: token-out} {
      pools: pools,
      pool-types: pool-types,
      estimated-gas: estimated-gas,
      active: true
    })
    
    (print {
      event: "route-registered",
      token-in: token-in,
      token-out: token-out,
      hops: (len pools)
    })
    
    (ok true)))

;; Register pool in routing registry
(define-public (register-pool-for-routing
  (pool-principal principal)
  (token-x principal)
  (token-y principal)
  (pool-type (string-ascii 20))
  (fee-tier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    
    (map-set pool-registry pool-principal {
      token-x: token-x,
      token-y: token-y,
      pool-type: pool-type,
      fee-tier: fee-tier,
      active: true
    })
    
    (ok true)))

;; =============================================================================
;; FEE TIER MANAGEMENT
;; =============================================================================

;; Configure fee tier
(define-public (configure-fee-tier
  (tier-id uint)
  (fee-bps uint)
  (tick-spacing uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= fee-bps u1000) ERR_INVALID_ROUTE) ;; Max 10% fee
    
    (map-set fee-tiers tier-id {
      fee-bps: fee-bps,
      tick-spacing: tick-spacing,
      enabled: true
    })
    
    (print {
      event: "fee-tier-configured",
      tier-id: tier-id,
      fee-bps: fee-bps,
      tick-spacing: tick-spacing
    })
    
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-route (token-in principal) (token-out principal))
  (map-get? routes {token-in: token-in, token-out: token-out}))

(define-read-only (get-pool-info (pool-principal principal))
  (map-get? pool-registry pool-principal))

(define-read-only (get-fee-tier (tier-id uint))
  (map-get? fee-tiers tier-id))

(define-read-only (get-routing-fee)
  (var-get routing-fee-bps))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-routing-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u100) ERR_INVALID_ROUTE) ;; Max 1% routing fee
    (var-set routing-fee-bps new-fee-bps)
    (ok true)))

(define-public (set-max-slippage (new-slippage-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= new-slippage-bps u5000) ERR_INVALID_ROUTE) ;; Max 50% slippage
    (var-set max-slippage-bps new-slippage-bps)
    (ok true)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (var-set router-admin new-admin)
    (ok true)))

;; Initialize default fee tiers
(define-private (initialize-fee-tiers)
  (begin
    ;; 0.05% tier
    (map-set fee-tiers u1 {fee-bps: u5, tick-spacing: u10, enabled: true})
    ;; 0.3% tier
    (map-set fee-tiers u2 {fee-bps: u30, tick-spacing: u60, enabled: true})
    ;; 1% tier
    (map-set fee-tiers u3 {fee-bps: u100, tick-spacing: u200, enabled: true})
    true))

;; Initialize fee tiers on deployment
(initialize-fee-tiers)
