;; economic-policy-engine.clar
;; Automated Monetary Fund with Gas-Free Internal Logic
;; Brain: Operations Engine | Input: On-chain data | Output: System parameters
;; Native Stacks Architecture - Fully Deterministic

(impl-trait .defi-traits.oracle-trait)
(impl-trait .core-traits.interest-rate-trait)

;; Constants - Gas Free (compile-time)
(define-constant BASE_RATE u1000) ;; 0.1% base rate (scaled 10000)
(define-constant UTILIZATION_THRESHOLD u8000) ;; 80% threshold
(define-constant RATE_MULTIPLIER u15000) ;; 1.5x multiplier
(define-constant MIN_COLLATERAL_FACTOR u5000) ;; 50% min
(define-constant MAX_COLLATERAL_FACTOR u9500) ;; 95% max
(define-constant PRICE_STALE_BLOCKS u100) ;; 5 minutes @ 3s blocks

(define-constant SUBSCRIPTION_COST u1000000) ;; 1 STX
(define-constant ERR_NO_SUBSCRIPTION (err u1006))

;; Data Vars - Single Source of Truth
(define-data-var price-feed principal tx-sender)
(define-data-var utilization-rate uint u0)
(define-data-var current-interest-rate uint BASE_RATE)
(define-data-var collateral-factor uint MIN_COLLATERAL_FACTOR)
(define-data-var last-price-update uint block-height)
(define-data-var treasury-address principal tx-sender)

;; Subscription State
(define-map subscribers principal bool)

;; Efficient Storage - Map for O(1) lookups
(define-map asset-prices
  principal
  {
    price: uint,
    timestamp: uint,
    confidence: uint,
  }
)

(define-map market-parameters
  principal
  {
    utilization: uint,
    interest-rate: uint,
    collateral-factor: uint,
    last-update: uint,
  }
)

;; Gas-Free Internal Logic (Private Functions)
(define-private (calculate-utilization-rate)
  ;; Calculate from total supply/borrow - O(1) operation
  (var-get utilization-rate)
)

(define-private (calculate-interest-rate (utilization uint))
  ;; Deterministic formula - no external calls
  (if (>= utilization UTILIZATION_THRESHOLD)
    (* BASE_RATE RATE_MULTIPLIER)
    BASE_RATE
  )
)

(define-private (calculate-collateral-factor (volatility uint))
  ;; Risk-based calculation - O(1) operation
  (let ((base-factor MIN_COLLATERAL_FACTOR))
    (if (> volatility u5000)
      (+ base-factor u1000) ;; Add 10% for high volatility
      base-factor
    )
  )
)

(define-private (is-price-stale (timestamp uint))
  (< (- block-height timestamp) PRICE_STALE_BLOCKS)
)

;; Public Functions - Minimized Gas Costs
(define-public (update-market-parameters
    (asset principal)
    (new-utilization uint)
    (price-volatility uint)
  )
  (begin
    ;; Single write operation - batch updates
    (let (
        (new-rate (calculate-interest-rate new-utilization))
        (new-factor (calculate-collateral-factor price-volatility))
      )
      ;; Atomic update - reduces write operations
      (map-set market-parameters asset {
        utilization: new-utilization,
        interest-rate: new-rate,
        collateral-factor: new-factor,
        last-update: block-height,
      })

      ;; Update global vars if primary asset
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

;; Oracle Integration - Gas Optimized
(define-public (update-price-feed
    (asset principal)
    (price uint)
    (confidence uint)
  )
  (begin
    ;; Single map operation
    (map-set asset-prices asset {
      price: price,
      timestamp: block-height,
      confidence: confidence,
    })

    ;; Update timestamp
    (var-set last-price-update block-height)

    (ok true)
  )
)

;; Read Functions - Gas Free (no state changes)
(define-read-only (get-current-interest-rate)
  (ok (var-get current-interest-rate))
)

(define-read-only (get-current-collateral-factor)
  (ok (var-get collateral-factor))
)

(define-read-only (get-market-parameters (asset principal))
  (map-get? market-parameters asset)
)

(define-read-only (get-price (asset principal))
  (match (map-get? asset-prices asset)
    price-data (ok (get price price-data))
    (err u1001)
  )
)

;; Subscription Management
(define-public (subscribe)
  (begin
    ;; Payment to treasury
    (try! (stx-transfer? SUBSCRIPTION_COST tx-sender (var-get treasury-address)))
    
    ;; Grant subscription
    (map-set subscribers tx-sender true)
    
    (print { event: "subscription-activated", subscriber: tx-sender })
    (ok true)
  )
)

(define-read-only (is-subscribed (user principal))
  (default-to false (map-get? subscribers user))
)

;; Automated Monetary Fund Operations
(define-public (auto-adjust-parameters (asset principal))
  (begin
    ;; Subscription Gate
    (asserts! (is-subscribed tx-sender) ERR_NO_SUBSCRIPTION)
    
    ;; Check if price is stale
    (match (map-get? asset-prices asset)
      price-data
      (begin
        (if (is-price-stale (get timestamp price-data))
          (err u1002) ;; Price stale
          (ok true)
        )

        ;; Calculate new parameters based on current market state
        (let (
            (current-params (unwrap! (map-get? market-parameters asset) (err u1003)))
            (volatility (- (get confidence price-data) u5000))
          )
          ;; Derive volatility from confidence

          (update-market-parameters asset (get utilization current-params)
            volatility
          )
        )
      )
      (err u1004) ;; Asset not found
    )
  )
)

(define-private (batch-update-helper (entry {a: principal, b: {a: uint, b: uint}}) (result (response uint uint)))
  (let (
      (asset (get a entry))
      (data (get b entry))
      (price (get a data))
      (confidence (get b data))
    )
    (begin
      (unwrap-panic (update-price-feed asset price confidence))
      result
    )
  )
)

(define-private (make-entry (asset principal) (price uint) (confidence uint))
  {a: asset, b: {a: price, b: confidence}}
)

;; Batch Operations - Gas Optimization
(define-public (batch-update-prices
    (assets (list 10 principal))
    (prices (list 10 uint))
    (confidences (list 10 uint))
  )
  (begin
    ;; Process all assets in single transaction
    (fold batch-update-helper (map make-entry assets prices confidences) (ok u0))
  )
)

;; System Health Monitoring
(define-read-only (get-system-health)
  (ok {
    last-update: (var-get last-price-update),
    blocks-since-update: (- block-height (var-get last-price-update)),
    current-rate: (var-get current-interest-rate),
    utilization: (var-get utilization-rate),
    collateral-factor: (var-get collateral-factor),
  })
)
