;; on-chain-router-helper.clar
;; Conxian DEX: On-chain routing helper for multi-hop trades

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVALID_ROUTE (err 19001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err 19002))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err 19003))
(define-constant ERR_INVALID_TOKENS (err 19004))
(define-constant ERR_ROUTE_TOO_LONG (err 19005))

;; Routing parameters
(define-constant MAX_HOPS u5) ;; Maximum 5 hops
(define-constant MAX_ROUTES u100) ;; Maximum routes to consider
(define-constant DEFAULT_SLIPPAGE_TOLERANCE u300) ;; 3% default slippage
(define-constant MIN_LIQUIDITY_THRESHOLD u1000000) ;; 1 STX equivalent
(define-constant ROUTE_CACHE_DURATION u100) ;; Cache routes for 100 blocks

;; Data variables
(define-data-var router-active bool true)
(define-data-var total-routes-calculated uint u0)
(define-data-var last-route-cleanup uint u0)

;; Storage maps
(define-map route-cache { from-token: principal, to-token: principal } { 
  routes: (list 10 (list 5 principal)),
  best-route: (list 5 principal),
  last-calculated: uint,
  total-liquidity: uint,
  estimated-output: uint
})

(define-map pool-liquidity-cache { pool: principal } { 
  token-0: principal,
  token-1: principal,
  reserve-0: uint,
  reserve-1: uint,
  last-updated: uint,
  fee-tier: uint
})

(define-map route-executions { route-hash: (buff 32) } { 
  route: (list 5 principal),
  input-amount: uint,
  output-amount: uint,
  execution-time: uint,
  success: bool,
  actual-slippage: uint
})

(define-map routing-statistics { token-pair: (string-ascii 64) } { 
  total-routes: uint,
  successful-routes: uint,
  average-slippage: uint,
  total-volume: uint,
  last-updated: uint
})

;; Events
(define-event (route-calculated (from-token principal) (to-token principal) (route (list 5 principal)) (estimated-output uint)))
(define-event (route-executed (route-hash (buff 32)) (input-amount uint) (output-amount uint) (success bool)))
(define-event (route-cache-updated (from-token principal) (to-token principal) (route-count uint)))
(define-event (liquidity-cache-updated (pool principal) (reserve-0 uint) (reserve-1 uint)))

;; Read-only functions

(define-read-only (get-cached-route (from-token principal) (to-token principal))
  (map-get? route-cache { from-token: from-token, to-token: to-token }))

(define-read-only (get-best-route (from-token principal) (to-token principal))
  (match (get-cached-route from-token to-token)
    cache (ok (get cache best-route))
    none (ok (list 0 principal))
  )
)

(define-read-only (get-pool-liquidity (pool principal))
  (map-get? pool-liquidity-cache { pool: pool }))

(define-read-only (get-route-execution (route-hash (buff 32)))
  (map-get? route-executions { route-hash: route-hash }))

(define-read-only (get-routing-statistics (token-pair (string-ascii 64)))
  (map-get? routing-statistics { token-pair: token-pair }))

(define-read-only (is-router-active)
  (var-get router-active))

(define-read-only (get-total-routes-calculated)
  (var-get total-routes-calculated))

(define-read-only (is-route-cache-fresh (from-token principal) (to-token principal))
  (match (get-cached-route from-token to-token)
    cache
      (let ((age (- block-height (get cache last-calculated))))
        (ok (< age ROUTE_CACHE_DURATION))
      )
    none (ok false)
  )
)

;; Public functions

(define-public (calculate-route (from-token principal) (to-token principal) (input-amount uint))
  (begin
    ;; Validate inputs
    (asserts! (not (is-eq from-token to-token)) ERR_INVALID_TOKENS)
    (asserts! (> input-amount u0) ERR_INVALID_TOKENS)
    (asserts! (var-get router-active) ERR_INVALID_ROUTE)
    
    ;; Check cache first
    (if (is-route-cache-fresh from-token to-token)
        (begin
          (let ((cache (unwrap-optional (get-cached-route from-token to-token))))
            (ok {
              route: (get cache best-route),
              estimated-output: (get cache estimated-output),
              from-cache: true
            })
          )
        )
        ;; Calculate new route
        (begin
          (let ((route-info (find-best-route from-token to-token input-amount)))
            (match route-info
              success
                (begin
                  ;; Update cache
                  (update-route-cache from-token to-token (get success route) (get success estimated-output))
                  
                  ;; Update statistics
                  (update-routing-statistics from-token to-token input-amount (get success estimated-output))
                  
                  ;; Emit event
                  (emit-event (route-calculated from-token to-token (get success route) (get success estimated-output)))
                  
                  (ok {
                    route: (get success route),
                    estimated-output: (get success estimated-output),
                    from-cache: false
                  })
                )
              error error
            )
          )
        )
    )
  )
)

(define-public (execute-route (route (list 5 principal)) (input-amount uint) (min-output uint))
  (begin
    ;; Validate inputs
    (asserts! (> input-amount u0) ERR_INVALID_ROUTE)
    (asserts! (> min-output u0) ERR_INVALID_ROUTE)
    (asserts! (<= (len route) MAX_HOPS) ERR_ROUTE_TOO_LONG)
    (asserts! (var-get router-active) ERR_INVALID_ROUTE)
    
    ;; Calculate route hash
    (let ((route-hash (hash-route route input-amount)))
      
      ;; Execute route step by step
      (let ((execution-result (execute-route-steps route input-amount)))
        (match execution-result
          success
            (begin
              ;; Check slippage
              (let ((slippage (calculate-slippage input-amount (get success output-amount))))
                (asserts! (<= slippage DEFAULT_SLIPPAGE_TOLERANCE) ERR_SLIPPAGE_TOO_HIGH)
                
                ;; Verify minimum output
                (asserts! (>= (get success output-amount) min-output) ERR_SLIPPAGE_TOO_HIGH)
                
                ;; Record execution
                (map-set route-executions { route-hash: route-hash } {
                  route: route,
                  input-amount: input-amount,
                  output-amount: (get success output-amount),
                  execution-time: block-height,
                  success: true,
                  actual-slippage: slippage
                })
                
                ;; Update statistics
                (update-routing-statistics (get-token-from-route route) (get-token-to-route route) input-amount (get success output-amount))
                
                ;; Emit event
                (emit-event (route-executed route-hash input-amount (get success output-amount) true))
                
                (ok {
                  output-amount: (get success output-amount),
                  actual-slippage: slippage,
                  route-hash: route-hash
                })
              )
            )
          error
            (begin
              ;; Record failed execution
              (map-set route-executions { route-hash: route-hash } {
                route: route,
                input-amount: input-amount,
                output-amount: u0,
                execution-time: block-height,
                success: false,
                actual-slippage: u10000
              })
              
              ;; Emit event
              (emit-event (route-executed route-hash input-amount u0 false))
              
              error
            )
        )
      )
    )
  )
)

(define-public (update-pool-liquidity (pool principal) (reserve-0 uint) (reserve-1 uint))
  (begin
    ;; Validate inputs
    (asserts! (> reserve-0 u0) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (> reserve-1 u0) ERR_INSUFFICIENT_LIQUIDITY)
    
    ;; Get pool tokens
    (let ((pool-info (contract-call? .dex-facade get-pool-info pool)))
      (asserts! (is-some pool-info) ERR_INVALID_ROUTE)
      
      (let ((info (unwrap-optional pool-info)))
        ;; Update liquidity cache
        (map-set pool-liquidity-cache { pool: pool } {
          token-0: (get info token-0),
          token-1: (get info token-1),
          reserve-0: reserve-0,
          reserve-1: reserve-1,
          last-updated: block-height,
          fee-tier: (get info fee-tier)
        })
        
        ;; Invalidate affected routes
        (invalidate-routes-for-pool pool)
        
        ;; Emit event
        (emit-event (liquidity-cache-updated pool reserve-0 reserve-1))
        
        (ok true)
      )
    )
  )
)

(define-public (batch-update-pool-liquidity (updates (list 20 { pool: principal, reserve-0: uint, reserve-1: uint })))
  (begin
    ;; Validate list size
    (asserts! (<= (len updates) u20) ERR_INVALID_ROUTE)
    
    ;; Update each pool
    (fold updates u0
      (lambda ((result uint) (update { pool: principal, reserve-0: uint, reserve-1: uint }))
        (match (update-pool-liquidity (get update pool) (get update reserve-0) (get update reserve-1))
          success (+ result u1)
          error result
        )
      )
    
    (ok true)
  )
)

(define-public (cleanup-route-cache)
  (begin
    ;; Only admin can cleanup cache
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_ROUTE)
    
    ;; Remove stale cache entries
    (let ((cleaned-count u0))
      ;; This would iterate through cache and remove stale entries
      ;; Simplified implementation
      
      ;; Update last cleanup time
      (var-set last-route-cleanup block-height)
      
      (ok cleaned-count)
    )
  )
)

;; Private helper functions

(define-private (find-best-route (from-token principal) (to-token principal) (input-amount uint))
  (begin
    ;; Find all possible routes
    (let ((all-routes (find-all-routes from-token to-token)))
      
      ;; Calculate output for each route
      (let ((route-outputs (map 
        (lambda ((route (list 5 principal)))
          {
            route: route,
            output: (calculate-route-output route input-amount)
          }
        )
        all-routes)))
        
        ;; Find best route (highest output)
        (let ((best-route (find-best-route-by-output route-outputs)))
          (if (is-some best-route)
              (ok (unwrap-optional best-route))
              (err ERR_INVALID_ROUTE)
          )
        )
      )
    )
  )
)

(define-private (find-all-routes (from-token principal) (to-token principal))
  (begin
    ;; Simplified route finding - would use proper graph traversal
    (list (list from-token to-token))
  )
)

(define-private (calculate-route-output (route (list 5 principal)) (input-amount uint))
  (begin
    ;; Calculate output through each hop
    (fold route input-amount
      (lambda ((amount uint) (pool principal))
        (let ((pool-info (get-pool-liquidity pool)))
          (if (is-some pool-info)
              (calculate-pool-output pool (unwrap-optional pool-info) amount)
              u0
          )
        )
      )
  )
)

(define-private (calculate-pool-output (pool principal) (pool-info { token-0: principal, token-1: principal, reserve-0: uint, reserve-1: uint, last-updated: uint, fee-tier: uint }) (input-amount uint))
  (begin
    ;; Simplified pool output calculation
    ;; Would use proper AMM formula
    (/ (* input-amount (get pool-info reserve-1)) (+ (get pool-info reserve-0) input-amount))
  )
)

(define-private (find-best-route-by-output (route-outputs (list 10 { route: (list 5 principal), output: uint })))
  (begin
    ;; Find route with highest output
    (fold route-outputs { route: (list 0 principal), output: u0 }
      (lambda ((best { route: (list 5 principal), output: uint }) (current { route: (list 5 principal), output: uint }))
        (if (> (get current output) (get best output))
            current
            best
        )
      )
  )
)

(define-private (execute-route-steps (route (list 5 principal)) (input-amount uint))
  (begin
    ;; Execute each step of the route
    (fold route { output-amount: input-amount, success: true }
      (lambda ((result { output-amount: uint, success: bool }) (pool principal))
        (if (get result success)
            (let ((pool-output (execute-pool-trade pool (get result output-amount))))
              (match pool-output
                success { output-amount: (get success output-amount), success: true }
                error { output-amount: u0, success: false }
              )
            )
            { output-amount: u0, success: false }
        )
      )
    )
  )
)

(define-private (execute-pool-trade (pool principal) (input-amount uint))
  (begin
    ;; Execute trade on specific pool
    (contract-call? .dex-facade swap pool input-amount)
  )
)

(define-private (calculate-slippage (input-amount uint) (output-amount uint))
  (begin
    ;; Simplified slippage calculation
    u100 ;; 1% default
  )
)

(define-private (hash-route (route (list 5 principal)) (input-amount uint))
  (begin
    ;; Create hash for route
    (hash160 (concat (principal-to-buff? (get route u0)) (int-to-buff input-amount)))
  )
)

(define-private (get-token-from-route (route (list 5 principal)))
  (get route u0)
)

(define-private (get-token-to-route (route (list 5 principal)))
  (let ((route-len (len route)))
    (get route (- route-len u1))
  )
)

(define-private (update-route-cache (from-token principal) (to-token principal) (route (list 5 principal)) (estimated-output uint))
  (begin
    ;; Update cache with new route
    (map-set route-cache { from-token: from-token, to-token: to-token } {
      routes: (list route),
      best-route: route,
      last-calculated: block-height,
      total-liquidity: u0, // Would calculate actual liquidity
      estimated-output: estimated-output
    })
    
    ;; Update statistics
    (var-set total-routes-calculated (+ (var-get total-routes-calculated) u1))
    
    ;; Emit event
    (emit-event (route-cache-updated from-token to-token u1))
  )
)

(define-private (update-routing-statistics (from-token principal) (to-token principal) (input-amount uint) (output-amount uint))
  (begin
    (let ((token-pair (concat (principal-to-string from-token) (principal-to-string to-token))))
      (match (get-routing-statistics token-pair)
        stats
          (begin
            (map-set routing-statistics { token-pair: token-pair } {
              total-routes: (+ (get stats total-routes) u1),
              successful-routes: (+ (get stats successful-routes) u1),
              average-slippage: (get stats average-slippage),
              total-volume: (+ (get stats total-volume) input-amount),
              last-updated: block-height
            })
          )
        none
          (map-set routing-statistics { token-pair: token-pair } {
            total-routes: u1,
            successful-routes: u1,
            average-slippage: DEFAULT_SLIPPAGE_TOLERANCE,
            total-volume: input-amount,
            last-updated: block-height
          })
      )
    )
  )
)

(define-private (invalidate-routes-for-pool (pool principal))
  (begin
    ;; This would find and invalidate routes that use the specified pool
    ;; Simplified implementation
    true
  )
)

;; Admin functions

(define-public (set-router-active (active bool))
  (begin
    ;; Only admin can set router status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_ROUTE)
    
    (var-set router-active active)
    (ok true)
  )
)

(define-public (emergency-clear-cache)
  (begin
    ;; Only admin can clear cache
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_ROUTE)
    
    ;; Clear all cache entries
    ;; This would iterate through all cache entries
    ;; Simplified implementation
    
    (ok true)
  )
)
