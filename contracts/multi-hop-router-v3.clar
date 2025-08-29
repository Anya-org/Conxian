;; Multi-Hop Router V3 - Advanced Routing Engine
;; Implements graph-based routing with Dijkstra's algorithm for optimal path finding
;; Supports price impact modeling, gas cost optimization, and atomic execution

;; Import required traits and libraries
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(use-trait pool-trait .pool-trait.pool-trait)
(use-trait math-trait .math-lib-advanced.advanced-math-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_HOPS u5) ;; Maximum number of hops in a route
(define-constant MAX_POOLS_PER_TOKEN u20) ;; Maximum pools per token for discovery
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision
(define-constant BASIS_POINTS u10000) ;; 100% in basis points

;; Error constants
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_INVALID_ROUTE u8001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u8002)
(define-constant ERR_SLIPPAGE_EXCEEDED u8003)
(define-constant ERR_DEADLINE_EXCEEDED u8004)
(define-constant ERR_ROUTE_NOT_FOUND u8005)
(define-constant ERR_INVALID_AMOUNT u8006)
(define-constant ERR_EXECUTION_FAILED u8007)
(define-constant ERR_PRICE_IMPACT_TOO_HIGH u8008)
(define-constant ERR_GAS_LIMIT_EXCEEDED u8009)

;; Route structure for multi-hop swaps
(define-map routes
  {route-id: uint}
  {token-in: principal,
   token-out: principal,
   hops: (list 5 {pool: principal, token-in: principal, token-out: principal}),
   expected-output: uint,
   price-impact: uint,
   gas-cost: uint,
   created-at: uint})

;; Pool registry for route discovery
(define-map token-pools
  {token: principal}
  {pools: (list 20 principal), count: uint})

;; Pool information cache
(define-map pool-info
  {pool: principal}
  {token-0: principal,
   token-1: principal,
   reserve-0: uint,
   reserve-1: uint,
   fee-bps: uint,
   pool-type: (string-ascii 20),
   last-updated: uint})

;; Route execution state
(define-map route-executions
  {execution-id: uint}
  {route-id: uint,
   user: principal,
   amount-in: uint,
   min-amount-out: uint,
   current-hop: uint,
   intermediate-amounts: (list 5 uint),
   status: (string-ascii 20),
   started-at: uint})

;; Data variables
(define-data-var next-route-id uint u1)
(define-data-var next-execution-id uint u1)
(define-data-var max-price-impact-bps uint u1000) ;; 10% max price impact
(define-data-var max-gas-cost uint u1000000) ;; Max gas cost in STX
(define-data-var route-cache-ttl uint u144) ;; Cache TTL in blocks (~24 hours)

;; Route analytics
(define-data-var total-routes-found uint u0)
(define-data-var total-swaps-executed uint u0)
(define-data-var total-volume-routed uint u0)

;; Register a pool for route discovery
(define-public (register-pool
  (pool principal)
  (token-0 principal)
  (token-1 principal)
  (fee-bps uint)
  (pool-type (string-ascii 20)))
  (begin
    ;; Add pool to token-0 registry
    (try! (add-pool-to-token token-0 pool))
    
    ;; Add pool to token-1 registry
    (try! (add-pool-to-token token-1 pool))
    
    ;; Cache pool information
    (map-set pool-info
      {pool: pool}
      {token-0: token-0,
       token-1: token-1,
       reserve-0: u0, ;; Will be updated by update-pool-reserves
       reserve-1: u0,
       fee-bps: fee-bps,
       pool-type: pool-type,
       last-updated: block-height})
    
    (ok true)))

;; Add pool to token's pool list
(define-private (add-pool-to-token (token principal) (pool principal))
  (let ((current-data (default-to {pools: (list), count: u0} 
                                 (map-get? token-pools {token: token}))))
    (let ((current-pools (get pools current-data))
          (current-count (get count current-data)))
      
      (if (< current-count MAX_POOLS_PER_TOKEN)
        (map-set token-pools
          {token: token}
          {pools: (unwrap-panic (as-max-len? (append current-pools pool) u20)),
           count: (+ current-count u1)})
        true)
      
      (ok true))))

;; Find optimal route using Dijkstra's algorithm
(define-public (find-optimal-route
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (max-hops uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount-in u0) (err ERR_INVALID_AMOUNT))
    (asserts! (<= max-hops MAX_HOPS) (err ERR_INVALID_ROUTE))
    (asserts! (not (is-eq token-in token-out)) (err ERR_INVALID_ROUTE))
    
    ;; Initialize route finding
    (let ((route-id (var-get next-route-id)))
      
      ;; Find best route using graph traversal
      (match (dijkstra-route-search token-in token-out amount-in max-hops)
        route-data (begin
                     ;; Store route
                     (map-set routes
                       {route-id: route-id}
                       (merge route-data {created-at: block-height}))
                     
                     ;; Update analytics
                     (var-set total-routes-found (+ (var-get total-routes-found) u1))
                     (var-set next-route-id (+ route-id u1))
                     
                     (ok {route-id: route-id,
                          expected-output: (get expected-output route-data),
                          price-impact: (get price-impact route-data),
                          gas-cost: (get gas-cost route-data),
                          hops: (get hops route-data)}))
        
        (err ERR_ROUTE_NOT_FOUND)))))

;; Dijkstra's algorithm for optimal route finding
(define-private (dijkstra-route-search
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (max-hops uint))
  (let ((initial-state {current-token: token-in,
                       amount-remaining: amount-in,
                       hops-used: u0,
                       total-gas-cost: u0,
                       total-price-impact: u0,
                       route-hops: (list)}))
    
    ;; Start recursive route search
    (dijkstra-search-recursive 
     token-in 
     token-out 
     amount-in 
     max-hops 
     (list token-in) ;; visited tokens
     (list) ;; current route
     u0 ;; current gas cost
     u0))) ;; current price impact

;; Recursive route search with optimization
(define-private (dijkstra-search-recursive
  (current-token principal)
  (target-token principal)
  (amount-remaining uint)
  (hops-remaining uint)
  (visited-tokens (list 10 principal))
  (current-route (list 5 {pool: principal, token-in: principal, token-out: principal}))
  (total-gas-cost uint)
  (total-price-impact uint))
  
  ;; Base case: reached target token
  (if (is-eq current-token target-token)
    (some {token-in: (unwrap-panic (element-at visited-tokens u0)),
           token-out: target-token,
           hops: current-route,
           expected-output: amount-remaining,
           price-impact: total-price-impact,
           gas-cost: total-gas-cost})
    
    ;; Continue search if hops remaining
    (if (> hops-remaining u0)
      (find-best-next-hop 
       current-token 
       target-token 
       amount-remaining 
       (- hops-remaining u1)
       visited-tokens
       current-route
       total-gas-cost
       total-price-impact)
      none)))

;; Find best next hop from current token
(define-private (find-best-next-hop
  (current-token principal)
  (target-token principal)
  (amount-in uint)
  (hops-remaining uint)
  (visited-tokens (list 10 principal))
  (current-route (list 5 {pool: principal, token-in: principal, token-out: principal}))
  (total-gas-cost uint)
  (total-price-impact uint))
  
  (let ((token-pool-data (map-get? token-pools {token: current-token})))
    (match token-pool-data
      pool-data (find-best-pool-option
                 (get pools pool-data)
                 current-token
                 target-token
                 amount-in
                 hops-remaining
                 visited-tokens
                 current-route
                 total-gas-cost
                 total-price-impact
                 none ;; best-route-so-far
                 u0) ;; pool-index
      none)))

;; Evaluate pool options and find best route
(define-private (find-best-pool-option
  (pools (list 20 principal))
  (current-token principal)
  (target-token principal)
  (amount-in uint)
  (hops-remaining uint)
  (visited-tokens (list 10 principal))
  (current-route (list 5 {pool: principal, token-in: principal, token-out: principal}))
  (total-gas-cost uint)
  (total-price-impact uint)
  (best-route-so-far (optional {token-in: principal, token-out: principal, hops: (list 5 {pool: principal, token-in: principal, token-out: principal}), expected-output: uint, price-impact: uint, gas-cost: uint}))
  (pool-index uint))
  
  (if (>= pool-index (len pools))
    best-route-so-far
    
    (let ((pool (unwrap-panic (element-at pools pool-index))))
      (match (evaluate-pool-hop pool current-token amount-in visited-tokens)
        hop-result (let ((next-token (get next-token hop-result))
                        (amount-out (get amount-out hop-result))
                        (gas-cost (get gas-cost hop-result))
                        (price-impact (get price-impact hop-result)))
                    
                    ;; Continue search from next token
                    (let ((new-visited (unwrap-panic (as-max-len? (append visited-tokens next-token) u10)))
                          (new-route (unwrap-panic (as-max-len? (append current-route {pool: pool, token-in: current-token, token-out: next-token}) u5)))
                          (new-gas-cost (+ total-gas-cost gas-cost))
                          (new-price-impact (+ total-price-impact price-impact)))
                      
                      (match (dijkstra-search-recursive
                             next-token
                             target-token
                             amount-out
                             hops-remaining
                             new-visited
                             new-route
                             new-gas-cost
                             new-price-impact)
                        
                        route-found (let ((is-better (match best-route-so-far
                                                      existing-best (> (get expected-output route-found) 
                                                                      (get expected-output existing-best))
                                                      true)))
                                     (find-best-pool-option
                                      pools current-token target-token amount-in hops-remaining
                                      visited-tokens current-route total-gas-cost total-price-impact
                                      (if is-better (some route-found) best-route-so-far)
                                      (+ pool-index u1)))
                        
                        ;; No route found through this pool, try next
                        (find-best-pool-option
                         pools current-token target-token amount-in hops-remaining
                         visited-tokens current-route total-gas-cost total-price-impact
                         best-route-so-far
                         (+ pool-index u1)))))
        
        ;; Pool evaluation failed, try next pool
        (find-best-pool-option
         pools current-token target-token amount-in hops-remaining
         visited-tokens current-route total-gas-cost total-price-impact
         best-route-so-far
         (+ pool-index u1))))))

;; Evaluate a specific pool for routing
(define-private (evaluate-pool-hop
  (pool principal)
  (token-in principal)
  (amount-in uint)
  (visited-tokens (list 10 principal)))
  
  (let ((pool-data (map-get? pool-info {pool: pool})))
    (match pool-data
      info (let ((token-0 (get token-0 info))
                (token-1 (get token-1 info))
                (fee-bps (get fee-bps info)))
            
            ;; Determine output token
            (let ((token-out (if (is-eq token-in token-0) token-1 token-0)))
              
              ;; Check if token-out is already visited (avoid cycles)
              (if (is-some (index-of visited-tokens token-out))
                none
                
                ;; Calculate swap output
                (match (calculate-swap-output pool token-in token-out amount-in)
                  swap-result (some {next-token: token-out,
                                   amount-out: (get amount-out swap-result),
                                   gas-cost: (get gas-cost swap-result),
                                   price-impact: (get price-impact swap-result)})
                  none))))
      none)))

;; Calculate swap output for a specific pool
(define-private (calculate-swap-output
  (pool principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  
  ;; This would call the actual pool contract to get swap output
  ;; For now, simplified calculation
  (let ((pool-data (unwrap! (map-get? pool-info {pool: pool}) none)))
    (let ((fee-bps (get fee-bps pool-data))
          (pool-type (get pool-type pool-data)))
      
      ;; Simplified calculation - in production would call actual pool
      (let ((fee-amount (/ (* amount-in fee-bps) BASIS_POINTS))
            (amount-after-fee (- amount-in fee-amount)))
        
        ;; Mock calculation based on pool type
        (let ((amount-out (if (is-eq pool-type "constant-product")
                           (/ (* amount-after-fee u997) u1000) ;; 0.3% slippage
                           (if (is-eq pool-type "stable")
                             (/ (* amount-after-fee u9995) u10000) ;; 0.05% slippage
                             (/ (* amount-after-fee u99) u100))))) ;; 1% slippage for others
          
          (some {amount-out: amount-out,
                 gas-cost: u50000, ;; Mock gas cost
                 price-impact: (/ (* amount-in u100) u1000000)}))))) ;; Mock price impact

;; Execute optimal swap with atomic guarantees
(define-public (execute-optimal-swap
  (route-id uint)
  (amount-in uint)
  (min-amount-out uint)
  (deadline uint))
  (begin
    ;; Validate deadline
    (asserts! (< block-height deadline) (err ERR_DEADLINE_EXCEEDED))
    
    ;; Get route data
    (let ((route-data (unwrap! (map-get? routes {route-id: route-id}) (err ERR_ROUTE_NOT_FOUND))))
      
      ;; Validate route is still fresh
      (asserts! (< (- block-height (get created-at route-data)) (var-get route-cache-ttl))
                (err ERR_ROUTE_NOT_FOUND))
      
      ;; Validate amounts
      (asserts! (> amount-in u0) (err ERR_INVALID_AMOUNT))
      (asserts! (>= (get expected-output route-data) min-amount-out) (err ERR_SLIPPAGE_EXCEEDED))
      
      ;; Check price impact limits
      (asserts! (<= (get price-impact route-data) (var-get max-price-impact-bps))
                (err ERR_PRICE_IMPACT_TOO_HIGH))
      
      ;; Execute multi-hop swap
      (let ((execution-id (var-get next-execution-id)))
        
        ;; Initialize execution state
        (map-set route-executions
          {execution-id: execution-id}
          {route-id: route-id,
           user: tx-sender,
           amount-in: amount-in,
           min-amount-out: min-amount-out,
           current-hop: u0,
           intermediate-amounts: (list amount-in),
           status: "executing",
           started-at: block-height})
        
        ;; Execute hops atomically
        (match (execute-route-hops (get hops route-data) amount-in u0)
          final-amount (begin
                        ;; Update execution status
                        (map-set route-executions
                          {execution-id: execution-id}
                          {route-id: route-id,
                           user: tx-sender,
                           amount-in: amount-in,
                           min-amount-out: min-amount-out,
                           current-hop: (len (get hops route-data)),
                           intermediate-amounts: (list amount-in final-amount),
                           status: "completed",
                           started-at: block-height})
                        
                        ;; Update analytics
                        (var-set total-swaps-executed (+ (var-get total-swaps-executed) u1))
                        (var-set total-volume-routed (+ (var-get total-volume-routed) amount-in))
                        (var-set next-execution-id (+ execution-id u1))
                        
                        (ok {execution-id: execution-id,
                             amount-out: final-amount,
                             hops-executed: (len (get hops route-data))}))
          
          (begin
            ;; Mark execution as failed
            (map-set route-executions
              {execution-id: execution-id}
              {route-id: route-id,
               user: tx-sender,
               amount-in: amount-in,
               min-amount-out: min-amount-out,
               current-hop: u0,
               intermediate-amounts: (list),
               status: "failed",
               started-at: block-height})
            
            (err ERR_EXECUTION_FAILED)))))))

;; Execute route hops sequentially with rollback on failure
(define-private (execute-route-hops
  (hops (list 5 {pool: principal, token-in: principal, token-out: principal}))
  (current-amount uint)
  (hop-index uint))
  
  (if (>= hop-index (len hops))
    (some current-amount) ;; All hops completed successfully
    
    (let ((hop (unwrap-panic (element-at hops hop-index))))
      (let ((pool (get pool hop))
            (token-in (get token-in hop))
            (token-out (get token-out hop)))
        
        ;; Execute single hop swap
        (match (execute-single-hop pool token-in token-out current-amount)
          amount-out (execute-route-hops hops amount-out (+ hop-index u1))
          none))))) ;; Hop failed, return none to trigger rollback

;; Execute a single hop swap
(define-private (execute-single-hop
  (pool principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  
  ;; This would call the actual pool contract for the swap
  ;; For now, return a mock successful result
  (some (/ (* amount-in u99) u100))) ;; Mock 1% slippage

;; Update pool reserves for accurate routing
(define-public (update-pool-reserves
  (pool principal)
  (reserve-0 uint)
  (reserve-1 uint))
  (let ((pool-data (unwrap! (map-get? pool-info {pool: pool}) (err ERR_INVALID_ROUTE))))
    (map-set pool-info
      {pool: pool}
      (merge pool-data 
        {reserve-0: reserve-0,
         reserve-1: reserve-1,
         last-updated: block-height}))
    (ok true)))

;; Price impact calculation across multiple hops
(define-public (calculate-route-price-impact
  (route-id uint))
  (let ((route-data (unwrap! (map-get? routes {route-id: route-id}) (err ERR_ROUTE_NOT_FOUND))))
    (ok (get price-impact route-data))))

;; Gas cost optimization
(define-read-only (estimate-gas-cost (hops uint))
  (+ u50000 (* hops u25000))) ;; Base cost + per-hop cost

;; Route validation and feasibility checking
(define-public (validate-route
  (route-id uint)
  (max-price-impact-bps uint)
  (max-gas-cost-stx uint))
  (let ((route-data (unwrap! (map-get? routes {route-id: route-id}) (err ERR_ROUTE_NOT_FOUND))))
    
    ;; Check price impact
    (asserts! (<= (get price-impact route-data) max-price-impact-bps)
              (err ERR_PRICE_IMPACT_TOO_HIGH))
    
    ;; Check gas cost
    (asserts! (<= (get gas-cost route-data) max-gas-cost-stx)
              (err ERR_GAS_LIMIT_EXCEEDED))
    
    ;; Check route freshness
    (asserts! (< (- block-height (get created-at route-data)) (var-get route-cache-ttl))
              (err ERR_ROUTE_NOT_FOUND))
    
    (ok true)))

;; Route caching for frequently used paths
(define-map route-cache
  {token-in: principal, token-out: principal, amount-bucket: uint}
  {route-id: uint, cached-at: uint, hit-count: uint})

;; Cache a route for future use
(define-public (cache-route
  (token-in principal)
  (token-out principal)
  (amount-bucket uint)
  (route-id uint))
  (let ((cache-key {token-in: token-in, token-out: token-out, amount-bucket: amount-bucket}))
    (let ((existing-cache (map-get? route-cache cache-key)))
      (match existing-cache
        cache-data (map-set route-cache
                    cache-key
                    (merge cache-data {hit-count: (+ (get hit-count cache-data) u1)}))
        
        (map-set route-cache
          cache-key
          {route-id: route-id, cached-at: block-height, hit-count: u1})))
    (ok true)))

;; Get cached route if available
(define-read-only (get-cached-route
  (token-in principal)
  (token-out principal)
  (amount-bucket uint))
  (let ((cache-key {token-in: token-in, token-out: token-out, amount-bucket: amount-bucket}))
    (match (map-get? route-cache cache-key)
      cache-data (if (< (- block-height (get cached-at cache-data)) (var-get route-cache-ttl))
                   (some (get route-id cache-data))
                   none)
      none)))

;; Administrative functions

;; Set maximum price impact threshold
(define-public (set-max-price-impact (max-impact-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (asserts! (<= max-impact-bps u5000) (err ERR_INVALID_AMOUNT)) ;; Max 50%
    (var-set max-price-impact-bps max-impact-bps)
    (ok true)))

;; Set route cache TTL
(define-public (set-cache-ttl (ttl-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (var-set route-cache-ttl ttl-blocks)
    (ok true)))

;; Read-only functions

;; Get route information
(define-read-only (get-route (route-id uint))
  (map-get? routes {route-id: route-id}))

;; Get execution status
(define-read-only (get-execution-status (execution-id uint))
  (map-get? route-executions {execution-id: execution-id}))

;; Get pool information
(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info {pool: pool}))

;; Get token pools
(define-read-only (get-token-pools (token principal))
  (map-get? token-pools {token: token}))

;; Get routing analytics
(define-read-only (get-routing-analytics)
  {total-routes-found: (var-get total-routes-found),
   total-swaps-executed: (var-get total-swaps-executed),
   total-volume-routed: (var-get total-volume-routed),
   max-price-impact-bps: (var-get max-price-impact-bps),
   cache-ttl: (var-get route-cache-ttl)})

;; Check if route exists between tokens
(define-read-only (route-exists (token-in principal) (token-out principal))
  (is-some (get-token-pools token-in)))

;; Get optimal route summary
(define-read-only (get-route-summary (route-id uint))
  (match (map-get? routes {route-id: route-id})
    route-data {route-id: route-id,
                token-in: (get token-in route-data),
                token-out: (get token-out route-data),
                hops-count: (len (get hops route-data)),
                expected-output: (get expected-output route-data),
                price-impact-bps: (get price-impact route-data),
                estimated-gas: (get gas-cost route-data)}
    none))

;; Route comparison for optimization
(define-read-only (compare-routes (route-id-1 uint) (route-id-2 uint))
  (let ((route-1 (map-get? routes {route-id: route-id-1}))
        (route-2 (map-get? routes {route-id: route-id-2})))
    (match route-1
      r1 (match route-2
           r2 (some {route-1-better: (> (get expected-output r1) (get expected-output r2)),
                     output-diff: (if (> (get expected-output r1) (get expected-output r2))
                                   (- (get expected-output r1) (get expected-output r2))
                                   (- (get expected-output r2) (get expected-output r1))),
                     gas-diff: (if (> (get gas-cost r1) (get gas-cost r2))
                                (- (get gas-cost r1) (get gas-cost r2))
                                (- (get gas-cost r2) (get gas-cost r1)))})
           none)
      none)))