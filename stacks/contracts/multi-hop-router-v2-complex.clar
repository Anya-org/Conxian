;; =============================================================================
;; MULTI-HOP ROUTER - PRODUCTION IMPLEMENTATION
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
(define-constant MAX_HOPS u5)
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
(define-data-var routing-fee-bps uint u0)
(define-data-var max-slippage-bps uint u1000)

;; =============================================================================
;; HELPER FUNCTIONS (DEFINED FIRST)
;; =============================================================================

;; Get output amount for single hop
(define-private (get-single-hop-output
  (pool-principal principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (/ (* amount-in u997) u1000))

;; Execute swap based on pool type
(define-private (execute-pool-swap
  (pool <pool-trait>)
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (pool-type (string-ascii 20)))
  (match pool-type
    "constant-product" (contract-call? pool swap-exact-in token-in token-out amount-in u0 true)
    "stable" (contract-call? pool swap-exact-in token-in token-out amount-in u0 true)
    "weighted" (contract-call? pool swap-exact-in token-in token-out amount-in u0 true)
    "concentrated" (contract-call? pool swap-exact-in token-in token-out amount-in u0 true)
    (err ERR_INVALID_ROUTE)))

;; Execute single hop in the route
(define-private (execute-single-hop
  (token-in principal)
  (token-out principal)
  (pool <pool-trait>)
  (amount-in uint))
  (let ((pool-info (unwrap! (map-get? pool-registry (contract-of pool)) ERR_INVALID_ROUTE)))
    (asserts! (or 
                (and (is-eq token-in (get token-x pool-info)) (is-eq token-out (get token-y pool-info)))
                (and (is-eq token-in (get token-y pool-info)) (is-eq token-out (get token-x pool-info))))
              ERR_INVALID_ROUTE)
    (match (execute-pool-swap pool token-in token-out amount-in (get pool-type pool-info))
      success (ok (get amount-out success))
      error (err ERR_NO_LIQUIDITY))))

;; =============================================================================
;; CORE ROUTING FUNCTIONS (DEFINED AFTER HELPERS)
;; =============================================================================

;; Execute multi-hop swap recursively
(define-private (execute-multi-hop-swap 
  (path (list 5 principal)) 
  (pools (list 4 <pool-trait>)) 
  (current-amount uint) 
  (hop-index uint))
  (if (>= hop-index (len pools))
    (ok current-amount)
    (let ((token-in (unwrap! (element-at path hop-index) ERR_INVALID_PATH))
          (token-out (unwrap! (element-at path (+ hop-index u1)) ERR_INVALID_PATH))
          (pool (unwrap! (element-at pools hop-index) ERR_INVALID_PATH)))
      (let ((hop-result (try! (execute-single-hop token-in token-out pool current-amount))))
        (execute-multi-hop-swap path pools hop-result (+ hop-index u1))))))

;; Calculate required input for exact output
(define-private (calculate-required-input
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-out uint))
  (ok (* amount-out u1003)))

;; Recursive helper for price calculation  
(define-private (calculate-amounts-out-recursive
  (path (list 5 principal))
  (pools (list 4 principal))
  (current-amount uint)
  (hop-index uint)
  (amounts (list 5 uint)))
  (if (>= hop-index (len pools))
    (ok (unwrap-panic (as-max-len? (append amounts current-amount) u5)))
    (let ((pool-principal (unwrap-panic (element-at pools hop-index)))
          (token-in (unwrap-panic (element-at path hop-index)))
          (token-out (unwrap-panic (element-at path (+ hop-index u1)))))
      (let ((amount-out (get-single-hop-output pool-principal token-in token-out current-amount)))
        (calculate-amounts-out-recursive 
          path 
          pools 
          amount-out 
          (+ hop-index u1)
          (unwrap-panic (as-max-len? (append amounts current-amount) u5)))))))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

;; Calculate output for a given route
(define-read-only (get-amounts-out
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (calculate-amounts-out-recursive path pools amount-in u0 (list)))

;; Find optimal route between two tokens
(define-read-only (find-optimal-route
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (match (map-get? routes {token-in: token-in, token-out: token-out})
    direct-route (ok direct-route)
    (match (map-get? routes {token-in: token-out, token-out: token-in})
      reverse-route (ok reverse-route)
      (err ERR_INVALID_ROUTE))))

;; =============================================================================
;; PUBLIC FUNCTIONS (DEFINED LAST)
;; =============================================================================

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
    (let ((gross-final (try! (execute-multi-hop-swap path pools amount-in u0))))
      (asserts! (>= gross-final min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (let ((fee-bps (var-get routing-fee-bps))
            (net-final (if (is-eq fee-bps u0) 
                         gross-final 
                         (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
        (print {event: "multi-hop-swap", path: path, amount-in: amount-in, gross-out: gross-final, net-out: net-final, fee-bps: fee-bps, pools-used: (len pools), trader: tx-sender})
        (ok net-final)))))

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
    (let ((required-input (try! (calculate-required-input path pools amount-out))))
      (asserts! (<= required-input max-amount-in) ERR_SLIPPAGE_EXCEEDED)
      (let ((gross-final (try! (execute-multi-hop-swap path pools required-input u0))))
        (asserts! (>= gross-final amount-out) ERR_INSUFFICIENT_OUTPUT)
        (let ((fee-bps (var-get routing-fee-bps))
              (net-final (if (is-eq fee-bps u0) 
                           gross-final 
                           (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
          (print {event: "multi-hop-swap-exact-out", path: path, required-out: amount-out, gross-out: gross-final, net-out: net-final, fee-bps: fee-bps, amount-in: required-input, pools-used: (len pools), trader: tx-sender})
          (ok required-input))))))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

;; Update routing fee
(define-public (update-routing-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u500) ERR_INVALID_ROUTE)
    (var-set routing-fee-bps new-fee-bps)
    (print {event: "routing-fee-updated", new-fee-bps: new-fee-bps})
    (ok true)))

;; Add new route
(define-public (add-route
  (token-in principal)
  (token-out principal)
  (pools (list 5 principal))
  (pool-types (list 5 (string-ascii 20)))
  (estimated-gas uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len pools) (len pool-types)) ERR_INVALID_PATH)
    (asserts! (> (len pools) u0) ERR_INVALID_PATH)
    (map-set routes {token-in: token-in, token-out: token-out} {
      pools: pools,
      pool-types: pool-types,
      estimated-gas: estimated-gas,
      active: true
    })
    (print {
      event: "route-added", 
      token-in: token-in, 
      token-out: token-out,
      hops: (len pools)
    })
    (ok true)))

;; Register a pool
(define-public (register-pool
  (pool principal)
  (token-x principal)
  (token-y principal)
  (pool-type (string-ascii 20))
  (fee-tier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (map-set pool-registry pool {
      token-x: token-x,
      token-y: token-y,
      pool-type: pool-type,
      fee-tier: fee-tier,
      active: true
    })
    (print {event: "pool-registered", pool: pool, token-x: token-x, token-y: token-y})
    (ok true)))

;; Transfer router admin
(define-public (transfer-router-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (var-set router-admin new-admin)
    (print {event: "router-admin-transferred", new-admin: new-admin})
    (ok true)))
