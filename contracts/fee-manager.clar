;; Fee Manager - Centralized Fee Management System
;; Implements dynamic fee adjustment and multi-tier fee support
;; Supports 0.05%, 0.3%, and 1% fee tiers with market-based optimization

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision

;; Fee tier constants (in basis points)
(define-constant FEE_TIER_005 u5)    ;; 0.05%
(define-constant FEE_TIER_03 u30)    ;; 0.3%
(define-constant FEE_TIER_1 u100)    ;; 1%

;; Maximum fee limits
(define-constant MAX_FEE_BPS u1000)  ;; 10% maximum fee
(define-constant MIN_FEE_BPS u1)     ;; 0.01% minimum fee

;; Dynamic adjustment parameters
(define-constant VOLATILITY_THRESHOLD u500)  ;; 5% volatility threshold
(define-constant VOLUME_THRESHOLD u1000000)  ;; Volume threshold for adjustments

;; Error constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_INVALID_FEE_TIER u6001)
(define-constant ERR_INVALID_POOL u6002)
(define-constant ERR_FEE_TOO_HIGH u6003)
(define-constant ERR_INVALID_PARAMETERS u6004)

;; Data variables
(define-data-var protocol-fee-bps uint u0)
(define-data-var dynamic-adjustment-enabled bool true)
(define-data-var governance-address principal tx-sender)

;; Fee tier configurations
(define-map fee-tier-configs
  {tier: uint}
  {base-fee-bps: uint,
   min-fee-bps: uint,
   max-fee-bps: uint,
   volatility-multiplier: uint,
   volume-discount-bps: uint,
   enabled: bool})

;; Pool-specific fee overrides
(define-map pool-fee-overrides
  {pool: principal}
  {custom-fee-bps: uint,
   tier: uint,
   last-updated: uint,
   reason: (string-ascii 50)})

;; Fee performance analytics
(define-map fee-performance
  {pool: principal, period: uint}
  {total-fees-collected: uint,
   volume-24h: uint,
   lp-count: uint,
   CXG-fee-rate: uint,
   optimization-score: uint})

;; Market condition tracking
(define-map market-conditions
  {pool: principal}
  {volatility-24h: uint,
   volume-24h: uint,
   liquidity-depth: uint,
   last-updated: uint,
   trend: (string-ascii 10)})

;; Initialize fee manager
(define-public (initialize-fee-manager)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    
    ;; Initialize fee tier configurations
    (map-set fee-tier-configs
      {tier: FEE_TIER_005}
      {base-fee-bps: FEE_TIER_005,
       min-fee-bps: u1,
       max-fee-bps: u10,
       volatility-multiplier: u150,
       volume-discount-bps: u1,
       enabled: true})
    
    (map-set fee-tier-configs
      {tier: FEE_TIER_03}
      {base-fee-bps: FEE_TIER_03,
       min-fee-bps: u10,
       max-fee-bps: u50,
       volatility-multiplier: u120,
       volume-discount-bps: u5,
       enabled: true})
    
    (map-set fee-tier-configs
      {tier: FEE_TIER_1}
      {base-fee-bps: FEE_TIER_1,
       min-fee-bps: u50,
       max-fee-bps: u200,
       volatility-multiplier: u110,
       volume-discount-bps: u10,
       enabled: true})
    
    (print {event: "fee-manager-initialized", tiers: u3})
    (ok true)))

;; Calculate dynamic fee for a pool
(define-public (calculate-dynamic-fee (pool principal) (base-tier uint) (trade-size uint))
  (let ((tier-config (unwrap! (map-get? fee-tier-configs {tier: base-tier}) 
                              (err ERR_INVALID_FEE_TIER)))
        (market-data (get-market-conditions pool))
        (pool-override (map-get? pool-fee-overrides {pool: pool})))
    
    ;; Check for pool-specific override
    (match pool-override
      override (ok (get custom-fee-bps override))
      
      ;; Calculate dynamic fee based on market conditions
      (if (var-get dynamic-adjustment-enabled)
        (let ((base-fee (get base-fee-bps tier-config))
              (volatility (get volatility-24h market-data))
              (volume (get volume-24h market-data))
              (volatility-adjustment (calculate-volatility-adjustment volatility tier-config))
              (volume-discount (calculate-volume-discount volume trade-size tier-config)))
          
          (let ((adjusted-fee (+ base-fee volatility-adjustment)))
            (let ((final-fee (if (> volume-discount u0)
                               (- adjusted-fee volume-discount)
                               adjusted-fee)))
              
              ;; Ensure fee is within bounds
              (ok (max (get min-fee-bps tier-config)
                       (min (get max-fee-bps tier-config) final-fee))))))
        
        ;; Static fee if dynamic adjustment disabled
        (ok (get base-fee-bps tier-config))))))

;; Calculate volatility-based fee adjustment
(define-private (calculate-volatility-adjustment (volatility uint) (tier-config (tuple (base-fee-bps uint) (min-fee-bps uint) (max-fee-bps uint) (volatility-multiplier uint) (volume-discount-bps uint) (enabled bool))))
  (if (> volatility VOLATILITY_THRESHOLD)
    (/ (* (get base-fee-bps tier-config) (- volatility VOLATILITY_THRESHOLD) (get volatility-multiplier tier-config))
       (* u10000 u100)) ;; Convert from basis points
    u0))

;; Calculate volume-based discount
(define-private (calculate-volume-discount (volume uint) (trade-size uint) (tier-config (tuple (base-fee-bps uint) (min-fee-bps uint) (max-fee-bps uint) (volatility-multiplier uint) (volume-discount-bps uint) (enabled bool))))
  (if (and (> volume VOLUME_THRESHOLD) (> trade-size (/ volume u1000))) ;; Large trade relative to volume
    (/ (* trade-size (get volume-discount-bps tier-config)) volume)
    u0))

;; Update market conditions for a pool
(define-public (update-market-conditions 
  (pool principal) 
  (volatility uint) 
  (volume uint) 
  (liquidity uint))
  (begin
    (asserts! (is-authorized-updater) (err ERR_UNAUTHORIZED))
    
    (let ((trend (if (> volatility VOLATILITY_THRESHOLD) "HIGH" "NORMAL")))
      (map-set market-conditions
        {pool: pool}
        {volatility-24h: volatility,
         volume-24h: volume,
         liquidity-depth: liquidity,
         last-updated: block-height,
         trend: trend})
      
      (print {event: "market-conditions-updated", pool: pool, volatility: volatility})
      (ok true))))

;; Set pool-specific fee override
(define-public (set-pool-fee-override 
  (pool principal) 
  (custom-fee-bps uint) 
  (tier uint) 
  (reason (string-ascii 50)))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    (asserts! (<= custom-fee-bps MAX_FEE_BPS) (err ERR_FEE_TOO_HIGH))
    (asserts! (>= custom-fee-bps MIN_FEE_BPS) (err ERR_INVALID_PARAMETERS))
    
    (map-set pool-fee-overrides
      {pool: pool}
      {custom-fee-bps: custom-fee-bps,
       tier: tier,
       last-updated: block-height,
       reason: reason})
    
    (print {event: "pool-fee-override-set", pool: pool, fee: custom-fee-bps})
    (ok true)))

;; Remove pool fee override
(define-public (remove-pool-fee-override (pool principal))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    
    (map-delete pool-fee-overrides {pool: pool})
    (print {event: "pool-fee-override-removed", pool: pool})
    (ok true)))

;; Update fee tier configuration
(define-public (update-fee-tier-config
  (tier uint)
  (base-fee-bps uint)
  (min-fee-bps uint)
  (max-fee-bps uint)
  (volatility-multiplier uint)
  (volume-discount-bps uint))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    (asserts! (<= max-fee-bps MAX_FEE_BPS) (err ERR_FEE_TOO_HIGH))
    (asserts! (>= min-fee-bps MIN_FEE_BPS) (err ERR_INVALID_PARAMETERS))
    (asserts! (<= base-fee-bps max-fee-bps) (err ERR_INVALID_PARAMETERS))
    (asserts! (>= base-fee-bps min-fee-bps) (err ERR_INVALID_PARAMETERS))
    
    (map-set fee-tier-configs
      {tier: tier}
      {base-fee-bps: base-fee-bps,
       min-fee-bps: min-fee-bps,
       max-fee-bps: max-fee-bps,
       volatility-multiplier: volatility-multiplier,
       volume-discount-bps: volume-discount-bps,
       enabled: true})
    
    (print {event: "fee-tier-updated", tier: tier, base-fee: base-fee-bps})
    (ok true)))

;; Record fee performance metrics
(define-public (record-fee-performance
  (pool principal)
  (period uint)
  (fees-collected uint)
  (volume uint)
  (lp-count uint))
  (begin
    (asserts! (is-authorized-updater) (err ERR_UNAUTHORIZED))
    
    (let ((CXG-fee-rate (if (> volume u0) (/ (* fees-collected u10000) volume) u0))
          (optimization-score (calculate-optimization-score fees-collected volume lp-count)))
      
      (map-set fee-performance
        {pool: pool, period: period}
        {total-fees-collected: fees-collected,
         volume-24h: volume,
         lp-count: lp-count,
         CXG-fee-rate: CXG-fee-rate,
         optimization-score: optimization-score})
      
      (print {event: "fee-performance-recorded", pool: pool, score: optimization-score})
      (ok true))))

;; Calculate optimization score (0-100)
(define-private (calculate-optimization-score (fees uint) (volume uint) (lp-count uint))
  (let ((fee-efficiency (if (> volume u0) (/ (* fees u100) volume) u0))
        (liquidity-factor (min u100 lp-count))
        (volume-factor (min u100 (/ volume u10000))))
    
    (/ (+ fee-efficiency liquidity-factor volume-factor) u3)))

;; Get optimal fee tier recommendation
(define-read-only (get-optimal-fee-tier (pool principal) (current-tier uint))
  (let ((market-data (get-market-conditions pool))
        (current-performance (map-get? fee-performance {pool: pool, period: block-height})))
    
    (match current-performance
      perf (let ((optimization-score (get optimization-score perf))
                 (volatility (get volatility-24h market-data))
                 (volume (get volume-24h market-data)))
             
             ;; Recommend tier based on market conditions
             (if (< optimization-score u30)
               ;; Low performance - suggest lower tier
               (if (is-eq current-tier FEE_TIER_1) FEE_TIER_03
                   (if (is-eq current-tier FEE_TIER_03) FEE_TIER_005 current-tier))
               
               ;; Good performance - consider higher tier if high volume
               (if (and (> volume VOLUME_THRESHOLD) (< volatility VOLATILITY_THRESHOLD))
                 (if (is-eq current-tier FEE_TIER_005) FEE_TIER_03
                     (if (is-eq current-tier FEE_TIER_03) FEE_TIER_1 current-tier))
                 current-tier)))
      
      ;; No performance data - use conservative approach
      (if (> (get volatility-24h market-data) VOLATILITY_THRESHOLD)
        FEE_TIER_005  ;; Low fee for high volatility
        FEE_TIER_03)))) ;; Standard fee

;; Administrative functions
(define-public (set-protocol-fee (fee-bps uint))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    (asserts! (<= fee-bps u1000) (err ERR_FEE_TOO_HIGH)) ;; Max 10%
    
    (var-set protocol-fee-bps fee-bps)
    (print {event: "protocol-fee-updated", fee: fee-bps})
    (ok true)))

(define-public (set-dynamic-adjustment (enabled bool))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    
    (var-set dynamic-adjustment-enabled enabled)
    (print {event: "dynamic-adjustment-toggled", enabled: enabled})
    (ok true)))

(define-public (set-governance-address (new-governance principal))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    
    (var-set governance-address new-governance)
    (print {event: "governance-updated", new-governance: new-governance})
    (ok true)))

;; Read-only functions
(define-read-only (get-fee-tier-config (tier uint))
  (map-get? fee-tier-configs {tier: tier}))

(define-read-only (get-pool-fee-override (pool principal))
  (map-get? pool-fee-overrides {pool: pool}))

(define-read-only (get-market-conditions (pool principal))
  (default-to 
    {volatility-24h: u0, volume-24h: u0, liquidity-depth: u0, last-updated: u0, trend: "UNKNOWN"}
    (map-get? market-conditions {pool: pool})))

(define-read-only (get-fee-performance (pool principal) (period uint))
  (map-get? fee-performance {pool: pool, period: period}))

(define-read-only (get-protocol-fee)
  (var-get protocol-fee-bps))

(define-read-only (is-dynamic-adjustment-enabled)
  (var-get dynamic-adjustment-enabled))

;; Authorization helpers
(define-private (is-governance)
  (is-eq tx-sender (var-get governance-address)))

(define-private (is-authorized-updater)
  (or (is-governance)
      (is-eq tx-sender CONTRACT_OWNER)))

;; Fee analytics functions
(define-read-only (get-fee-analytics-summary (pool principal))
  (let ((market-data (get-market-conditions pool))
        (recent-performance (map-get? fee-performance {pool: pool, period: block-height}))
        (override (map-get? pool-fee-overrides {pool: pool})))
    
    {pool: pool,
     market-conditions: market-data,
     performance: recent-performance,
     override: override,
     recommended-tier: (get-optimal-fee-tier pool FEE_TIER_03)}))

(define-read-only (calculate-fee-impact (pool principal) (tier uint) (trade-size uint))
  (match (calculate-dynamic-fee pool tier trade-size)
    fee-bps (let ((fee-amount (/ (* trade-size fee-bps) u10000)))
              (some {fee-bps: fee-bps,
                     fee-amount: fee-amount,
                     effective-rate: (/ (* fee-amount u10000) trade-size)}))
    none))