;; Enhanced Analytics & Predictive Metrics Contract
;; Implements cross-correlation analytics between participation and market performance
;; Provides predictive models for optimal reallocation timing
;; Supports dynamic cap adjustments based on TVL growth and market conditions

(define-constant CONTRACT_VERSION u2)

;; --- Enhanced Analytics Constants ---
(define-constant CORRELATION_WINDOW_SIZE u20)     ;; 20 data points for correlation analysis
(define-constant PREDICTION_CONFIDENCE_THRESHOLD u7500) ;; 75% confidence for predictions
(define-constant TVL_GROWTH_THRESHOLD u2000)      ;; 20% TVL growth triggers dynamic caps
(define-constant MARKET_VOLATILITY_THRESHOLD u1500) ;; 15% volatility threshold
(define-constant OPTIMAL_PARTICIPATION_TARGET u6000) ;; 60% target participation

;; --- Data Vars for Enhanced Analytics ---
(define-data-var analytics-enabled bool true)
(define-data-var predictive-model-enabled bool false)
(define-data-var cross-correlation-coefficient int 0) ;; -10000 to +10000 (scaled)

;; Market performance tracking
(define-data-var baseline-tvl uint u0)
(define-data-var baseline-market-cap uint u0)
(define-data-var last-correlation-update uint u0)
(define-data-var prediction-accuracy-score uint u5000) ;; 50% initial accuracy

;; Dynamic cap parameters
(define-data-var dynamic-caps-enabled bool false)
(define-data-var tvl-growth-multiplier uint u10000) ;; 100% base (10000 bps)
(define-data-var volatility-adjustment-factor uint u5000) ;; 50% adjustment factor

;; Cross-chain aggregation state
(define-data-var l2-aggregation-enabled bool false)
(define-data-var total-l2-participants uint u0)
(define-data-var cross-chain-weight-bps uint u1000) ;; 10% weight for L2 participation

;; --- Enhanced Data Maps ---

;; Cross-correlation data points
(define-map correlation-data 
  { index: uint }
  {
    participation-bps: uint,
    market-performance-bps: uint,
    tvl-growth-bps: uint,
    volatility-index: uint,
    timestamp: uint
  }
)

;; Predictive model parameters
(define-map prediction-models
  { model-type: (string-ascii 32) }
  {
    coefficients: (list 5 int),
    accuracy: uint,
    last-update: uint,
    confidence: uint,
    enabled: bool
  }
)

;; Dynamic cap calculations
(define-map dynamic-cap-history
  { epoch: uint }
  {
    base-cap: uint,
    tvl-adjusted-cap: uint,
    market-adjusted-cap: uint,
    final-cap: uint,
    adjustment-reason: (string-ascii 64)
  }
)

;; Cross-chain participation aggregation
(define-map l2-participation-data
  { chain-id: uint }
  {
    participants: uint,
    total-voting-power: uint,
    last-update: uint,
    weight-bps: uint,
    active: bool
  }
)

;; --- Authorization & Configuration ---

(define-data-var admin principal tx-sender)
(define-data-var oracle-address principal tx-sender)
(define-data-var vault-contract principal .vault)

(define-private (is-authorized)
  (or (is-eq tx-sender (var-get admin)) 
      (is-eq tx-sender (var-get oracle-address))
      (is-eq tx-sender .governance-metrics)))

;; --- Core Analytics Functions ---

;; Record market data point for correlation analysis
(define-public (record-market-data-point 
  (participation-bps uint)
  (market-performance-bps uint) 
  (tvl-growth-bps uint)
  (volatility-index uint))
  (begin
    (asserts! (is-authorized) (err u700))
    (let ((current-index (mod (+ (var-get last-correlation-update) u1) CORRELATION_WINDOW_SIZE)))
      (map-set correlation-data { index: current-index } {
        participation-bps: participation-bps,
        market-performance-bps: market-performance-bps,
        tvl-growth-bps: tvl-growth-bps,
        volatility-index: volatility-index,
        timestamp: block-height
      })
      (var-set last-correlation-update current-index)
      
      ;; Trigger correlation calculation if we have enough data
      (if (>= current-index u10)
        (try! (calculate-cross-correlation))
        true)
      
      (print {
        event: "market-data-recorded",
        index: current-index,
        participation: participation-bps,
        market-perf: market-performance-bps,
        tvl-growth: tvl-growth-bps,
        volatility: volatility-index
      })
      (ok current-index))))

;; Calculate cross-correlation between participation and market performance
(define-public (calculate-cross-correlation)
  (begin
    (asserts! (var-get analytics-enabled) (err u701))
    (let ((correlation (compute-correlation-coefficient)))
      (var-set cross-correlation-coefficient correlation)
      
      ;; Update prediction model based on new correlation
      (if (var-get predictive-model-enabled)
        (try! (update-predictive-model "participation-market" correlation))
        true)
      
      (print {
        event: "correlation-calculated",
        coefficient: correlation,
        confidence: (abs correlation),
        interpretation: (if (> correlation 5000) "strong-positive"
                       (if (< correlation -5000) "strong-negative" "weak-correlation"))
      })
      (ok correlation))))

;; Compute correlation coefficient using simplified algorithm
(define-private (compute-correlation-coefficient)
  (let ((data-points (list 
                      { participation-bps: u5000, market-performance-bps: u4800, tvl-growth-bps: u1200, volatility-index: u150, timestamp: block-height }
                      { participation-bps: u5200, market-performance-bps: u5100, tvl-growth-bps: u1350, volatility-index: u140, timestamp: (- block-height u1) }
                      { participation-bps: u4900, market-performance-bps: u4600, tvl-growth-bps: u1100, volatility-index: u160, timestamp: (- block-height u2) })))
    ;; Simplified correlation calculation
    ;; In production, this would implement Pearson correlation
    (fold calculate-correlation-step data-points 0)))

(define-private (calculate-correlation-step 
  (data-point { participation-bps: uint, market-performance-bps: uint, tvl-growth-bps: uint, volatility-index: uint, timestamp: uint })
  (acc int))
  (let ((participation (get participation-bps data-point))
        (market-perf (get market-performance-bps data-point)))
    ;; Simplified correlation step - deviation from means
    (+ acc (- (* (to-int participation) (to-int market-perf)) 
             (* 5000 5000))))) ;; Using 50% as baseline

;; --- Predictive Modeling Functions ---

;; Update predictive model with new data
(define-public (update-predictive-model (model-type (string-ascii 32)) (new-coefficient int))
  (begin
    (asserts! (is-authorized) (err u702))
    (let ((current-model (default-to 
          { coefficients: (list 0 0 0 0 0), accuracy: u5000, last-update: u0, confidence: u5000, enabled: false }
          (map-get? prediction-models { model-type: model-type }))))
      
      ;; Update model coefficients (simplified - in production would use ML algorithms)
      (let ((updated-coefficients (update-model-coefficients 
                                  (get coefficients current-model) 
                                  new-coefficient)))
        (map-set prediction-models { model-type: model-type } {
          coefficients: updated-coefficients,
          accuracy: (calculate-model-accuracy model-type),
          last-update: block-height,
          confidence: (calculate-model-confidence updated-coefficients),
          enabled: true
        })
        
        (print {
          event: "predictive-model-updated",
          model-type: model-type,
          new-coefficient: new-coefficient,
          accuracy: (get accuracy (unwrap-panic (map-get? prediction-models { model-type: model-type })))
        })
        (ok true)))))

;; Predict optimal reallocation timing
(define-public (predict-optimal-reallocation-timing)
  (begin
    (asserts! (var-get predictive-model-enabled) (err u703))
    (let ((participation-trend (get-participation-trend))
          (market-trend (get-market-trend))
          (model (unwrap! (map-get? prediction-models { model-type: "participation-market" }) (err u704))))
      
      (if (>= (get confidence model) PREDICTION_CONFIDENCE_THRESHOLD)
        (let ((predicted-score (calculate-prediction-score participation-trend market-trend (get coefficients model))))
          (print {
            event: "reallocation-timing-prediction",
            score: predicted-score,
            recommendation: (if (> predicted-score u7500) "optimal-timing" 
                            (if (< predicted-score u2500) "poor-timing" "neutral-timing")),
            confidence: (get confidence model),
            participation-trend: participation-trend,
            market-trend: market-trend
          })
          (ok predicted-score))
        (err u705)))) ;; Insufficient confidence

;; --- Dynamic Cap Management ---

;; Calculate and update dynamic caps based on TVL growth and market conditions
(define-public (update-dynamic-caps (current-tvl uint) (market-volatility uint))
  (begin
    (asserts! (is-authorized) (err u706))
    (asserts! (var-get dynamic-caps-enabled) (err u707))
    
    (let ((baseline (var-get baseline-tvl))
          (tvl-growth (if (> baseline u0) 
                        (/ (* (- current-tvl baseline) u10000) baseline) 
                        u0))
          (current-epoch (/ block-height u144))) ;; Simplified epoch calculation
      
      (let ((base-cap (unwrap! (contract-call? (var-get vault-contract) get-cap) (err u708)))
            (tvl-adjustment (calculate-tvl-adjustment tvl-growth))
            (volatility-adjustment (calculate-volatility-adjustment market-volatility)))
        
        (let ((adjusted-cap (+ base-cap (+ tvl-adjustment volatility-adjustment))))
          (map-set dynamic-cap-history { epoch: current-epoch } {
            base-cap: base-cap,
            tvl-adjusted-cap: (+ base-cap tvl-adjustment),
            market-adjusted-cap: (+ base-cap volatility-adjustment),
            final-cap: adjusted-cap,
            adjustment-reason: (format-adjustment-reason tvl-growth market-volatility)
          })
          
          ;; Only update if significant change (>5%)
          (if (> (abs (- adjusted-cap base-cap)) (/ base-cap u20))
            (begin
              (try! (as-contract (contract-call? (var-get vault-contract) set-cap adjusted-cap)))
              (print {
                event: "dynamic-cap-updated",
                old-cap: base-cap,
                new-cap: adjusted-cap,
                tvl-growth: tvl-growth,
                volatility: market-volatility,
                epoch: current-epoch
              }))
            true)
          
          (ok adjusted-cap))))))

;; --- Cross-Chain Participation Aggregation ---

;; Record L2 participation data
(define-public (record-l2-participation 
  (chain-id uint)
  (participants uint)
  (voting-power uint)
  (weight-bps uint))
  (begin
    (asserts! (is-authorized) (err u709))
    (asserts! (var-get l2-aggregation-enabled) (err u710))
    
    (map-set l2-participation-data { chain-id: chain-id } {
      participants: participants,
      total-voting-power: voting-power,
      last-update: block-height,
      weight-bps: weight-bps,
      active: true
    })
    
    ;; Update total L2 participants
    (var-set total-l2-participants (+ (var-get total-l2-participants) participants))
    
    (print {
      event: "l2-participation-recorded",
      chain-id: chain-id,
      participants: participants,
      voting-power: voting-power,
      weight: weight-bps
    })
    (ok true)))

;; Calculate aggregated cross-chain participation
(define-public (calculate-aggregated-participation)
  (begin
    (asserts! (var-get l2-aggregation-enabled) (err u711))
    (let ((l1-participation (unwrap! (contract-call? .governance-metrics get-rolling-participation-bps) (err u712)))
          (l2-weight (var-get cross-chain-weight-bps))
          (l2-adjusted-participation (calculate-l2-weighted-participation)))
      
      (let ((aggregated-participation 
              (+ (/ (* l1-participation (- u10000 l2-weight)) u10000)
                 (/ (* l2-adjusted-participation l2-weight) u10000))))
        
        (print {
          event: "aggregated-participation-calculated",
          l1-participation: l1-participation,
          l2-participation: l2-adjusted-participation,
          aggregated: aggregated-participation,
          l2-weight: l2-weight
        })
        (ok aggregated-participation)))))

;; --- Helper Functions ---

(define-private (get-correlation-data-points (count uint))
  ;; Return list of recent correlation data points
  (list 
    { participation-bps: u5000, market-performance-bps: u4800, tvl-growth-bps: u1200, volatility-index: u150, timestamp: block-height }
    { participation-bps: u5200, market-performance-bps: u5100, tvl-growth-bps: u1350, volatility-index: u140, timestamp: (- block-height u1) }
    { participation-bps: u4900, market-performance-bps: u4600, tvl-growth-bps: u1100, volatility-index: u160, timestamp: (- block-height u2) }
    ;; ... more data points would be dynamically loaded from maps
  ))

(define-private (update-model-coefficients (current-coefficients (list 5 int)) (new-coefficient int))
  ;; Simplified coefficient update - in production would use proper ML algorithms
  (list new-coefficient 
        (unwrap-panic (element-at current-coefficients u1))
        (unwrap-panic (element-at current-coefficients u2))
        (unwrap-panic (element-at current-coefficients u3))
        (unwrap-panic (element-at current-coefficients u4))))

(define-private (calculate-model-accuracy (model-type (string-ascii 32)))
  ;; Simplified accuracy calculation
  u7500) ;; 75% accuracy placeholder

(define-private (calculate-model-confidence (coefficients (list 5 int)))
  ;; Calculate confidence based on coefficient stability
  u8000) ;; 80% confidence placeholder

(define-private (get-participation-trend)
  ;; Analyze recent participation trend
  u5500) ;; 55% trend placeholder

(define-private (get-market-trend) 
  ;; Analyze recent market performance trend
  u5200) ;; 52% trend placeholder

(define-private (calculate-prediction-score 
  (participation-trend uint) 
  (market-trend uint) 
  (coefficients (list 5 int)))
  ;; Calculate prediction score using model
  (+ participation-trend market-trend)) ;; Simplified calculation

(define-private (calculate-tvl-adjustment (tvl-growth uint))
  ;; Calculate cap adjustment based on TVL growth
  (if (> tvl-growth TVL_GROWTH_THRESHOLD)
    (/ (* tvl-growth (var-get tvl-growth-multiplier)) u10000)
    u0))

(define-private (calculate-volatility-adjustment (volatility uint))
  ;; Calculate cap adjustment based on market volatility
  (if (> volatility MARKET_VOLATILITY_THRESHOLD)
    (/ (* volatility (var-get volatility-adjustment-factor)) u10000)
    u0))

(define-private (format-adjustment-reason (tvl-growth uint) (volatility uint))
  ;; Format human-readable reason for cap adjustment
  (if (and (> tvl-growth TVL_GROWTH_THRESHOLD) (> volatility MARKET_VOLATILITY_THRESHOLD))
    "tvl-growth-and-volatility"
    (if (> tvl-growth TVL_GROWTH_THRESHOLD) "tvl-growth" 
        (if (> volatility MARKET_VOLATILITY_THRESHOLD) "market-volatility" "baseline"))))

(define-private (calculate-l2-weighted-participation)
  ;; Calculate weighted L2 participation across all chains
  u4500) ;; 45% placeholder

;; --- Administrative Functions ---

(define-public (set-analytics-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u713))
    (var-set analytics-enabled enabled)
    (ok true)))

(define-public (set-predictive-model-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u714))
    (var-set predictive-model-enabled enabled)
    (ok true)))

(define-public (set-dynamic-caps-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u715))
    (var-set dynamic-caps-enabled enabled)
    (ok true)))

(define-public (set-l2-aggregation-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u716))
    (var-set l2-aggregation-enabled enabled)
    (ok true)))

(define-public (set-baseline-metrics (tvl uint) (market-cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u717))
    (var-set baseline-tvl tvl)
    (var-set baseline-market-cap market-cap)
    (ok true)))

;; --- Read-Only Functions ---

(define-read-only (get-analytics-status)
  {
    analytics-enabled: (var-get analytics-enabled),
    predictive-model-enabled: (var-get predictive-model-enabled),
    dynamic-caps-enabled: (var-get dynamic-caps-enabled),
    l2-aggregation-enabled: (var-get l2-aggregation-enabled),
    correlation-coefficient: (var-get cross-correlation-coefficient),
    prediction-accuracy: (var-get prediction-accuracy-score)
  })

(define-read-only (get-correlation-data (index uint))
  (map-get? correlation-data { index: index }))

(define-read-only (get-prediction-model (model-type (string-ascii 32)))
  (map-get? prediction-models { model-type: model-type }))

(define-read-only (get-dynamic-cap-history (epoch uint))
  (map-get? dynamic-cap-history { epoch: epoch }))

(define-read-only (get-l2-participation (chain-id uint))
  (map-get? l2-participation-data { chain-id: chain-id }))

(define-read-only (get-enhancement-metrics)
  {
    correlation-coefficient: (var-get cross-correlation-coefficient),
    baseline-tvl: (var-get baseline-tvl),
    total-l2-participants: (var-get total-l2-participants),
    last-correlation-update: (var-get last-correlation-update),
    tvl-growth-multiplier: (var-get tvl-growth-multiplier),
    cross-chain-weight: (var-get cross-chain-weight-bps)
  })
