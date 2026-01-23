;; price-impact-calculator.clar
;; Conxian Protocol: Price impact calculation for trading operations

;; Dependencies
(use-trait defi-traits .defi-traits.defi-traits)
(use-trait core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVALID_TRADE_SIZE (err 27001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err 27002))
(define-constant ERR_INVALID_POOL_STATE (err 27003))
(define-constant ERR_CALCULATION_FAILED (err 27004))
(define-constant ERR_INVALID_TOKEN_PAIR (err 27005))

;; Price impact parameters
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant MAX_TRADE_SIZE_RATIO u1000) ;; 10% of pool liquidity max
(define-constant MIN_LIQUIDITY_THRESHOLD u1000000) ;; 1 STX equivalent
(define-constant IMPACT_THRESHOLD u1000) ;; 10% impact threshold
(define-constant SLIPPAGE_TOLERANCE u500) ;; 5% default slippage tolerance

;; Data variables
(define-data-var calculator-active bool true)
(define-data-var total-calculations uint u0)
(define-data-var average-impact uint u0)

;; Storage maps
(define-map price-impact-cache { pool: principal, trade-size: uint } { 
  impact: uint,
  slippage: uint,
  effective-price: uint,
  timestamp: uint,
  pool-reserve-0: uint,
  pool-reserve-1: uint
})

(define-map pool-liquidity-state { pool: principal } { 
  reserve-0: uint,
  reserve-1: uint,
  total-liquidity: uint,
  last-updated: uint,
  fee-tier: uint,
  token-0: principal,
  token-1: principal
})

(define-map trade-impact-history { pool: principal, trade-id: (buff 32) } { 
  trade-size: uint,
  calculated-impact: uint,
  actual-impact: uint,
  timestamp: uint,
  accuracy: uint
})

(define-map impact-statistics { pool: principal } { 
  total-trades: uint,
  average-impact: uint,
  max-impact: uint,
  min-impact: u10000,
  total-volume: uint,
  last-trade: uint
})

;; Events
(define-event (impact-calculated (pool principal) (trade-size uint) (impact uint) (slippage uint)))
(define-event (high-impact-detected (pool principal) (trade-size uint) (impact uint)))
(define-event (liquidity-updated (pool principal) (reserve-0 uint) (reserve-1 uint)))
(define-event (impact-threshold-exceeded (pool principal) (impact uint)))
(define-event (cache-hit (pool principal) (trade-size uint)))

;; Read-only functions

(define-read-only (get-cached-impact (pool principal) (trade-size uint))
  (map-get? price-impact-cache { pool: pool, trade-size: trade-size }))

(define-read-only (get-pool-liquidity-state (pool principal))
  (map-get? pool-liquidity-state { pool: pool }))

(define-read-only (get-pool-reserves (pool principal))
  (match (get-pool-liquidity-state pool)
    state (ok { reserve-0: (get state reserve-0), reserve-1: (get state reserve-1) })
    none (ok { reserve-0: u0, reserve-1: u0 })
  )
)

(define-read-only (get-pool-total-liquidity (pool principal))
  (match (get-pool-liquidity-state pool)
    state (ok (get state total-liquidity))
    none (ok u0)
  )
)

(define-read-only (get-trade-impact-history (pool principal) (trade-id (buff 32)))
  (map-get? trade-impact-history { pool: pool, trade-id: trade-id }))

(define-read-only (get-impact-statistics (pool principal))
  (map-get? impact-statistics { pool: pool }))

(define-read-only (get-pool-average-impact (pool principal))
  (match (get-impact-statistics pool)
    stats (ok (get stats average-impact))
    none (ok u0)
  )
)

(define-read-only (is-calculator-active)
  (var-get calculator-active))

(define-read-only (get-total-calculations)
  (var-get total-calculations))

(define-read-only (get-average-impact)
  (var-get average-impact))

;; Public functions

(define-public (calculate-price-impact (pool principal) (trade-size uint) (token-in principal))
  (begin
    ;; Validate inputs
    (asserts! (> trade-size u0) ERR_INVALID_TRADE_SIZE)
    (asserts! (principal? token-in) ERR_INVALID_TOKEN_PAIR)
    (asserts! (var-get calculator-active) ERR_CALCULATION_FAILED)
    
    ;; Check cache first
    (let ((cached-result (get-cached-impact pool trade-size)))
      (if (is-some cached-result)
          (begin
            ;; Check if cache is still valid (within 100 blocks)
            (let ((cache (unwrap-optional cached-result)))
              (if (< (- block-height (get cache timestamp)) u100)
                  (begin
                    ;; Emit cache hit event
                    (emit-event (cache-hit pool trade-size))
                    
                    (ok {
                      impact: (get cache impact),
                      slippage: (get cache slippage),
                      effective-price: (get cache effective-price)
                    })
                  )
                  ;; Cache expired, recalculate
                  (recalculate-impact pool trade-size token-in)
              )
            )
            ;; No cache entry, calculate new
            (recalculate-impact pool trade-size token-in)
          )
      )
    )
  )
)

(define-public (update-pool-liquidity (pool principal) (reserve-0 uint) (reserve-1 uint) (token-0 principal) (token-1 principal) (fee-tier uint))
  (begin
    ;; Validate inputs
    (asserts! (> reserve-0 u0) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (> reserve-1 u0) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (principal? token-0) ERR_INVALID_TOKEN_PAIR)
    (asserts! (principal? token-1) ERR_INVALID_TOKEN_PAIR)
    (asserts! (>= fee-tier u0) ERR_INVALID_POOL_STATE)
    (asserts! (<= fee-tier u10000) ERR_INVALID_POOL_STATE)
    
    ;; Calculate total liquidity
    (let ((total-liquidity (+ reserve-0 reserve-1)))
      
      ;; Update pool state
      (map-set pool-liquidity-state { pool: pool } {
        reserve-0: reserve-0,
        reserve-1: reserve-1,
        total-liquidity: total-liquidity,
        last-updated: block-height,
        fee-tier: fee-tier,
        token-0: token-0,
        token-1: token-1
      })
      
      ;; Invalidate cache entries for this pool
      (invalidate-cache-for-pool pool)
      
      ;; Emit event
      (emit-event (liquidity-updated pool reserve-0 reserve-1))
      
      (ok {
        total-liquidity: total-liquidity,
        reserve-0: reserve-0,
        reserve-1: reserve-1
      })
    )
  )
)

(define-public (calculate-max-trade-size (pool principal) (max-impact uint))
  (begin
    ;; Validate inputs
    (asserts! (> max-impact u0) ERR_INVALID_TRADE_SIZE)
    (asserts! (<= max-impact u10000) ERR_INVALID_TRADE_SIZE)
    (asserts! (var-get calculator-active) ERR_CALCULATION_FAILED)
    
    ;; Get pool state
    (let ((pool-state (get-pool-liquidity-state pool)))
      (asserts! (is-some pool_state) ERR_INSUFFICIENT_LIQUIDITY)
      
      (let ((state (unwrap-optional pool_state)))
        ;; Calculate maximum trade size for given impact
        (let ((total-liquidity (get state total-liquidity))
              (max-trade-size (/ (* total-liquidity max-impact) u10000)))
          
          ;; Ensure trade size doesn't exceed pool ratio limit
          (let ((limited-trade-size (min max-trade-size (/ (* total-liquidity MAX_TRADE_SIZE_RATIO) u10000))))
            
            (ok {
              max-trade-size: limited-trade-size,
              max-impact: max-impact,
              pool-liquidity: total-liquidity
            })
          )
        )
      )
    )
  )
)

(define-public (calculate-slippage-tolerance (pool principal) (trade-size uint) (user-tolerance uint))
  (begin
    ;; Validate inputs
    (asserts! (> trade-size u0) ERR_INVALID_TRADE_SIZE)
    (asserts! (> user-tolerance u0) ERR_INVALID_TRADE_SIZE)
    (asserts! (<= user-tolerance u10000) ERR_INVALID_TRADE_SIZE)
    (asserts! (var-get calculator-active) ERR_CALCULATION_FAILED)
    
    ;; Calculate price impact
    (match (calculate-price-impact pool trade-size tx-sender)
      impact-result
        (begin
          (let ((calculated-impact (get impact-result impact))
                (calculated-slippage (get impact-result slippage)))
            
            ;; Check if calculated slippage exceeds user tolerance
            (if (> calculated-slippage user-tolerance)
                (err ERR_CALCULATION_FAILED)
                (ok {
                  calculated-slippage: calculated-slippage,
                  user-tolerance: user-tolerance,
                  acceptable: (<= calculated-slippage user-tolerance)
                })
            )
          )
        )
      error error
    )
  )
)

(define-public (record-actual-impact (pool principal) (trade-id (buff 32)) (actual-impact uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len trade-id) u0) ERR_INVALID_TRADE_SIZE)
    (asserts! (var-get calculator-active) ERR_CALCULATION_FAILED)
    
    ;; Get trade history
    (let ((trade-history (get-trade-impact-history pool trade-id)))
      (asserts! (is-some trade_history) ERR_CALCULATION_FAILED)
      
      (let ((history (unwrap-optional trade-history)))
        ;; Calculate accuracy
        (let ((accuracy (calculate-accuracy (get history calculated-impact) actual-impact)))
          
          ;; Update trade history with actual impact
          (map-set trade-impact-history { pool: pool, trade-id: trade-id } {
            trade-size: (get history trade-size),
            calculated-impact: (get history calculated-impact),
            actual-impact: actual-impact,
            timestamp: (get history timestamp),
            accuracy: accuracy
          })
          
          ;; Update pool statistics
          (update-pool-statistics pool (get history calculated-impact) actual-impact)
          
          (ok {
            calculated-impact: (get history calculated-impact),
            actual-impact: actual-impact,
            accuracy: accuracy
          })
        )
      )
    )
  )
)

(define-public (batch-calculate-impact (calculations (list 20 { pool: principal, trade-size: uint, token-in principal })))
  (begin
    ;; Validate list size
    (asserts! (<= (len calculations) u20) ERR_INVALID_TRADE_SIZE)
    
    ;; Calculate impact for each trade
    (fold calculations u0
      (lambda ((result uint) (calc { pool: principal, trade-size: uint, token-in principal }))
        (match (calculate-price-impact (get calc pool) (get calc trade-size) (get calc token-in))
          success (+ result u1)
          error result
        )
      )
    
    (ok true)
  )
)

(define-public (clear-cache)
  (begin
    ;; Only admin can clear cache
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_CALCULATION_FAILED)
    
    ;; Clear all cache entries
    ;; This would iterate through all cache entries
    ;; Simplified implementation
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { impact: u0, slippage: u0, effective-price: u0, timestamp: u0, pool-reserve-0: u0, pool-reserve-1: u0 } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (recalculate-impact (pool principal) (trade-size uint) (token-in principal))
  (begin
    ;; Get pool state
    (let ((pool-state (get-pool-liquidity-state pool)))
      (asserts! (is-some pool_state) ERR_INSUFFICIENT_LIQUIDITY)
      
      (let ((state (unwrap-optional pool_state)))
        ;; Validate trade size against pool liquidity
        (let ((total-liquidity (get state total-liquidity)))
          (asserts! (>= total-liquidity MIN_LIQUIDITY_THRESHOLD) ERR_INSUFFICIENT_LIQUIDITY)
          (asserts! (<= trade-size (/ (* total-liquidity MAX_TRADE_SIZE_RATIO) u10000)) ERR_INVALID_TRADE_SIZE)
          
          ;; Calculate impact using constant product formula
          (let ((impact-result (calculate-constant-product-impact state trade-size token-in)))
            
            ;; Store in cache
            (map-set price-impact-cache { pool: pool, trade-size: trade-size } {
              impact: (get impact-result impact),
              slippage: (get impact-result slippage),
              effective-price: (get impact-result effective-price),
              timestamp: block-height,
              pool-reserve-0: (get state reserve-0),
              pool-reserve-1: (get state reserve-1)
            })
            
            ;; Create trade history record
            (let ((trade-id (hash160 (concat (principal-to-buff? pool) (int-to-buff trade-size)))))
              (map-set trade-impact-history { pool: pool, trade-id: trade-id } {
                trade-size: trade-size,
                calculated-impact: (get impact-result impact),
                actual-impact: u0, ;; Will be updated when actual trade executes
                timestamp: block-height,
                accuracy: u0 ;; Will be calculated when actual impact is known
              })
            )
            
            ;; Update statistics
            (update-pool-statistics pool (get impact-result impact) u0)
            
            ;; Update global statistics
            (var-set total-calculations (+ (var-get total-calculations) u1))
            (var-set average-impact (/ (+ (* (var-get average-impact) (- (var-get total-calculations) u1)) (get impact-result impact)) (var-get total-calculations)))
            
            ;; Check for high impact
            (if (> (get impact-result impact) IMPACT_THRESHOLD)
                (emit-event (high-impact-detected pool trade-size (get impact-result impact)))
                true
            )
            
            ;; Emit event
            (emit-event (impact-calculated pool trade-size (get impact-result impact) (get impact-result slippage)))
            
            (ok impact-result)
          )
        )
      )
    )
  )
)

(define-private (calculate-constant-product-impact (state { reserve-0: uint, reserve-1: uint, total-liquidity: uint, last-updated: uint, fee-tier: uint, token-0: principal, token-1: principal }) (trade-size uint) (token-in principal))
  (begin
    ;; Determine which reserve to use based on token-in
    (let ((is-token-0 (is-eq token-in (get state token-0)))
          (reserve-in (if is-token-0 (get state reserve-0) (get state reserve-1)))
          (reserve-out (if is-token-0 (get state reserve-1) (get state reserve-0))))
      
      ;; Calculate output using constant product formula
      (let ((fee-multiplier (- u10000 (get state fee-tier)))
            (output-amount (/ (* trade-size reserve-out fee-multiplier) (+ reserve-in (* trade-size fee-multiplier))))
            (price-impact (/ (* trade-size u10000) (+ reserve-in trade-size)))
            (effective-price (/ (* trade-size PRECISION) output-amount)))
        
        {
          impact: price-impact,
          slippage: price-impact, ;; Simplified - would calculate actual slippage
          effective-price: effective-price
        }
      )
    )
  )
)

(define-private (invalidate-cache-for-pool (pool principal))
  (begin
    ;; Remove all cache entries for the specified pool
    ;; This would iterate through all cache entries and remove those matching the pool
    ;; Simplified implementation
    true
  )
)

(define-private (calculate-accuracy (calculated uint) (actual uint))
  (begin
    ;; Calculate accuracy as percentage of how close calculated was to actual
    (if (> calculated u0)
        (let ((error (abs (- calculated actual))))
          (if (>= calculated error)
              (/ (* (- calculated error) u10000) calculated)
              u0
          )
        )
        u0
    )
  )
)

(define-private (update-pool-statistics (pool principal) (calculated-impact uint) (actual-impact uint))
  (begin
    ;; Get current statistics
    (let ((stats (get-impact-statistics pool)))
      (if (is-some stats)
          (begin
            (let ((current-stats (unwrap-optional stats))
                  (total-trades (get current-stats total-trades)))
              
              ;; Update statistics
              (map-set impact-statistics { pool: pool } {
                total-trades: (+ total-trades u1),
                average-impact: (if (> actual-impact u0)
                                  (/ (+ (* (get current-stats average-impact) total-trades) actual-impact) (+ total-trades u1))
                                  (get current-stats average-impact)),
                max-impact: (max (get current-stats max-impact) calculated-impact),
                min-impact: (min (get current-stats min-impact) calculated-impact),
                total-volume: (get current-stats total-volume), ;; Would update with actual trade volume
                last-trade: block-height
              })
            )
          )
          ;; Create new statistics
          (map-set impact-statistics { pool: pool } {
            total-trades: u1,
            average-impact: (if (> actual-impact u0) actual-impact calculated-impact),
            max-impact: calculated-impact,
            min-impact: calculated-impact,
            total-volume: u0, ;; Would update with actual trade volume
            last-trade: block-height
          })
      )
    )
  )
)

;; Admin functions

(define-public (set-calculator-active (active bool))
  (begin
    ;; Only admin can set calculator status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_CALCULATION_FAILED)
    
    (var-set calculator-active active)
    (ok true)
  )
)

(define-public (emergency-reset-statistics)
  (begin
    ;; Only admin can emergency reset
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_CALCULATION_FAILED)
    
    ;; Reset global statistics
    (var-set total-calculations u0)
    (var-set average-impact u0)
    
    (ok true)
  )
)

;; Utility functions

(define-read-only (get-calculator-status)
  {
    active: (var-get calculator-active),
    total-calculations: (var-get total-calculations),
    average-impact: (var-get average-impact),
    cache-size: u0 ;; Would count actual cache entries
  }
)

(define-read-only (validate-pool-state (pool principal))
  (begin
    ;; Validate pool state consistency
    (let ((pool-state (get-pool-liquidity-state pool)))
      (if (is-some pool_state)
          (begin
            (let ((state (unwrap-optional pool_state)))
              (and
                (> (get state reserve-0) u0)
                (> (get state reserve-1) u0)
                (> (get state total-liquidity) u0)
                (>= (get state fee-tier) u0)
                (<= (get state fee-tier) u10000)
                (is-eq (get state total-liquidity) (+ (get state reserve-0) (get state reserve-1)))
              )
            )
          )
          false
      )
    )
  )
)
