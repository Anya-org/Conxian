;; economic-policy-engine.clar
;; Automated Monetary Fund with Gas-Free Internal Logic
;; Brain: Operations Engine | Input: On-chain data | Output: System parameters

(impl-trait .defi-traits.oracle-trait)
(impl-trait .core-traits.funding-rate-trait)

;; Constants
(define-constant BASE_RATE u100) ;; 1% base rate
(define-constant UTILIZATION_KINK u8000) ;; 80% threshold
(define-constant SLOPE_1 u400) ;; 4% slope 1
(define-constant SLOPE_2 u6000) ;; 60% slope 2
(define-constant MIN_COLLATERAL_FACTOR u5000) ;; 50% min
(define-constant MAX_COLLATERAL_FACTOR u9500) ;; 95% max
(define-constant PRICE_STALE_BLOCKS u300) ;; Target: 300 blocks (~50 hours at 10m/block)

(define-data-var subscription-cost uint u1000000) ;; 1 STX default
(define-constant ERR_NO_SUBSCRIPTION u1006)
(define-constant ERR_UNAUTHORIZED u1007)
(define-constant ERR_INVALID_PARAM u1008)

;; Data Vars
(define-data-var price-feed principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var utilization-rate uint u0)
(define-data-var current-interest-rate uint BASE_RATE)
(define-data-var collateral-factor uint MIN_COLLATERAL_FACTOR)
(define-data-var reserve-factor uint u1000) ;; 10% default
(define-data-var last-price-update-time uint u0)
(define-data-var revenue-distributor principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Subscription State
(define-map subscribers principal bool)

;; Storage
(define-map asset-prices
  principal
  {
    price: uint,
    timestamp: uint, ;; burn-block-height
    confidence: uint,
  }
)

(define-map market-parameters
  principal
  {
    utilization: uint,
    interest-rate: uint,
    collateral-factor: uint,
    last-update-burn: uint, ;; burn-block-height
  }
)

;; Gas-Free Internal Logic (Private Functions)
(define-private (calculate-utilization-rate)
  (var-get utilization-rate)
)

(define-private (calculate-interest-rate (utilization uint))
  (if (<= utilization UTILIZATION_KINK)
    (+ BASE_RATE (/ (* utilization SLOPE_1) UTILIZATION_KINK))
    (+ (+ BASE_RATE SLOPE_1) (/ (* (- utilization UTILIZATION_KINK) SLOPE_2) (- u10000 UTILIZATION_KINK)))
  )
)

(define-private (calculate-collateral-factor (volatility uint))
  (let ((base-factor MIN_COLLATERAL_FACTOR))
    (if (> volatility u5000)
      (+ base-factor u1000)
      base-factor
    )
  )
)

(define-private (is-price-stale (timestamp uint))
  (>= (- burn-block-height timestamp) PRICE_STALE_BLOCKS)
)

;; Public Functions

;; @desc Update market parameters for a specific asset.
;; @param asset principal - The principal of the asset to update.
;; @param new-utilization uint - The current utilization rate in basis points (0-10000).
;; @param price-volatility uint - The asset's price volatility in basis points.
;; @returns (response bool uint)
(define-public (update-market-parameters
    (asset principal)
    (new-utilization uint)
    (price-volatility uint)
  )
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    (let (
        (new-rate (calculate-interest-rate new-utilization))
        (new-factor (calculate-collateral-factor price-volatility))
      )
      (map-set market-parameters asset {
        utilization: new-utilization,
        interest-rate: new-rate,
        collateral-factor: new-factor,
        last-update-burn: burn-block-height,
      })

      (if (is-eq asset (var-get price-feed))
        (begin
          (var-set utilization-rate new-utilization)
          (var-set current-interest-rate new-rate)
          (var-set collateral-factor new-factor)
        )
        true
      )
      (ok true)
    )
  )
)

;; @desc Update the price feed for an asset.
;; @param asset principal - The principal of the asset.
;; @param price uint - The new price value.
;; @param confidence uint - The confidence interval or volatility indicator.
;; @returns (response bool uint)
(define-public (update-price-feed
    (asset principal)
    (price uint)
    (confidence uint)
  )
  (begin
    (map-set asset-prices asset {
      price: price,
      timestamp: burn-block-height,
      confidence: confidence,
    })
    (var-set last-price-update-time burn-block-height)
    (ok true)
  )
)

;; Read Functions

;; @desc Get the current protocol interest rate.
;; @returns (response uint uint)
(define-read-only (get-current-interest-rate)
  (ok (var-get current-interest-rate))
)

;; @desc Get the funding rate for a specific period.
;; @param period uint - The time period for funding calculation (in blocks).
;; @returns (response uint uint)
(define-read-only (get-funding-rate (period uint))
  (ok (* (var-get current-interest-rate) period))
)

;; @desc Get the current global collateral factor.
;; @returns (response uint uint)
(define-read-only (get-current-collateral-factor)
  (ok (var-get collateral-factor))
)

;; @desc Get market parameters for a specific asset.
;; @param asset principal - The principal of the asset.
;; @returns (optional {utilization: uint, interest-rate: uint, collateral-factor: uint, last-update-burn: uint})
(define-read-only (get-market-parameters (asset principal))
  (map-get? market-parameters asset)
)

;; @desc Get the last recorded price for an asset.
;; @param asset principal - The principal of the asset.
;; @returns (response uint uint)
(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices asset)
    price-data (ok (get price price-data))
    (err u1001)
  )
)

;; @desc Facade for get-price to match oracle-trait.
;; @param asset principal - The principal of the asset.
;; @returns (response uint uint)
(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

;; @desc Returns the name of the contract.
;; @returns (response (string-ascii 32) uint)
(define-read-only (get-name)
  (ok "Economic-Policy-Engine")
)

;; Configuration

;; @desc Set the cost of protocol subscriptions.
;; @param new-cost uint - The new subscription cost in micro-STX.
;; @returns (response bool uint)
(define-public (set-subscription-cost (new-cost uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    (var-set subscription-cost new-cost)
    (ok true)
  )
)

;; @desc Get the revenue distributor principal.
;; @returns (response principal uint)
(define-read-only (get-revenue-distributor)
  (ok (var-get revenue-distributor))
)
    
;; @desc Set the reserve factor for the protocol.
;; @param new-factor uint - The new reserve factor in basis points (0-10000).
;; @returns (response bool uint)
(define-public (set-reserve-factor (new-factor uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-factor u10000) (err ERR_INVALID_PARAM))
    (var-set reserve-factor new-factor)
    (ok true)
  )
)

;; @desc Get the current reserve factor.
;; @returns (response uint uint)
(define-read-only (get-reserve-factor)
  (ok (var-get reserve-factor))
)

;; Subscription Management

;; @desc Activate a subscription for access to advanced monetary functions.
;; @returns (response bool uint)
(define-public (subscribe)
  (let ((cost (var-get subscription-cost)))
    (begin
      (try! (stx-transfer? cost tx-sender (var-get revenue-distributor)))
      (try! (contract-call? .revenue-distributor distribute-stx cost))
      (map-set subscribers tx-sender true)
      (print { event: "subscription-activated", subscriber: tx-sender, cost: cost })
      (ok true)
    )
  )
)

;; @desc Check if a user is a subscriber.
;; @param user principal - The principal of the user.
;; @returns bool
(define-read-only (is-subscribed (user principal))
  (default-to false (map-get? subscribers user))
)

;; Automated Monetary Fund Operations

;; @desc Automatically adjust market parameters based on recent price data.
;; @param asset principal - The principal of the asset.
;; @returns (response bool uint)
(define-public (auto-adjust-parameters (asset principal))
  (begin
    (asserts! (is-subscribed tx-sender) (err ERR_NO_SUBSCRIPTION))
    (match (map-get? asset-prices asset)
      price-data
      (if (is-price-stale (get timestamp price-data))
        (err u1002)
        (let (
            (current-params (unwrap! (map-get? market-parameters asset) (err u1003)))
            (volatility (if (> (get confidence price-data) u5000) (- (get confidence price-data) u5000) u0))
          )
          (update-market-parameters asset (get utilization current-params) volatility)
        )
      )
      (err u1004)
    )
  )
)

;; System Health Monitoring

;; @desc Get the overall health and status of the economic engine.
;; @returns (response {last-update-time: uint, seconds-since-update: uint, current-rate: uint, utilization: uint, collateral-factor: uint, burn-height: uint} uint)
(define-read-only (get-system-health)
  (ok {
    last-update-time: (var-get last-price-update-time),
    seconds-since-update: (- burn-block-height (var-get last-price-update-time)),
    current-rate: (var-get current-interest-rate),
    utilization: (var-get utilization-rate),
    collateral-factor: (var-get collateral-factor),
    burn-height: burn-block-height
  })
)
