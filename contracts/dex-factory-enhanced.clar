;; AutoVault DEX Factory Enhanced - integrates with base factory for pool lookup

(define-read-only (get-pool (token-x principal) (token-y principal))
  (contract-call? .dex-factory get-pool token-x token-y))
;; AutoVault Enhanced DEX Factory
;; Integrates: Load Distribution, Pool Optimization, Performance Monitoring
;; PRD Aligned: DEX.md specifications  
;; Target: +50K TPS through intelligent pool management and routing

(use-trait sip010 .sip-010-trait.sip-010-trait)

;; =============================================================================
;; ENHANCED DEX CONSTANTS AND CONFIGURATION
;; =============================================================================

(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_PAIR u101)
(define-constant ERR_POOL_EXISTS u102)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u103)
(define-constant ERR_SLIPPAGE_EXCEEDED u104)
(define-constant ERR_POOL_NOT_FOUND u105)

;; Performance optimization constants
(define-constant MAX_POOLS_PER_PAIR u10)
(define-constant OPTIMAL_POOL_UTILIZATION u7000) ;; 70%
(define-constant MAX_POOL_UTILIZATION u9000) ;; 90%
(define-constant REBALANCE_THRESHOLD u1000) ;; 10%

;; Pool fee tiers with dynamic adjustment
(define-constant FEE_TIER_LOW u25)    ;; 0.25%
(define-constant FEE_TIER_MEDIUM u100) ;; 1.00%
(define-constant FEE_TIER_HIGH u300)   ;; 3.00%

;; =============================================================================
;; ENHANCED DATA STRUCTURES
;; =============================================================================

;; Pool registry with load distribution metadata
(define-map pools 
  {token-a: principal, token-b: principal, fee-tier: uint}
  {
    pool-address: principal,
    created-at: uint,
    total-liquidity: uint,
    current-utilization: uint,
    performance-score: uint,
    active: bool,
    last-rebalance: uint
  })

;; Pool performance tracking for optimal routing
(define-map pool-performance principal {
  total-volume: uint,
  total-fees: uint,
  swap-count: uint,
  average-slippage: uint,
  last-activity: uint,
  efficiency-score: uint
})

;; Load distribution tracking
(define-map pool-load-metrics principal {
  current-load: uint,
  capacity: uint,
  queue-depth: uint,
  last-load-update: uint
})

;; Enhanced pool routing table
(define-map token-pair-pools
  {token-a: principal, token-b: principal}
  (list 10 principal))

;; Fee tier configuration
(define-map fee-tier-config uint {
  fee-rate: uint,
  min-liquidity: uint,
  max-liquidity: uint,
  utilization-target: uint
})

;; Global factory state
(define-data-var admin principal tx-sender)
(define-data-var total-pools uint u0)
(define-data-var total-volume uint u0)
(define-data-var factory-paused bool false)
(define-data-var auto-rebalancing-enabled bool true)

;; Pool deployment sequence
(define-data-var next-pool-id uint u1)

;; =============================================================================
;; VALIDATION HELPERS
;; =============================================================================

;; =============================================================================
;; ENHANCED POOL CREATION WITH LOAD DISTRIBUTION
;; =============================================================================

(define-private (is-valid-fee-tier (fee-tier uint))
  ;; Accept standard tiers and allow any positive bps up to 10000 for flexibility
  (or (is-eq fee-tier FEE_TIER_LOW)
      (is-eq fee-tier FEE_TIER_MEDIUM)
      (is-eq fee-tier FEE_TIER_HIGH)
      (and (> fee-tier u0) (<= fee-tier u10000))))

(define-public (create-pool-optimized
  (token-a <sip010>)
  (token-b <sip010>)
  (pool-address principal)
  (fee-tier uint)
  (initial-liquidity-a uint)
  (initial-liquidity-b uint))
  (begin
    (asserts! (not (var-get factory-paused)) (err u106))
    (asserts! (is-valid-fee-tier fee-tier) (err u107))
    
    (let ((token-a-addr (contract-of token-a))
          (token-b-addr (contract-of token-b))
          (pool-key {token-a: token-a-addr, token-b: token-b-addr, fee-tier: fee-tier}))
      
      ;; Check if pool already exists
      (asserts! (is-none (map-get? pools pool-key)) (err ERR_POOL_EXISTS))
      
      ;; Validate initial liquidity
      (asserts! (and (> initial-liquidity-a u0) (> initial-liquidity-b u0)) (err ERR_INSUFFICIENT_LIQUIDITY))
      
  ;; Register externally-deployed pool with optimized parameters
  (let ((pool-id (get-next-pool-id)))
        
        ;; Register pool with enhanced metadata
        (map-set pools pool-key {
          pool-address: pool-address,
          created-at: block-height,
          total-liquidity: (+ initial-liquidity-a initial-liquidity-b),
          current-utilization: u0,
          performance-score: u100, ;; Default score
          active: true,
          last-rebalance: block-height
        })
        
        ;; Initialize performance tracking
        (map-set pool-performance pool-address {
          total-volume: u0,
          total-fees: u0,
          swap-count: u0,
          average-slippage: u0,
          last-activity: block-height,
          efficiency-score: u100
        })
        
        ;; Initialize load metrics
        (map-set pool-load-metrics pool-address {
          current-load: u0,
          capacity: u1000, ;; Default capacity
          queue-depth: u0,
          last-load-update: block-height
        })
        
  ;; Add to routing table and global registry
  (update-routing-table token-a-addr token-b-addr pool-address)
        
        ;; Update global state
        (var-set total-pools (+ (var-get total-pools) u1))
        
        (print {
          event: "pool-created-optimized",
          token-a: token-a-addr,
          token-b: token-b-addr,
          fee-tier: fee-tier,
          pool-address: pool-address,
          initial-liquidity: (+ initial-liquidity-a initial-liquidity-b)
        })
        (ok pool-address)))))

;; Compatibility: register an already-deployed pool using principals (test fast-path)
(define-public (register-pool
  (token-a principal)
  (token-b principal)
  (pool-address principal)
  (fee-tier uint)
  (initial-liquidity-a uint)
  (initial-liquidity-b uint))
  (begin
    (asserts! (not (var-get factory-paused)) (err u106))
    (asserts! (is-valid-fee-tier fee-tier) (err u107))
    (let ((pool-key {token-a: token-a, token-b: token-b, fee-tier: fee-tier}))
      (asserts! (is-none (map-get? pools pool-key)) (err ERR_POOL_EXISTS))
      (asserts! (and (> initial-liquidity-a u0) (> initial-liquidity-b u0)) (err ERR_INSUFFICIENT_LIQUIDITY))
      (let ((pool-id (get-next-pool-id)))
        (map-set pools pool-key {
          pool-address: pool-address,
          created-at: block-height,
          total-liquidity: (+ initial-liquidity-a initial-liquidity-b),
          current-utilization: u0,
          performance-score: u100,
          active: true,
          last-rebalance: block-height
        })
        (map-set pool-performance pool-address {
          total-volume: u0,
          total-fees: u0,
          swap-count: u0,
          average-slippage: u0,
          last-activity: block-height,
          efficiency-score: u100
        })
        (map-set pool-load-metrics pool-address {
          current-load: u0,
          capacity: u1000,
          queue-depth: u0,
          last-load-update: block-height
        })
        (update-routing-table token-a token-b pool-address)
        (var-set total-pools (+ (var-get total-pools) u1))
        (print {
          event: "pool-registered",
          token-a: token-a,
          token-b: token-b,
          fee-tier: fee-tier,
          pool-address: pool-address
        })
        (ok pool-address)))))

;; =============================================================================
;; INTELLIGENT POOL SELECTION AND ROUTING
;; =============================================================================

(define-public (get-optimal-pool 
  (token-a principal) 
  (token-b principal) 
  (amount uint))
  (let ((available-pools (default-to (list) (map-get? token-pair-pools {token-a: token-a, token-b: token-b}))))
    (if (> (len available-pools) u0)
      (let ((acc (fold select-better-pool-with-context 
                       available-pools 
                       {best: none, best-score: u0, amount: amount})))
        (match (get best acc)
          best-pool (ok best-pool)
          (err ERR_POOL_NOT_FOUND)))
      (err ERR_POOL_NOT_FOUND))))

;; Mainnet-ready pool comparator used in fold for routing
(define-private (select-better-pool-with-context 
  (pool principal)
  (acc {best: (optional principal), best-score: uint, amount: uint}))
  (let ((load-metrics (default-to 
                         {current-load: u0, capacity: u1000, queue-depth: u0, last-load-update: u0}
                         (map-get? pool-load-metrics pool)))
        (performance (default-to
                      {total-volume: u0, total-fees: u0, swap-count: u0, average-slippage: u0, 
                       last-activity: u0, efficiency-score: u100}
                      (map-get? pool-performance pool)))
        (score (calculate-pool-routing-score load-metrics performance (get amount acc))))
    (if (> score (get best-score acc))
      {best: (some pool), best-score: score, amount: (get amount acc)}
  acc)))

(define-private (calculate-pool-routing-score 
  (load-metrics {current-load: uint, capacity: uint, queue-depth: uint, last-load-update: uint})
  (performance {total-volume: uint, total-fees: uint, swap-count: uint, average-slippage: uint, last-activity: uint, efficiency-score: uint})
  (amount uint))
  (let ((load-score (calculate-load-score load-metrics))
        (performance-score (get efficiency-score performance))
        (liquidity-score (calculate-liquidity-score (get total-volume performance) amount))
        (slippage-score (calculate-slippage-score (get average-slippage performance))))
    
    ;; Weighted scoring: 40% load, 30% performance, 20% liquidity, 10% slippage
    (/ (+ (* load-score u40)
          (* performance-score u30)
          (* liquidity-score u20)
          (* slippage-score u10)) u100)))

(define-private (calculate-load-score (load-metrics {current-load: uint, capacity: uint, queue-depth: uint, last-load-update: uint}))
  (let ((utilization (if (> (get capacity load-metrics) u0)
                       (/ (* (get current-load load-metrics) u100) (get capacity load-metrics))
                       u0)))
    (if (<= utilization OPTIMAL_POOL_UTILIZATION)
      u100 ;; Optimal load
      (if (<= utilization MAX_POOL_UTILIZATION)
        (- u100 (/ (* (- utilization OPTIMAL_POOL_UTILIZATION) u100) (- MAX_POOL_UTILIZATION OPTIMAL_POOL_UTILIZATION)))
        u0)))) ;; Overloaded

(define-private (calculate-liquidity-score (total-vol uint) (amount uint))
  (if (>= total-vol (* amount u10))
    u100 ;; Excellent liquidity
    (if (>= total-vol amount)
      u75  ;; Good liquidity
      u25))) ;; Poor liquidity

(define-private (calculate-slippage-score (average-slippage uint))
  (if (<= average-slippage u50) ;; 0.5% or less
    u100
    (if (<= average-slippage u200) ;; 2% or less
      u75
      u25)))

;; Removed intermediate scored list; selection happens in a single fold with context.

;; =============================================================================
;; DYNAMIC LOAD BALANCING AND REBALANCING
;; =============================================================================

(define-public (rebalance-pool-loads)
  (begin
    (asserts! (var-get auto-rebalancing-enabled) (err u108))
    
    (let ((overloaded-pools (identify-overloaded-pools))
          (underutilized-pools (identify-underutilized-pools)))
      
      (if (and (> (len overloaded-pools) u0) (> (len underutilized-pools) u0))
        (begin
          (redistribute-pool-loads overloaded-pools underutilized-pools)
          (print {event: "pool-loads-rebalanced", timestamp: block-height})
          (ok true))
        (ok false))))) ;; No rebalancing needed

(define-private (identify-overloaded-pools)
  (filter is-pool-overloaded (get-all-active-pools)))

(define-private (identify-underutilized-pools)
  (filter is-pool-underutilized (get-all-active-pools)))

(define-private (is-pool-overloaded (pool principal))
  (let ((load-metrics (map-get? pool-load-metrics pool)))
    (match load-metrics
      metrics 
        (let ((utilization (if (> (get capacity metrics) u0)
                            (/ (* (get current-load metrics) u100) (get capacity metrics))
                            u0)))
          (> utilization (+ OPTIMAL_POOL_UTILIZATION REBALANCE_THRESHOLD)))
      false)))

(define-private (is-pool-underutilized (pool principal))
  (let ((load-metrics (map-get? pool-load-metrics pool)))
    (match load-metrics
      metrics 
        (let ((utilization (if (> (get capacity metrics) u0)
                            (/ (* (get current-load metrics) u100) (get capacity metrics))
                            u0)))
          (< utilization (- OPTIMAL_POOL_UTILIZATION REBALANCE_THRESHOLD)))
      false)))

(define-private (redistribute-pool-loads 
  (source-pools (list 100 principal))
  (target-pools (list 100 principal)))
  (let ((total-excess (fold + (map get-excess-load source-pools) u0))
        (total-headroom (fold + (map get-available-headroom target-pools) u0)))
    (if (and (> total-excess u0) (> total-headroom u0))
      (begin
        (fold reduce-source-load source-pools total-excess)
        (fold increase-target-load target-pools (min-uint total-excess total-headroom))
        true)
      false)))

(define-private (get-excess-load (pool principal))
  (let ((m (map-get? pool-load-metrics pool)))
    (match m mm
      (let ((util (if (> (get capacity mm) u0) (/ (* (get current-load mm) u100) (get capacity mm)) u0)))
        (if (> util MAX_POOL_UTILIZATION)
          (- util MAX_POOL_UTILIZATION)
          u0))
      u0)))

(define-private (get-available-headroom (pool principal))
  (let ((m (map-get? pool-load-metrics pool)))
    (match m mm
      (let ((util (if (> (get capacity mm) u0) (/ (* (get current-load mm) u100) (get capacity mm)) u0)))
        (if (< util OPTIMAL_POOL_UTILIZATION)
          (- OPTIMAL_POOL_UTILIZATION util)
          u0))
      u0)))

(define-private (reduce-source-load (pool principal) (remaining uint))
  (let ((m (default-to {current-load: u0, capacity: u1, queue-depth: u0, last-load-update: u0} (map-get? pool-load-metrics pool))))
    (let ((util (if (> (get capacity m) u0) (/ (* (get current-load m) u100) (get capacity m)) u0))
          (over (if (> (get capacity m) u0)
                   (if (> util MAX_POOL_UTILIZATION)
                     (/ (* (- util MAX_POOL_UTILIZATION) (get capacity m)) u100)
                     u0)
                   u0)))
      (let ((delta (if (> over remaining) remaining over)))
        (begin
          (map-set pool-load-metrics pool {
            current-load: (if (> (get current-load m) delta) (- (get current-load m) delta) u0),
            capacity: (get capacity m),
            queue-depth: (get queue-depth m),
            last-load-update: block-height
          })
          (- remaining delta))))))

(define-private (increase-target-load (pool principal) (remaining uint))
  (let ((m (default-to {current-load: u0, capacity: u1, queue-depth: u0, last-load-update: u0} (map-get? pool-load-metrics pool))))
    (let ((util (if (> (get capacity m) u0) (/ (* (get current-load m) u100) (get capacity m)) u0))
          (head (if (> (get capacity m) u0)
                   (/ (* (- OPTIMAL_POOL_UTILIZATION util) (get capacity m)) u100)
                   u0)))
      (let ((delta (if (> head remaining) remaining head)))
        (begin
          (map-set pool-load-metrics pool {
            current-load: (+ (get current-load m) delta),
            capacity: (get capacity m),
            queue-depth: (get queue-depth m),
            last-load-update: block-height
          })
          (- remaining delta))))))

(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b))

;; =============================================================================
;; PERFORMANCE MONITORING AND OPTIMIZATION
;; =============================================================================

(define-public (update-pool-performance 
  (pool principal)
  (volume uint)
  (fees uint)
  (slippage uint))
  (let ((current-perf (default-to
                       {total-volume: u0, total-fees: u0, swap-count: u0, average-slippage: u0,
                        last-activity: u0, efficiency-score: u100}
                       (map-get? pool-performance pool))))
    
    (let ((new-swap-count (+ (get swap-count current-perf) u1))
          (new-avg-slippage (/ (+ (* (get average-slippage current-perf) (get swap-count current-perf)) slippage) new-swap-count))
          (new-efficiency (calculate-efficiency-score 
                           (+ (get total-volume current-perf) volume)
                           (+ (get total-fees current-perf) fees)
                           new-avg-slippage)))
      
      (map-set pool-performance pool {
        total-volume: (+ (get total-volume current-perf) volume),
        total-fees: (+ (get total-fees current-perf) fees),
        swap-count: new-swap-count,
        average-slippage: new-avg-slippage,
        last-activity: block-height,
        efficiency-score: new-efficiency
      })
      
      ;; Update global volume
      (var-set total-volume (+ (var-get total-volume) volume))
      
      (ok true))))

(define-private (calculate-efficiency-score (volume uint) (fees uint) (slippage uint))
  (let ((fee-efficiency (if (> volume u0) (/ (* fees u10000) volume) u0))
        (slippage-penalty (if (< u50 (/ slippage u100)) u50 (/ slippage u100))))
    (if (> u10 (- u100 slippage-penalty)) u10 (- u100 slippage-penalty))))

;; =============================================================================
;; UTILITY FUNCTIONS
;; =============================================================================

;; Pool deployment tracking
(define-map pool-implementations uint principal) ;; fee-tier -> implementation

;; Initialize pool implementations (admin function)
(define-public (set-pool-implementation (fee-tier uint) (implementation principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-valid-fee-tier fee-tier) (err u107))
    (map-set pool-implementations fee-tier implementation)
    (ok true)))

;; NOTE: Pools are deployed externally by orchestrator scripts/contracts.
;; This contract registers pools and maintains routing/metrics.

;; Pool creation helper
;; create-pool-contract and prepare-pool-init-code removed in stubbed deployment path

(define-private (get-next-pool-id)
  (let ((current-id (var-get next-pool-id)))
    (var-set next-pool-id (+ current-id u1))
    current-id))

;; moved above to satisfy reference order

(define-constant MAX_GLOBAL_POOLS u100)
(define-data-var all-pools (list 100 principal) (list))

(define-private (contains-acc (item principal) (acc {found: bool, target: principal}))
  (if (or (get found acc) (is-eq item (get target acc)))
    {found: true, target: (get target acc)}
    acc))

(define-private (contains-principal (items (list 100 principal)) (p principal))
  (get found (fold contains-acc items {found: false, target: p})))

(define-private (update-routing-table (token-a principal) (token-b principal) (pool principal))
  (let ((current-pools (default-to (list) (map-get? token-pair-pools {token-a: token-a, token-b: token-b})))
        (global-pools (var-get all-pools)))
    (begin
      (if (< (len current-pools) MAX_POOLS_PER_PAIR)
        (map-set token-pair-pools {token-a: token-a, token-b: token-b} (unwrap-panic (as-max-len? (append current-pools pool) u10)))
        true)
      (if (and (< (len global-pools) MAX_GLOBAL_POOLS) (not (contains-principal global-pools pool)))
        (var-set all-pools (unwrap-panic (as-max-len? (append global-pools pool) u100)))
        true))))

(define-private (get-all-active-pools)
  (var-get all-pools))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-pool-info 
  (token-a principal) 
  (token-b principal) 
  (fee-tier uint))
  (map-get? pools {token-a: token-a, token-b: token-b, fee-tier: fee-tier}))

(define-read-only (get-pool-performance (pool principal))
  (map-get? pool-performance pool))

(define-read-only (get-pool-load-metrics (pool principal))
  (map-get? pool-load-metrics pool))

(define-read-only (get-available-pools (token-a principal) (token-b principal))
  (default-to (list) (map-get? token-pair-pools {token-a: token-a, token-b: token-b})))

(define-read-only (get-factory-stats)
  {
    total-pools: (var-get total-pools),
    total-volume: (var-get total-volume),
    factory-paused: (var-get factory-paused),
    auto-rebalancing: (var-get auto-rebalancing-enabled)
  })

(define-read-only (recommend-pool 
  (token-a principal) 
  (token-b principal) 
  (amount uint))
  (get-optimal-pool token-a token-b amount))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)))

(define-public (set-factory-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set factory-paused paused)
    (ok true)))

(define-public (set-auto-rebalancing (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set auto-rebalancing-enabled enabled)
    (ok true)))

(define-public (update-pool-capacity (pool principal) (new-capacity uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (let ((current-metrics (default-to
                            {current-load: u0, capacity: u1000, queue-depth: u0, last-load-update: u0}
                            (map-get? pool-load-metrics pool))))
      (map-set pool-load-metrics pool {
        current-load: (get current-load current-metrics),
        capacity: new-capacity,
        queue-depth: (get queue-depth current-metrics),
        last-load-update: block-height
      })
      (ok true))))
