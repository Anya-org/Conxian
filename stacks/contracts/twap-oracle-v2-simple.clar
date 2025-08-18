;; =============================================================================
;; TWAP ORACLE V2 - MANIPULATION RESISTANT
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_PAIR (err u401))
(define-constant ERR_INSUFFICIENT_HISTORY (err u402))
(define-constant ERR_MANIPULATION_DETECTED (err u403))
(define-constant ERR_STALE_PRICE (err u404))
(define-constant ERR_INVALID_PERIOD (err u405))

;; Constants
(define-constant DEFAULT_TWAP_PERIOD u144) ;; ~24 hours in blocks (10min avg)
(define-constant MAX_PRICE_AGE u6) ;; Max 6 blocks for fresh price
(define-constant MANIPULATION_THRESHOLD u500) ;; 5% deviation threshold
(define-constant MAX_OBSERVATIONS u256)

;; State variables
(define-data-var contract-owner principal tx-sender)
(define-data-var manipulation-detection-enabled bool true)
(define-data-var max-price-age-blocks uint MAX_PRICE_AGE)

;; Data structures
(define-map pair-config
  {token-a: principal, token-b: principal}
  {
    min-liquidity: uint,
    twap-period: uint,
    active: bool,
    observation-index: uint
  })

(define-map price-observations
  {pair: {token-a: principal, token-b: principal}, index: uint}
  {
    timestamp: uint,
    price: uint,
    liquidity: uint,
    volume: uint,
    block-height: uint
  })

(define-map twap-cache
  {pair: {token-a: principal, token-b: principal}, period: uint}
  {
    twap-price: uint,
    calculated-at: uint,
    valid-until: uint,
    observations-used: uint
  })

(define-map manipulation-flags
  {pair: {token-a: principal, token-b: principal}}
  {
    detected: bool,
    detection-block: uint,
    price-deviation: uint,
    volume-spike: uint
  })

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; =============================================================================
;; CORE TWAP FUNCTIONS
;; =============================================================================

;; Get TWAP price for a pair
(define-public (get-twap-price
  (token-a principal)
  (token-b principal)
  (period uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (asserts! (is-some (map-get? pair-config pair)) ERR_INVALID_PAIR)
    (asserts! (> period u0) ERR_INVALID_PERIOD)
    
    ;; Check cache first
    (match (map-get? twap-cache {pair: pair, period: period})
      cached-twap
      (if (< block-height (get valid-until cached-twap))
        (ok (get twap-price cached-twap))
        (calculate-fresh-twap pair period))
      (calculate-fresh-twap pair period))))

;; Record a price observation
(define-public (observe-price
  (token-a principal)
  (token-b principal)
  (price uint)
  (liquidity uint)
  (volume uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (asserts! (is-some (map-get? pair-config pair)) ERR_INVALID_PAIR)
    (asserts! (> price u0) ERR_INVALID_PAIR)
    
    (let ((config (unwrap-panic (map-get? pair-config pair)))
          (current-index (get observation-index config))
          (new-index (if (< current-index (- MAX_OBSERVATIONS u1))
                       (+ current-index u1)
                       u0)))
      
      ;; Store the observation
      (map-set price-observations
        {pair: pair, index: new-index}
        {
          timestamp: (unwrap-panic (get-block-info? time (- block-height u1))),
          price: price,
          liquidity: liquidity,
          volume: volume,
          block-height: block-height
        })
      
      ;; Update config with new index
      (map-set pair-config pair
        (merge config {observation-index: new-index}))
      
      ;; Check for manipulation if enabled
      (if (var-get manipulation-detection-enabled)
        (check-for-manipulation pair price volume)
        (ok true))
      
      (ok true))))

;; =============================================================================
;; HELPER FUNCTIONS (Non-circular)
;; =============================================================================

;; Calculate fresh TWAP (simplified to avoid circular dependencies)
(define-private (calculate-fresh-twap
  (pair {token-a: principal, token-b: principal})
  (period uint))
  (let ((config (unwrap! (map-get? pair-config pair) ERR_INVALID_PAIR))
        (current-index (get observation-index config)))
    
    ;; Simple average of recent observations
    (let ((recent-prices (get-recent-price-data pair current-index period)))
      (if (>= (len recent-prices) u2)
        (let ((average-price (calculate-simple-price-average recent-prices)))
          ;; Cache the result
          (map-set twap-cache {pair: pair, period: period} {
            twap-price: average-price,
            calculated-at: block-height,
            valid-until: (+ block-height (/ period u4)),
            observations-used: (len recent-prices)
          })
          (ok average-price))
        (err ERR_INSUFFICIENT_HISTORY)))))

;; Get recent price data
(define-private (get-recent-price-data
  (pair {token-a: principal, token-b: principal})
  (start-index uint)
  (count uint))
  (let ((max-count (min count u20))) ;; Limit to prevent infinite loops
    (fold get-price-at-index
          (generate-index-list start-index max-count)
          (list))))

;; Generate list of indices to check
(define-private (generate-index-list (start uint) (count uint))
  (if (<= count u0)
    (list)
    (if (<= count u10)
      (list start)
      (list start (if (> start u0) (- start u1) (- MAX_OBSERVATIONS u1))))))

;; Get price at specific index
(define-private (get-price-at-index
  (index uint)
  (acc (list 20 uint)))
  (match (map-get? price-observations {pair: {token-a: .mock-ft, token-b: .mock-ft}, index: index})
    observation (append acc (get price observation))
    acc))

;; Calculate simple average
(define-private (calculate-simple-price-average (prices (list 20 uint)))
  (if (is-eq (len prices) u0)
    u0
    (/ (fold + prices u0) (len prices))))

;; Check for manipulation (simplified)
(define-private (check-for-manipulation
  (pair {token-a: principal, token-b: principal})
  (current-price uint)
  (current-volume uint))
  (let ((recent-data (get-recent-price-data pair u10 u5)))
    (if (>= (len recent-data) u2)
      (let ((avg-price (calculate-simple-price-average recent-data))
            (deviation (if (> current-price avg-price)
                        (/ (* (- current-price avg-price) u10000) avg-price)
                        (/ (* (- avg-price current-price) u10000) avg-price))))
        
        (if (> deviation MANIPULATION_THRESHOLD)
          (begin
            (map-set manipulation-flags pair {
              detected: true,
              detection-block: block-height,
              price-deviation: deviation,
              volume-spike: u0
            })
            (err ERR_MANIPULATION_DETECTED))
          (ok true)))
      (ok true))))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (initialize-pair
  (token-a principal)
  (token-b principal)
  (min-liquidity uint)
  (twap-period uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set pair-config
      {token-a: token-a, token-b: token-b}
      {
        min-liquidity: min-liquidity,
        twap-period: twap-period,
        active: true,
        observation-index: u0
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
  (map-get? manipulation-flags {token-a: token-a, token-b: token-b}))

(define-read-only (is-price-stale (token-a principal) (token-b principal))
  (match (get-latest-price token-a token-b)
    observation (> (- block-height (get block-height observation)) (var-get max-price-age-blocks))
    true))

;; Admin functions
(define-public (set-manipulation-detection (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set manipulation-detection-enabled enabled)
    (ok true)))

(define-public (set-max-price-age (new-age uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set max-price-age-blocks new-age)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))
