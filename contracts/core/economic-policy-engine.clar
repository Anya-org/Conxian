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
(define-constant PRICE_STALE_SECONDS u300) ;; 5 minutes in seconds

(define-constant SUBSCRIPTION_COST u1000000) ;; 1 STX
(define-constant ERR_NO_SUBSCRIPTION u1006)
(define-constant ERR_UNAUTHORIZED u1007)

;; Data Vars
(define-data-var price-feed principal tx-sender)
(define-data-var utilization-rate uint u0)
(define-data-var current-interest-rate uint BASE_RATE)
(define-data-var collateral-factor uint MIN_COLLATERAL_FACTOR)
(define-data-var last-price-update-time uint u0)
(define-data-var revenue-distributor principal .revenue-distributor)

;; Subscription State
(define-map subscribers principal bool)

;; Storage
(define-map asset-prices
  principal
  {
    price: uint,
    timestamp: uint, ;; Block timestamp
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
  (>= (- (default-to u0 (get-block-info? time block-height)) timestamp) PRICE_STALE_SECONDS)
)

;; Public Functions

;; @desc Update market parameters for a specific asset.
(define-public (update-market-parameters
    (asset principal)
    (new-utilization uint)
    (price-volatility uint)
  )
  (begin
    (asserts! (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
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
(define-public (update-price-feed
    (asset principal)
    (price uint)
    (confidence uint)
  )
  (begin
    (map-set asset-prices asset {
      price: price,
      timestamp: (default-to u0 (get-block-info? time block-height)),
      confidence: confidence,
    })
    (var-set last-price-update-time (default-to u0 (get-block-info? time block-height)))
    (ok true)
  )
)

;; Read Functions

;; @desc Get the current protocol interest rate.
(define-read-only (get-current-interest-rate)
  (ok (var-get current-interest-rate))
)

;; @desc Get the funding rate for a specific period.
(define-read-only (get-funding-rate (period uint))
  (ok (* (var-get current-interest-rate) period))
)

;; @desc Get the current global collateral factor.
(define-read-only (get-current-collateral-factor)
  (ok (var-get collateral-factor))
)

;; @desc Get market parameters for a specific asset.
(define-read-only (get-market-parameters (asset principal))
  (map-get? market-parameters asset)
)

;; @desc Get the last recorded price for an asset.
(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices asset)
    price-data (ok (get price price-data))
    (err u1001)
  )
)

;; @desc Facade for get-price to match oracle-trait.
(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

;; @desc Returns the name of the contract.
(define-read-only (get-name)
  (ok "Economic-Policy-Engine")
)

;; Subscription Management

;; @desc Activate a subscription for access to advanced monetary functions.
(define-public (subscribe)
  (begin
    (try! (stx-transfer? SUBSCRIPTION_COST tx-sender (var-get revenue-distributor)))
    (try! (contract-call? .revenue-distributor distribute-stx SUBSCRIPTION_COST))
    (map-set subscribers tx-sender true)
    (print { event: "subscription-activated", subscriber: tx-sender })
    (ok true)
  )
)

;; @desc Check if a user is a subscriber.
(define-read-only (is-subscribed (user principal))
  (default-to false (map-get? subscribers user))
)

;; Automated Monetary Fund Operations
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
(define-read-only (get-system-health)
  (ok {
    last-update-time: (var-get last-price-update-time),
    seconds-since-update: (- (default-to u0 (get-block-info? time block-height)) (var-get last-price-update-time)),
    current-rate: (var-get current-interest-rate),
    utilization: (var-get utilization-rate),
    collateral-factor: (var-get collateral-factor),
    burn-height: burn-block-height
  })
)
