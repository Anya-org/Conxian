;; liquidity-optimization-engine.clar
;; Conxian DEX: Liquidity optimization algorithms and strategies

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err 12001))
(define-constant ERR_INVALID_POOL (err 12002))
(define-constant ERR_OPTIMIZATION_FAILED (err 12003))
(define-constant ERR_INSUFFICIENT_DATA (err 12004))
(define-constant ERR_INVALID_PARAMETERS (err 12005))

;; Optimization parameters
(define-constant MIN_LIQUIDITY_THRESHOLD u100000000) ;; 100 STX equivalent
(define-constant MAX_OPTIMIZATION_ITERATIONS u100)
(define-constant TARGET_UTILIZATION u8000) ;; 80% utilization target
(define-constant OPTIMIZATION_FEE_BASIS_POINTS u50) ;; 0.5% fee

;; Data variables
(define-data-var optimization-engine-active bool true)
(define-data-var optimization-frequency uint u100) ;; Every 100 blocks

;; Storage maps
(define-map pool-optimization-data { pool: principal } { 
  last-optimization: uint,
  target-liquidity: uint,
  current-utilization: uint,
  optimization-score: uint,
  fee-tier: uint
})

(define-map optimization-history { pool: principal } { 
  timestamp: uint,
  action: (string-ascii 32),
  old-value: uint,
  new-value: uint
})

;; Events
(define-event (liquidity-optimized (pool principal) (old-liquidity uint) (new-liquidity uint)))
(define-event (fee-tier-updated (pool principal) (old-tier uint) (new-tier uint)))
(define-event (optimization-score-calculated (pool principal) (score uint)))

;; Read-only functions

(define-read-only (get-pool-optimization-data (pool principal))
  (map-get? pool-optimization-data { pool: pool }))

(define-read-only (get-pool-target-liquidity (pool principal))
  (match (get-pool-optimization-data pool)
    data (ok (get data target-liquidity))
    none (ok u0)
  )
)

(define-read-only (get-pool-utilization (pool principal))
  (match (get-pool-optimization-data pool)
    data (ok (get data current-utilization))
    none (ok u0)
  )
)

(define-read-only (get-optimization-score (pool principal))
  (match (get-pool-optimization-data pool)
    data (ok (get data optimization-score))
    none (ok u0)
  )
)

(define-read-only (get-pool-fee-tier (pool principal))
  (match (get-pool-optimization-data pool)
    data (ok (get data fee-tier))
    none (ok u1000) ;; Default 0.1% fee
  )
)

(define-read-only (is-optimization-active)
  (var-get optimization-engine-active)
)

(define-read-only (should-optimize-pool (pool principal))
  (begin
    (match (get-pool-optimization-data pool)
      data
        (let ((blocks-since-optimization (- block-height (get data last-optimization))))
          (ok (and (var-get optimization-engine-active) 
                  (>= blocks-since-optimization (var-get optimization-frequency)))))
      none (ok false)
    )
  )
)

;; Public functions

(define-public (analyze-pool-liquidity (pool principal))
  (begin
    ;; Verify pool exists and has sufficient data
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Get current pool metrics
    (let ((current-liquidity (contract-call? .dex-facade get-pool-liquidity pool))
          (current-volume (contract-call? .dex-facade get-pool-volume pool))
          (fee-revenue (contract-call? .dex-facade get-pool-fee-revenue pool)))
      
      (asserts! (>= current-liquidity MIN_LIQUIDITY_THRESHOLD) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Calculate utilization
      (let ((utilization (if (> current-liquidity u0)
                          (/ (* current-volume u10000) current-liquidity)
                          u0)))
        
        ;; Calculate optimization score
        (let ((score (calculate-optimization-score current-liquidity utilization fee-revenue)))
          
          ;; Update optimization data
          (map-set pool-optimization-data { pool: pool } {
            last-optimization: block-height,
            target-liquidity: (calculate-target-liquidity current-liquidity utilization),
            current-utilization: utilization,
            optimization-score: score,
            fee-tier: (calculate-optimal-fee-tier score)
          })
          
          ;; Emit event
          (emit-event (optimization-score-calculated pool score))
          
          (ok {
            current-liquidity: current-liquidity,
            utilization: utilization,
            optimization-score: score,
            target-liquidity: (calculate-target-liquidity current-liquidity utilization),
            recommended-fee-tier: (calculate-optimal-fee-tier score)
          })
        )
      )
    )
  )
)

(define-public (optimize-pool-liquidity (pool principal) (target-liquidity uint))
  (begin
    ;; Verify optimization is active
    (asserts! (var-get optimization-engine-active) ERR_OPTIMIZATION_FAILED)
    
    ;; Verify pool exists
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Get current state
    (let ((current-liquidity (contract-call? .dex-facade get-pool-liquidity pool))
          (old-data (get-pool-optimization-data pool)))
      
      (asserts! (>= target-liquidity MIN_LIQUIDITY_THRESHOLD) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Calculate optimal liquidity adjustment
      (let ((optimal-liquidity (calculate-optimal-liquidity current-liquidity target-liquidity))
            (liquidity-delta (- optimal-liquidity current-liquidity)))
        
        ;; Update optimization data
        (map-set pool-optimization-data { pool: pool } {
          last-optimization: block-height,
          target-liquidity: optimal-liquidity,
          current-utilization: (get old-data current-utilization),
          optimization-score: (get old-data optimization-score),
          fee-tier: (get old-data fee-tier)
        })
        
        ;; Record optimization history
        (map-set optimization-history { pool: pool } {
          timestamp: block-height,
          action: "liquidity-optimization",
          old-value: current-liquidity,
          new-value: optimal-liquidity
        })
        
        ;; Emit event
        (emit-event (liquidity-optimized pool current-liquidity optimal-liquidity))
        
        (ok {
          old-liquidity: current-liquidity,
          new-liquidity: optimal-liquidity,
          delta: liquidity-delta,
          recommended-action: (if (> liquidity-delta u0) "add-liquidity" "remove-liquidity")
        })
      )
    )
  )
)

(define-public (update-pool-fee-tier (pool principal) (new-fee-tier uint))
  (begin
    ;; Verify pool exists
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Validate fee tier
    (asserts! (and (>= new-fee-tier u0) (<= new-fee-tier u10000)) ERR_INVALID_PARAMETERS)
    
    ;; Get current fee tier
    (let ((old-fee-tier (get-pool-fee-tier pool)))
      
      ;; Update fee tier
      (map-set pool-optimization-data { pool: pool } {
        last-optimization: block-height,
        target-liquidity: (get-pool-target-liquidity pool),
        current-utilization: (get-pool-utilization pool),
        optimization-score: (get-optimization-score pool),
        fee-tier: new-fee-tier
      })
      
      ;; Record optimization history
      (map-set optimization-history { pool: pool } {
        timestamp: block-height,
        action: "fee-tier-update",
        old-value: old-fee-tier,
        new-value: new-fee-tier
      })
      
      ;; Emit event
      (emit-event (fee-tier-updated pool old-fee-tier new-fee-tier))
      
      (ok true)
    )
  )

(define-public (batch-optimize-pools (pools (list 20 principal)))
  (begin
    ;; Verify optimization is active
    (asserts! (var-get optimization-engine-active) ERR_OPTIMIZATION_FAILED)
    
    ;; Validate list size
    (asserts! (<= (len pools) u20) ERR_INVALID_PARAMETERS)
    
    ;; Optimize each pool
    (fold pools u0
      (lambda ((result uint) (pool principal))
        (match (analyze-pool-liquidity pool)
          analysis
            (begin
              (match (optimize-pool-liquidity pool (get analysis target-liquidity))
                success (+ result u1)
                error result
              )
            )
          error result
        )
      )
    
    (ok true)
  )
)

;; Private helper functions

(define-private (calculate-optimization-score (liquidity uint) (utilization uint) (fee-revenue uint))
  (begin
    ;; Score based on liquidity efficiency, utilization, and revenue
    (let ((liquidity-score (if (>= liquidity u1000000000) u5000 u2500)) ;; Bonus for high liquidity
          (utilization-score (if (and (>= utilization u7000) (<= utilization u9000)) u3000 u1500)) ;; Optimal utilization
          (revenue-score (if (> fee-revenue u1000000) u2000 u1000))) ;; Revenue generation
      
      (+ liquidity-score utilization-score revenue-score)
    )
  )
)

(define-private (calculate-target-liquidity (current-liquidity uint) (current-utilization uint))
  (begin
    ;; Calculate target liquidity to achieve optimal utilization
    (if (>= current-utilization TARGET_UTILIZATION)
        current-liquidity
        (/ (* current-liquidity TARGET_UTILIZATION) current-utilization)
    )
  )
)

(define-private (calculate-optimal-liquidity (current-liquidity uint) (target-liquidity uint))
  (begin
    ;; Apply smoothing to avoid drastic changes
    (let ((max-change (/ current-liquidity u10)) ;; Max 10% change
          (proposed-change (- target-liquidity current-liquidity)))
      
      (if (> (absolute-value proposed-change) max-change)
          (+ current-liquidity (if (> proposed-change u0) max-change (- max-change)))
          target-liquidity
      )
    )
  )
)

(define-private (calculate-optimal-fee-tier (optimization-score uint))
  (begin
    ;; Higher scoring pools get lower fees to attract more volume
    (if (>= optimization-score u8000)
        u500 ;; 0.05% fee
        (if (>= optimization-score u6000)
            u1000 ;; 0.1% fee
            (if (>= optimization-score u4000)
                u2000 ;; 0.2% fee
                u3000 ;; 0.3% fee
            )
        )
    )
  )
)

(define-private (absolute-value (value int))
  (if (< value 0) (- value) value)
)

;; Admin functions

(define-public (set-optimization-active (active bool))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (var-set optimization-engine-active active)
    (ok true)
  )
)

(define-public (set-optimization-frequency (frequency uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (asserts! (> frequency u0) ERR_INVALID_PARAMETERS)
    (var-set optimization-frequency frequency)
    (ok true)
  )
)

(define-public (emergency-optimize-all-pools)
  (begin
    ;; Only admin can emergency optimize
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    
    ;; Get all active pools from DEX facade
    (match (contract-call? .dex-facade get-all-pools)
      pools
        (begin
          (batch-optimize-pools pools)
          (ok true)
        )
      error (err 10001) ;; Failed to get pools
    )
  )
)
