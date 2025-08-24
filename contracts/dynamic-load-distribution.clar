;; AutoVault Dynamic Load Distribution Implementation  
;; Target: +35K TPS through intelligent routing and load balancing

;; =============================================================================
;; LOAD DISTRIBUTION CONSTANTS
;; =============================================================================

(define-constant MAX_POOL_UTILIZATION u9000) ;; 90% max utilization
(define-constant OPTIMAL_UTILIZATION u7000) ;; 70% optimal utilization
(define-constant REBALANCE_THRESHOLD u1000) ;; 10% difference threshold
(define-constant MAX_POOLS_PER_TOKEN u10) ;; Maximum pools per token pair

;; Load balancing weights
(define-constant UTILIZATION_WEIGHT u40) ;; 40% weight
(define-constant LIQUIDITY_WEIGHT u30) ;; 30% weight  
(define-constant FEE_WEIGHT u20) ;; 20% weight
(define-constant PERFORMANCE_WEIGHT u10) ;; 10% weight

;; =============================================================================
;; LOAD TRACKING DATA STRUCTURES
;; =============================================================================

(define-map pool-metrics principal {
  current-utilization: uint,
  total-liquidity: uint,
  average-fee: uint,
  performance-score: uint,
  last-update: uint,
  transaction-count: uint,
  volume-24h: uint
})

(define-map token-pools {token-a: principal, token-b: principal} (list 10 principal))

(define-map pool-performance principal {
  success-rate: uint,
  average-execution-time: uint,
  slippage-average: uint,
  last-performance-update: uint
})

(define-map load-distribution-state uint {
  total-pools: uint,
  active-pools: uint,
  total-volume: uint,
  rebalance-count: uint,
  last-global-rebalance: uint
})

;; =============================================================================
;; INTELLIGENT POOL SELECTION
;; =============================================================================

(define-public (select-optimal-pool 
  (token-a principal) 
  (token-b principal) 
  (amount uint))
  (let ((available-pools (default-to (list) (map-get? token-pools {token-a: token-a, token-b: token-b}))))
    (if (> (len available-pools) u0)
      (let ((best-result (fold select-better-pool-with-context 
                              available-pools 
                              {best: none, best-score: u0}))
            (best-pool (get best best-result)))
        (match best-pool
          pool-found (ok pool-found)
          (err u301))) ;; No suitable pool found
      (err u302)))) ;; No pools available

(define-private (select-better-pool-with-context 
  (pool principal)
  (acc {best: (optional principal), best-score: uint}))
  (let (
        (metrics (default-to 
                   {current-utilization: u0, total-liquidity: u0, average-fee: u0, 
                    performance-score: u0, last-update: u0, transaction-count: u0, volume-24h: u0}
                   (map-get? pool-metrics pool)))
        (score (get performance-score metrics)))
    (if (> score (get best-score acc))
      {best: (some pool), best-score: score}
      acc)))

;; Simplified helper functions for load distribution

(define-private (calculate-utilization-score (utilization uint))
  (if (<= utilization OPTIMAL_UTILIZATION)
    ;; Under-utilized pools get higher scores
    (/ (* (- OPTIMAL_UTILIZATION utilization) u10000) OPTIMAL_UTILIZATION)
    ;; Over-utilized pools get lower scores
    (if (<= utilization MAX_POOL_UTILIZATION)
      (/ (* (- MAX_POOL_UTILIZATION utilization) u10000) (- MAX_POOL_UTILIZATION OPTIMAL_UTILIZATION))
      u0))) ;; Pools at max utilization get 0 score

(define-private (calculate-liquidity-score (liquidity uint) (amount uint))
  (if (>= liquidity (* amount u10)) ;; 10x the transaction amount
    u10000 ;; Perfect score
    (if (>= liquidity (* amount u2)) ;; 2x the transaction amount
      u7500 ;; Good score
      (if (>= liquidity amount) ;; At least the transaction amount
        u5000 ;; Acceptable score
        u1000)))) ;; Poor score

(define-private (calculate-fee-score (average-fee uint))
  (let ((max-acceptable-fee u10000)) ;; 1% max fee
    (if (<= average-fee max-acceptable-fee)
      (- u10000 (/ (* average-fee u10000) max-acceptable-fee))
      u0)))

;; No need for an intermediate scored list; selection is done in one pass with context.

;; =============================================================================
;; DYNAMIC LOAD BALANCING
;; =============================================================================

(define-public (rebalance-pool-loads)
  (let ((pools-to-rebalance (identify-overutilized-pools))
        (target-pools (identify-underutilized-pools)))
    (if (and (> (len pools-to-rebalance) u0) (> (len target-pools) u0))
      (begin
        (unwrap-panic (execute-load-redistribution pools-to-rebalance target-pools))
        (update-global-rebalance-state)
        (ok true))
      (ok false)))) ;; No rebalancing needed

(define-private (get-all-active-pools)
  ;; Pull from factory-enhanced; returns (list 10 principal)
  (contract-call? .dex-factory-enhanced get-available-pools tx-sender tx-sender))
(define-private (identify-overutilized-pools)
  (filter is-overutilized (get-all-active-pools)))

(define-private (identify-underutilized-pools) 
  (filter is-underutilized (get-all-active-pools)))

(define-private (is-overutilized (pool principal))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data (> (get current-utilization pool-data) (+ OPTIMAL_UTILIZATION REBALANCE_THRESHOLD))
      false)))

(define-private (is-underutilized (pool principal))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data (< (get current-utilization pool-data) (- OPTIMAL_UTILIZATION REBALANCE_THRESHOLD))
      false)))

(define-private (execute-load-redistribution 
  (source-pools (list 10 principal))
  (target-pools (list 10 principal)))
  (let ((redistribution-amount (calculate-redistribution-amount source-pools target-pools)))
    (begin
      (unwrap-panic (drain-excess-liquidity source-pools redistribution-amount))
      (unwrap-panic (distribute-liquidity target-pools redistribution-amount))
      (ok true))))

(define-private (calculate-redistribution-amount 
  (source-pools (list 10 principal))
  (target-pools (list 10 principal)))
  (let ((total-excess (fold + (map get-excess-utilization source-pools) u0))
        (total-capacity (fold + (map get-available-capacity target-pools) u0)))
    (if (< total-excess total-capacity) total-excess total-capacity)))

;; =============================================================================
;; REAL-TIME UTILIZATION TRACKING
;; =============================================================================

(define-public (update-pool-metrics 
  (pool principal)
  (transaction-amount uint)
  (operation (string-ascii 10)))
  (let ((current-metrics (default-to 
                          {current-utilization: u0, total-liquidity: u0, average-fee: u0,
                           performance-score: u0, last-update: u0, transaction-count: u0, volume-24h: u0}
                          (map-get? pool-metrics pool)))
        (new-utilization (calculate-new-utilization pool transaction-amount operation))
        (new-volume (+ (get volume-24h current-metrics) transaction-amount)))
    (begin
      (map-set pool-metrics pool {
        current-utilization: new-utilization,
        total-liquidity: (get total-liquidity current-metrics),
        average-fee: (get average-fee current-metrics),
        performance-score: (get performance-score current-metrics),
        last-update: block-height,
        transaction-count: (+ (get transaction-count current-metrics) u1),
        volume-24h: new-volume
      })
      (unwrap-panic (check-and-trigger-rebalancing pool))
      (ok true))))

(define-private (calculate-new-utilization 
  (pool principal)
  (transaction-amount uint)
  (operation (string-ascii 10)))
  (let ((current-metrics (map-get? pool-metrics pool)))
    (match current-metrics
      metrics
        (let ((current-util (get current-utilization metrics))
              (total-liquidity (get total-liquidity metrics)))
          (if (> total-liquidity u0)
            (if (is-eq operation "deposit")
              ;; Deposit increases utilization
              (let ((new-util (+ current-util (/ (* transaction-amount u10000) total-liquidity))))
                (if (< new-util MAX_POOL_UTILIZATION) new-util MAX_POOL_UTILIZATION))
              ;; Withdrawal decreases utilization  
              (if (>= current-util (/ (* transaction-amount u10000) total-liquidity))
                (- current-util (/ (* transaction-amount u10000) total-liquidity))
                u0))
            u0))
      u0)))

(define-private (check-and-trigger-rebalancing (pool principal))
  (let ((metrics (unwrap! (map-get? pool-metrics pool) (err u303))))
    (if (or 
          (> (get current-utilization metrics) MAX_POOL_UTILIZATION)
          (< (get current-utilization metrics) (/ OPTIMAL_UTILIZATION u2)))
      (rebalance-pool-loads)
      (ok false))))

;; =============================================================================
;; CAPACITY-BASED FEE ADJUSTMENT
;; =============================================================================

(define-public (get-dynamic-fee 
  (pool principal)
  (base-fee uint))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data
        (let ((utilization (get current-utilization pool-data)))
          (ok (calculate-utilization-adjusted-fee base-fee utilization)))
      (ok base-fee))))

(define-private (calculate-utilization-adjusted-fee (base-fee uint) (utilization uint))
  (if (> utilization u9000) 
    (* base-fee u150) ;; 1.5x fee at >90% utilization
    (if (> utilization u8000) 
      (* base-fee u125) ;; 1.25x fee at >80% utilization
      (if (> utilization u7000) 
        base-fee ;; Normal fee at optimal utilization
        (if (< utilization u3000) 
          (/ (* base-fee u75) u100) ;; 0.75x fee at <30% utilization
          base-fee))))) ;; Default fee

;; =============================================================================
;; PERFORMANCE MONITORING
;; =============================================================================

(define-public (update-pool-performance 
  (pool principal)
  (execution-time uint)
  (success bool)
  (slippage uint))
  (let ((current-performance (default-to
                              {success-rate: u10000, average-execution-time: u0, slippage-average: u0, last-performance-update: u0}
                              (map-get? pool-performance pool)))
        (new-success-rate (update-success-rate (get success-rate current-performance) success))
        (new-avg-time (update-average-time (get average-execution-time current-performance) execution-time))
        (new-avg-slippage (update-average-slippage (get slippage-average current-performance) slippage)))
    (begin
      (map-set pool-performance pool {
        success-rate: new-success-rate,
        average-execution-time: new-avg-time,
        slippage-average: new-avg-slippage,
        last-performance-update: block-height
      })
      (ok true))))

(define-private (update-success-rate (current-rate uint) (success bool))
  (let ((weight u90)) ;; 90% weight to historical data
    (if success
      (/ (+ (* current-rate weight) (* u10000 (- u100 weight))) u100)
      (/ (* current-rate weight) u100))))

(define-private (update-average-time (current-avg uint) (new-time uint))
  (let ((weight u90)) ;; 90% weight to historical data
    (/ (+ (* current-avg weight) (* new-time (- u100 weight))) u100)))

(define-private (update-average-slippage (current-avg uint) (new-slippage uint))
  (let ((weight u90)) ;; 90% weight to historical data  
    (/ (+ (* current-avg weight) (* new-slippage (- u100 weight))) u100)))

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

(define-private (get-excess-utilization (pool principal))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data
        (if (> (get current-utilization pool-data) OPTIMAL_UTILIZATION)
          (- (get current-utilization pool-data) OPTIMAL_UTILIZATION)
          u0)
      u0)))

(define-private (get-available-capacity (pool principal))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data
        (if (< (get current-utilization pool-data) OPTIMAL_UTILIZATION)
          (- OPTIMAL_UTILIZATION (get current-utilization pool-data))
          u0)
      u0)))

(define-private (drain-excess-liquidity (pools (list 10 principal)) (amount uint))
  ;; Model capacity reduction proportional to amount across pools
  (let ((per-pool (if (> (len pools) u0) (/ amount (len pools)) u0)))
    (begin
      (fold reduce-one pools per-pool)
      (ok true))))

(define-private (reduce-one (pool principal) (delta uint))
  (let ((m (map-get? pool-metrics pool)))
    (match m mm
      (begin
        (map-set pool-metrics pool {
          current-utilization: (if (> (get current-utilization mm) delta) (- (get current-utilization mm) delta) u0),
          total-liquidity: (get total-liquidity mm),
          average-fee: (get average-fee mm),
          performance-score: (get performance-score mm),
          last-update: block-height,
          transaction-count: (get transaction-count mm),
          volume-24h: (get volume-24h mm)
        })
        delta)
      delta)))

(define-private (distribute-liquidity (pools (list 10 principal)) (amount uint))
  (let ((per-pool (if (> (len pools) u0) (/ amount (len pools)) u0)))
    (begin
      (fold add-one pools per-pool)
      (ok true))))

(define-private (add-one (pool principal) (delta uint))
  (let ((m (map-get? pool-metrics pool)))
    (match m mm
      (begin
        (map-set pool-metrics pool {
          current-utilization: (+ (get current-utilization mm) delta),
          total-liquidity: (get total-liquidity mm),
          average-fee: (get average-fee mm),
          performance-score: (get performance-score mm),
          last-update: block-height,
          transaction-count: (get transaction-count mm),
          volume-24h: (get volume-24h mm)
        })
        delta)
      delta)))

(define-private (update-global-rebalance-state)
  (let ((current-state (default-to 
                        {total-pools: u0, active-pools: u0, total-volume: u0, rebalance-count: u0, last-global-rebalance: u0}
                        (map-get? load-distribution-state u0))))
    (map-set load-distribution-state u0 {
      total-pools: (get total-pools current-state),
      active-pools: (get active-pools current-state),
      total-volume: (get total-volume current-state),
      rebalance-count: (+ (get rebalance-count current-state) u1),
      last-global-rebalance: block-height
    })))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-pool-metrics (pool principal))
  (map-get? pool-metrics pool))

(define-read-only (get-pool-utilization (pool principal))
  (let ((metrics (map-get? pool-metrics pool)))
    (match metrics
      pool-data (ok (get current-utilization pool-data))
      (ok u0))))

(define-public (get-pool-utilization-public (pool principal))
  (get-pool-utilization pool))

(define-read-only (get-pool-performance (pool principal))
  (map-get? pool-performance pool))

(define-read-only (get-load-distribution-stats)
  (map-get? load-distribution-state u0))

(define-read-only (recommend-pool 
  (token-a principal) 
  (token-b principal) 
  (amount uint))
  (select-optimal-pool token-a token-b amount))
