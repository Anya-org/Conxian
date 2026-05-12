;; federated-oracle-adapter.clar
;; Conxian Finance: Federated Oracle Adapter
;; Aggregates price data from multiple oracle sources

;; Implement oracle trait
(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_NOT_IMPLEMENTED u9999)
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_STALE_PRICE u6001)
(define-constant ERR_NOT_FOUND u6002)
(define-constant MAX_PRICE_AGE u100) ;; 100 blocks

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var required-sources uint u3) ;; Require 3 sources
(define-data-var active-sources-count uint u0)

;; Maps
(define-map oracle-sources
  { source: principal }
  {
    active: bool,
    last-update: uint,
    weight: uint }
)

(define-map price-data
  { asset: principal }
  {
    aggregated-price: uint,
    last-update: uint,
    source-count: uint }
)

(define-map individual-prices
  { asset: principal, source: principal }
  {
    price: uint,
    timestamp: uint }
)

;; Read-Only: Get Aggregated Price (trait compliance)

;; @desc Returns the aggregated price for a given asset
(define-read-only (get-price (asset principal))
  (match (map-get? price-data { asset: asset })
    data
      (if (> (- burn-block-height (get last-update data)) MAX_PRICE_AGE)
        (err ERR_STALE_PRICE)
        (ok (get aggregated-price data))
      )
    (err ERR_NOT_FOUND)
  )
)

;; Read-Only: Fetch Price (trait compliance identical to get-price in this context)

;; @desc Returns the aggregated price for a given asset (alias for get-price)
(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

;; @desc Submit a price observation for an asset
(define-public (submit-price (asset principal) (price uint))
  (let ((source tx-sender))
    (begin
      (asserts! (default-to false (get active (map-get? oracle-sources { source: source }))) (err ERR_UNAUTHORIZED))

      ;; Update individual price
      (map-set individual-prices { asset: asset, source: source } {
        price: price,
        timestamp: burn-block-height })

      ;; Recalculate aggregated price
      (recalculate-aggregated-price asset)
    )
  )
)

;; List of potential sources (for simulation-safe iteration)
(define-data-var oracle-source-list (list 20 principal) (list))

;; Private: Recalculate Aggregated Price
;; Uses a weighted average calculation across active sources
(define-private (recalculate-aggregated-price (asset principal))
  (let (
    (sources (var-get oracle-source-list))
    (calculation (fold calculate-weighted-sum sources { asset: asset, total-weighted-price: u0, total-weight: u0, valid-sources: u0 }))
  )
    (if (>= (get valid-sources calculation) (var-get required-sources))
      (if (> (get total-weight calculation) u0)
        (let (
          (new-aggregated-price (/ (get total-weighted-price calculation) (get total-weight calculation)))
        )
          (begin
            (map-set price-data { asset: asset } {
              aggregated-price: new-aggregated-price,
              last-update: burn-block-height,
              source-count: (get valid-sources calculation) })
            (ok true)
          )
        )
        (ok false) ;; Should not happen if valid-sources >= 1 and weights > 0
      )
      (ok false) ;; Not enough sources yet
    )
  )
)

;; Fold function for weighted sum calculation
(define-private (calculate-weighted-sum (source principal) (acc { asset: principal, total-weighted-price: uint, total-weight: uint, valid-sources: uint }))
  (let (
    (source-info (unwrap! (map-get? oracle-sources { source: source }) acc))
    (price-info (map-get? individual-prices { asset: (get asset acc), source: source }))
  )
    (if (and (get active source-info) (is-some price-info))
      (let (
        (price-data-actual (unwrap-panic price-info))
      )
        (if (<= (- burn-block-height (get timestamp price-data-actual)) MAX_PRICE_AGE)
          {
            asset: (get asset acc),
            total-weighted-price: (+ (get total-weighted-price acc) (* (get price price-data-actual) (get weight source-info))),
            total-weight: (+ (get total-weight acc) (get weight source-info)),
            valid-sources: (+ (get valid-sources acc) u1) }
          acc ;; Stale price
        )
      )
      acc ;; Inactive or no price
    )
  )
)

;; @desc Add a new authorized oracle source
(define-public (add-oracle-source (source principal) (weight uint))
  (begin
    (asserts! (is-eq contract-caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (if (is-none (map-get? oracle-sources { source: source }))
      (var-set oracle-source-list (unwrap! (as-max-len? (append (var-get oracle-source-list) source) u20) (err u500)))
      true
    )
    (map-set oracle-sources { source: source } {
      active: true,
      last-update: burn-block-height,
      weight: weight })
    (var-set active-sources-count (+ (var-get active-sources-count) u1))
    (ok true)
  )
)

;; @desc Remove an authorized oracle source
(define-public (remove-oracle-source (source principal))
  (begin
    (asserts! (is-eq contract-caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set oracle-sources { source: source } {
      active: false,
      last-update: burn-block-height,
      weight: u0 })
    (var-set active-sources-count (- (var-get active-sources-count) u1))
    (ok true)
  )
)

;; Admin: Set required sources
(define-public (set-required-sources (count uint))
  (begin
    (asserts! (is-eq contract-caller (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set required-sources count)
    (ok true)
  )
)

;; Read-only: Get Name
(define-read-only (get-name)
  (ok "Federated-Oracle-Adapter")
)
