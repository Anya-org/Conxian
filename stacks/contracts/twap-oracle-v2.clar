;; =============================================================================
;; ADVANCED TWAP ORACLE - PHASE 2 IMPLEMENTATION
;; =============================================================================

(use-trait ft-trait .traits.sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_INVALID_PERIOD (err u701))
(define-constant ERR_INSUFFICIENT_HISTORY (err u702))
(define-constant ERR_INVALID_PRICE (err u703))
(define-constant ERR_STALE_PRICE (err u704))
(define-constant ERR_MANIPULATION_DETECTED (err u705))
(define-constant ERR_INVALID_PAIR (err u706))

;; Constants
(define-constant MAX_PRICE_HISTORY u256) ;; Maximum price observations
(define-constant MIN_OBSERVATION_INTERVAL u6) ;; Minimum 6 blocks between observations
(define-constant MAX_PRICE_DEVIATION u2000) ;; 20% max price deviation
(define-constant MANIPULATION_THRESHOLD u1000) ;; 10% threshold for manipulation detection
(define-constant PRICE_PRECISION u100000000) ;; 8 decimal precision

;; Price observation structure
(define-map price-observations
  {pair: {token-a: principal, token-b: principal}, index: uint}
  {
    timestamp: uint,
    block-height: uint,
    price: uint,
    liquidity: uint,
    volume: uint,
    cumulative-price: uint
  })

;; Pair configuration
(define-map pair-config
  {token-a: principal, token-b: principal}
  {
    active: bool,
    observation-cardinality: uint,
    observation-index: uint,
    last-observation-block: uint,
    base-token: principal,
    manipulation-checks: bool,
    min-liquidity: uint
  })

;; TWAP cache for efficiency
(define-map twap-cache
  {pair: {token-a: principal, token-b: principal}, period: uint}
  {
    twap-price: uint,
    calculated-at: uint,
    valid-until: uint,
    observations-used: uint
  })

;; Circuit breaker for manipulation detection
(define-map manipulation-alerts
  {token-a: principal, token-b: principal}
  {
    detected-at: uint,
    severity: uint,
    price-deviation: uint,
    volume-spike: uint,
    recovery-block: uint
  })

;; State variables
(define-data-var oracle-admin principal tx-sender)
(define-data-var global-observation-fee uint u0)
(define-data-var max-price-age uint u144) ;; ~24 hours at 10 min blocks
(define-data-var manipulation-detection-enabled bool true)

;; =============================================================================
;; CORE ORACLE FUNCTIONS
;; =============================================================================

;; Get TWAP price with manipulation resistance
(define-public (get-twap-price
  (token-a principal)
  (token-b principal)
  (period uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    
    ;; Validate inputs
    (asserts! (> period u0) ERR_INVALID_PERIOD)
    (asserts! (is-some (map-get? pair-config pair)) ERR_INVALID_PAIR)
    
    ;; Check for cached TWAP
    (match (map-get? twap-cache {pair: pair, period: period})
      cached-twap
        (if (<= block-height (get valid-until cached-twap))
          (ok (get twap-price cached-twap))
          (calculate-and-cache-twap pair period))
      ;; No cache, calculate fresh
      (calculate-and-cache-twap pair period))))

;; Record new price observation
(define-public (observe-price
  (token-a principal)
  (token-b principal)
  (price uint)
  (liquidity uint)
  (volume uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    
    ;; Validate observation
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (is-some (map-get? pair-config pair)) ERR_INVALID_PAIR)
    
    (let ((config (unwrap! (map-get? pair-config pair) ERR_INVALID_PAIR)))
      
      ;; Check observation frequency
      (asserts! (>= (- block-height (get last-observation-block config)) MIN_OBSERVATION_INTERVAL)
                ERR_INSUFFICIENT_HISTORY)
      
      ;; Manipulation detection
      (if (var-get manipulation-detection-enabled)
        (try! (check-manipulation pair price liquidity volume))
        (ok true))
      
      ;; Record observation
      (let ((new-index (mod (+ (get observation-index config) u1) (get observation-cardinality config)))
            (cumulative-price (calculate-cumulative-price pair price)))
        
        ;; Store observation
        (map-set price-observations {pair: pair, index: new-index} {
          timestamp: (unwrap-panic (get-stacks-block-info? time block-height)),
          block-height: block-height,
          price: price,
          liquidity: liquidity,
          volume: volume,
          cumulative-price: cumulative-price
        })
        
        ;; Update pair config
        (map-set pair-config pair (merge config {
          observation-index: new-index,
          last-observation-block: block-height
        }))
        
        ;; Invalidate TWAP cache for this pair
        (invalidate-twap-cache pair)
        
        ;; Emit observation event
        (print {
          event: "price-observed",
          pair: pair,
          price: price,
          liquidity: liquidity,
          volume: volume,
          block-height: block-height,
          index: new-index
        })
        
        (ok true)))))

;; =============================================================================
;; TWAP CALCULATION ENGINE
;; =============================================================================

;; Calculate and cache TWAP
(define-private (calculate-and-cache-twap
  (pair {token-a: principal, token-b: principal})
  (period uint))
  (let ((config (unwrap! (map-get? pair-config pair) ERR_INVALID_PAIR))
        (target-block (- block-height period)))
    
    ;; Get observations for TWAP calculation
    (let ((observations (get-observations-for-period pair target-block block-height)))
      (if (>= (len observations) u2)
        (let ((twap-price (calculate-time-weighted-price observations))
              (cache-duration (/ period u4))) ;; Cache for 1/4 of the period
          
          ;; Cache the result
          (map-set twap-cache {pair: pair, period: period} {
            twap-price: twap-price,
            calculated-at: block-height,
            valid-until: (+ block-height cache-duration),
            observations-used: (len observations)
          })
          
          (print {
            event: "twap-calculated",
            pair: pair,
            period: period,
            twap-price: twap-price,
            observations-used: (len observations)
          })
          
          (ok twap-price))
        (err ERR_INSUFFICIENT_HISTORY)))))

;; Calculate time-weighted average price
(define-private (calculate-time-weighted-price
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint})))
  (if (< (len observations) u2)
    u0
    (let ((total-time (- (get timestamp (unwrap-panic (element-at observations (- (len observations) u1))))
                        (get timestamp (unwrap-panic (element-at observations u0))))))
      (if (is-eq total-time u0)
        (get price (unwrap-panic (element-at observations u0)))
        (calculate-weighted-sum observations total-time u0 u0)))))

;; Calculate weighted sum recursively
(define-private (calculate-weighted-sum
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint}))
  (total-time uint)
  (index uint)
  (accumulated-sum uint))
  (if (>= index (- (len observations) u1))
    (/ accumulated-sum total-time)
    (let ((current-obs (unwrap-panic (element-at observations index)))
          (next-obs (unwrap-panic (element-at observations (+ index u1)))))
      (let ((time-delta (- (get timestamp next-obs) (get timestamp current-obs)))
            (weighted-price (* (get price current-obs) time-delta)))
        (calculate-weighted-sum 
          observations 
          total-time 
          (+ index u1)
          (+ accumulated-sum weighted-price))))))

;; =============================================================================
;; MANIPULATION DETECTION
;; =============================================================================

;; Check for price manipulation
(define-private (check-manipulation
  (pair {token-a: principal, token-b: principal})
  (new-price uint)
  (new-liquidity uint)
  (new-volume uint))
  (let ((recent-obs (get-recent-observations pair u10))) ;; Last 10 observations
    (if (>= (len recent-obs) u3)
      (let ((price-deviation (calculate-price-deviation recent-obs new-price))
            (volume-spike (calculate-volume-spike recent-obs new-volume)))
        
        ;; Check for manipulation indicators
        (if (or (> price-deviation MANIPULATION_THRESHOLD)
                (> volume-spike (* u5 MANIPULATION_THRESHOLD))) ;; 5x volume spike
          (begin
            ;; Record manipulation alert
            (map-set manipulation-alerts pair {
              detected-at: block-height,
              severity: (if (> price-deviation (* u2 MANIPULATION_THRESHOLD)) u2 u1),
              price-deviation: price-deviation,
              volume-spike: volume-spike,
              recovery-block: (+ block-height u72) ;; ~12 hour recovery
            })
            
            (print {
              event: "manipulation-detected",
              pair: pair,
              price-deviation: price-deviation,
              volume-spike: volume-spike,
              severity: (if (> price-deviation (* u2 MANIPULATION_THRESHOLD)) u2 u1)
            })
            
            (err ERR_MANIPULATION_DETECTED))
          (ok true)))
      (ok true)))) ;; Not enough history to detect manipulation

;; Calculate price deviation from recent average
(define-private (calculate-price-deviation
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint}))
  (new-price uint))
  (if (is-eq (len observations) u0)
    u0
    (let ((avg-price (calculate-simple-average observations u0 u0)))
      (if (is-eq avg-price u0)
        u0
        (let ((deviation (if (> new-price avg-price)
                           (- new-price avg-price)
                           (- avg-price new-price))))
          (/ (* deviation u10000) avg-price)))))) ;; Return as basis points

;; Calculate volume spike ratio
(define-private (calculate-volume-spike
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint}))
  (new-volume uint))
  (if (is-eq (len observations) u0)
    u0
    (let ((avg-volume (calculate-volume-average observations u0 u0)))
      (if (is-eq avg-volume u0)
        u0
        (/ (* new-volume u10000) avg-volume))))) ;; Return as ratio * 10000

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

;; Get observations for a specific period
(define-private (get-observations-for-period
  (pair {token-a: principal, token-b: principal})
  (start-block uint)
  (end-block uint))
  ;; Simplified implementation - would traverse observation ring buffer
  (list))

;; Get recent observations
(define-private (get-recent-observations
  (pair {token-a: principal, token-b: principal})
  (count uint))
  ;; Simplified implementation
  (list))

;; Calculate simple average price
(define-private (calculate-simple-average
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint}))
  (index uint)
  (sum uint))
  (if (>= index (len observations))
    (if (> (len observations) u0) (/ sum (len observations)) u0)
    (let ((obs (unwrap-panic (element-at observations index))))
      (calculate-simple-average observations (+ index u1) (+ sum (get price obs))))))

;; Calculate volume average
(define-private (calculate-volume-average
  (observations (list 256 {timestamp: uint, price: uint, liquidity: uint}))
  (index uint)
  (sum uint))
  (if (>= index (len observations))
    (if (> (len observations) u0) (/ sum (len observations)) u0)
    (let ((obs (unwrap-panic (element-at observations index))))
      (calculate-volume-average observations (+ index u1) (+ sum (get liquidity obs))))))

;; Calculate cumulative price
(define-private (calculate-cumulative-price
  (pair {token-a: principal, token-b: principal})
  (current-price uint))
  ;; Simplified - would maintain cumulative price sum
  current-price)

;; Invalidate TWAP cache for all periods
(define-private (invalidate-twap-cache
  (pair {token-a: principal, token-b: principal}))
  ;; Simplified - would invalidate all cached TWAP values for this pair
  true)

;; =============================================================================
;; PAIR MANAGEMENT
;; =============================================================================

;; Initialize trading pair for oracle
(define-public (initialize-pair
  (token-a principal)
  (token-b principal)
  (base-token principal)
  (observation-cardinality uint)
  (min-liquidity uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq token-a token-b)) ERR_INVALID_PAIR)
    (asserts! (> observation-cardinality u0) ERR_INVALID_PERIOD)
    
    (map-set pair-config pair {
      active: true,
      observation-cardinality: observation-cardinality,
      observation-index: u0,
      last-observation-block: u0,
      base-token: base-token,
      manipulation-checks: true,
      min-liquidity: min-liquidity
    })
    
    (print {
      event: "pair-initialized",
      pair: pair,
      observation-cardinality: observation-cardinality,
      min-liquidity: min-liquidity
    })
    
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-pair-config (token-a principal) (token-b principal))
  (map-get? pair-config {token-a: token-a, token-b: token-b}))

(define-read-only (get-latest-price (token-a principal) (token-b principal))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (match (map-get? pair-config pair)
      config (map-get? price-observations {pair: pair, index: (get observation-index config)})
      none)))

(define-read-only (get-manipulation-status (token-a principal) (token-b principal))
  (map-get? manipulation-alerts {token-a: token-a, token-b: token-b}))

(define-read-only (is-price-stale (token-a principal) (token-b principal))
  (match (get-latest-price token-a token-b)
    latest-obs (> (- block-height (get block-height latest-obs)) (var-get max-price-age))
    true))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-manipulation-detection (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set manipulation-detection-enabled enabled)
    (ok true)))

(define-public (set-max-price-age (new-age uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set max-price-age new-age)
    (ok true)))

(define-public (clear-manipulation-alert (token-a principal) (token-b principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (map-delete manipulation-alerts {token-a: token-a, token-b: token-b})
    (print {event: "manipulation-alert-cleared", token-a: token-a, token-b: token-b})
    (ok true)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set oracle-admin new-admin)
    (ok true)))
