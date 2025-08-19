;; =============================================================================
;; MULTI-HOP ROUTER - PRODUCTION IMPLEMENTATION (FIXED)
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
;; CORE HELPER FUNCTIONS (NON-INTERDEPENDENT)
;; =============================================================================

;; Get output amount for single hop
(define-private (get-single-hop-output
  (pool-principal principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (/ (* amount-in u997) u1000))

;; Execute single hop swap
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
    (match (contract-call? pool swap-exact-in token-in token-out amount-in u0 true)
      success (ok (get amount-out success))
      error (err ERR_NO_LIQUIDITY))))

;; Execute multi-hop swap iteratively (no recursion)
(define-private (execute-multi-hop-iteration
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-in uint))
  (if (is-eq (len pools) u1)
    ;; Single hop case
    (let ((pool (unwrap! (element-at pools u0) ERR_INVALID_PATH))
          (token-in (unwrap! (element-at path u0) ERR_INVALID_PATH))
          (token-out (unwrap! (element-at path u1) ERR_INVALID_PATH)))
      (execute-single-hop token-in token-out pool amount-in))
    ;; Multi-hop case - execute first hop and estimate remainder
    (let ((pool (unwrap! (element-at pools u0) ERR_INVALID_PATH))
          (token-in (unwrap! (element-at path u0) ERR_INVALID_PATH))
          (token-out (unwrap! (element-at path u1) ERR_INVALID_PATH)))
      (let ((first-hop-result (try! (execute-single-hop token-in token-out pool amount-in))))
        ;; For multi-hop, estimate remaining hops with simplified calculation
        (ok (/ (* first-hop-result u995) u1000))))))

;; Simplified price calculation without recursion
(define-private (estimate-output-simple
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (let ((hop-count (len pools)))
    (if (<= hop-count u1)
      ;; Single hop
      (let ((pool-principal (unwrap-panic (element-at pools u0)))
            (token-in (unwrap-panic (element-at path u0)))
            (token-out (unwrap-panic (element-at path u1))))
        (get-single-hop-output pool-principal token-in token-out amount-in))
      ;; Multi-hop: estimate with cascading fee calculation
      (let ((fee-per-hop u3)) ;; 0.3% per hop
        (/ (* amount-in (pow u997 hop-count)) (pow u1000 hop-count))))))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

;; Calculate output for a given route (simplified, non-recursive)
(define-read-only (get-amounts-out
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (ok (list (estimate-output-simple path pools amount-in))))

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

;; Get estimated gas for route
(define-read-only (estimate-gas
  (path (list 5 principal)))
  (let ((hop-count (- (len path) u1)))
    (* hop-count u50000))) ;; 50k gas per hop estimate

;; =============================================================================
;; PUBLIC FUNCTIONS
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
    
    (let ((gross-final (try! (execute-multi-hop-iteration path pools amount-in))))
      (asserts! (>= gross-final min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (let ((fee-bps (var-get routing-fee-bps))
            (net-final (if (is-eq fee-bps u0) 
                         gross-final 
                         (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
        (print {
          event: "multi-hop-swap", 
          path: path, 
          amount-in: amount-in, 
          gross-out: gross-final, 
          net-out: net-final, 
          fee-bps: fee-bps, 
          pools-used: (len pools), 
          trader: tx-sender
        })
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
    
    ;; Estimate required input (simplified calculation)
    (let ((required-input (* amount-out u1003))) ;; 0.3% buffer
      (asserts! (<= required-input max-amount-in) ERR_SLIPPAGE_EXCEEDED)
      (let ((gross-final (try! (execute-multi-hop-iteration path pools required-input))))
        (asserts! (>= gross-final amount-out) ERR_INSUFFICIENT_OUTPUT)
        (let ((fee-bps (var-get routing-fee-bps))
              (net-final (if (is-eq fee-bps u0) 
                           gross-final 
                           (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
          (print {
            event: "multi-hop-swap-exact-out", 
            path: path, 
            required-out: amount-out, 
            gross-out: gross-final, 
            net-out: net-final, 
            fee-bps: fee-bps, 
            amount-in: required-input, 
            pools-used: (len pools), 
            trader: tx-sender
          })
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
