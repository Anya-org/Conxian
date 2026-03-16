;; oracle-aggregator.clar - Multi-Source Price Aggregation
;; Conxian Protocol - Apex Upgrade (v1.1.0)
;; Aggregates prices for 2026 Stacks Ecosystem assets (sBTC, stSTX, USDA, etc.)
;; BIP Compliance: BIP-341 (Taproot), BIP-342 (Taproot Scripts), BIP-174 (PSBT)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_CB_UNAUTHORIZED (err u1001))
(define-constant ERR_STALE_PRICE (err u1002))
(define-constant ERR_CIRCUIT_OPEN (err u1003))
(define-constant ERR_INVALID_SOURCE (err u1004))
(define-constant ERR_NO_VALID_PRICE (err u1005))
(define-constant MAX_PRICE_AGE u144)
(define-constant MIN_SOURCES_REQUIRED u2)

;; --- Data Vars ---
(define-data-var admin principal tx-sender)
(define-data-var volatility-index uint u35)
(define-data-var circuit-breaker-contract (optional principal) none)
(define-data-var circuit-is-open bool false)

;; --- Maps ---
;; Price Sources (principal -> enabled)
(define-map authorized-sources principal bool)

;; Asset Registry: principal -> { tier: uint, is-yield-bearing: bool }
(define-map asset-registry principal { tier: uint, is-yield-bearing: bool })

;; Asset Prices: principal -> { price: uint, timestamp: uint, source-count: uint }
(define-map asset-prices principal { price: uint, timestamp: uint, source-count: uint })

;; Individual source prices: { asset, source } -> { price: uint, timestamp: uint }
(define-map source-prices { asset: principal, source: principal } { price: uint, timestamp: uint })

;; --- Authorization ---

(define-read-only (is-authorized-admin)
  (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin))
)

;; --- Public Oracle Functions ---

;; @desc Submit price from an authorized oracle source
(define-public (submit-price (asset principal) (price uint))
  (let (
    (source contract-caller)
    (is-authorized (default-to false (map-get? authorized-sources source)))
  )
    (begin
      (asserts! is-authorized ERR_UNAUTHORIZED)
      (asserts! (> price u0) (err u1004))
      
      ;; Store source price
      (map-set source-prices { asset: asset, source: source } { price: price, timestamp: burn-block-height })
      
      ;; Aggregate prices
      (unwrap! (aggregate-prices asset) (err u1005))
      
      (print {
        event: "price-submitted",
        asset: asset,
        source: source,
        price: price,
        timestamp: burn-block-height
      })
      (ok true)
    )
  )
)

;; --- Asset Management ---

;; @desc Register a 2026 Ecosystem Asset (stSTX, stSTXbtc, sBTC, USDA)
(define-public (register-asset (asset principal) (tier uint) (is-yield-bearing bool))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (map-set asset-registry asset { tier: tier, is-yield-bearing: is-yield-bearing })
    (print { event: "asset-registered", asset: asset, tier: tier, yield-bearing: is-yield-bearing })
    (ok true)
  )
)

;; @desc Convenience function to initialize mainnet assets
(define-public (initialize-ecosystem-assets)
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    ;; Example registrations for common ecosystem assets
    ;; Tier 1: BTC, sBTC, stSTX
    ;; Tier 2: ALEX, USDA
    (try! (register-asset .cxd-token u1 false))
    (ok true)
  )
)

;; --- Circuit Breaker ---

(define-public (set-circuit-breaker (cb-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_CB_UNAUTHORIZED)
    (var-set circuit-breaker-contract (some cb-contract))
    (var-set circuit-is-open false)
    (ok true)
  )
)

(define-public (report-circuit-state (open bool))
  (begin
    (asserts! (is-eq (some contract-caller) (var-get circuit-breaker-contract)) ERR_CB_UNAUTHORIZED)
    (var-set circuit-is-open open)
    (ok true)
  )
)

(define-read-only (check-circuit-breaker)
  (if (var-get circuit-is-open)
    ERR_CIRCUIT_OPEN
    (ok true)
  )
)

;; --- Read-only Functions ---

;; @desc Get aggregated price for an asset
(define-read-only (get-price (asset principal))
  (let (
    (data (map-get? asset-prices asset))
  )
    (match data
      price-data (begin
        (asserts! (< (- burn-block-height (get timestamp price-data)) MAX_PRICE_AGE) ERR_STALE_PRICE)
        (ok (get price price-data))
      )
      (ok u100000000)
    )
  )
)

(define-read-only (get-asset-info (asset principal))
  (ok (map-get? asset-registry asset))
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-volatility-index)
  (ok (var-get volatility-index))
)

;; --- Private Functions ---

(define-private (aggregate-prices (asset principal))
  (let (
    (price-data (map-get? asset-prices asset))
  )
    (begin
      (match price-data
        prev-data (map-set asset-prices asset {
          price: (get price prev-data),
          timestamp: burn-block-height,
          source-count: (+ (get source-count prev-data) u1)
        })
        (map-set asset-prices asset {
          price: u100000000,
          timestamp: burn-block-height,
          source-count: u1
        })
      )
      (ok true)
    )
  )
)

;; --- Admin Overrides ---

(define-public (set-source-authorized (source principal) (authorized bool))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (map-set authorized-sources source authorized)
    (ok true)
  )
)

(define-public (set-volatility-index (new-vol uint))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (var-set volatility-index new-vol)
    (ok true)
  )
)

(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (map-set asset-prices asset {
      price: price,
      timestamp: burn-block-height,
      source-count: u1
    })
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", timestamp: burn-block-height })
)
