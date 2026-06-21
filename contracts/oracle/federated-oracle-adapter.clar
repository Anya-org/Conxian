;; federated-oracle-adapter.clar
;; Conxian Finance: Federated Oracle Adapter
;; Aggregates price data from multiple oracle sources
;; Standards: Clarity 4, Diataxis, SAB Core

;; Implement oracle trait
(impl-trait .defi-traits.oracle-trait)

;; --- Constants ---
(define-constant ERR_NOT_IMPLEMENTED u9999)
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_STALE_PRICE u6001)
(define-constant ERR_NOT_FOUND u6002)
(define-constant ERR_ALREADY_INITIALIZED u6003)
(define-constant MAX_PRICE_AGE u100) ;; 100 blocks

;; --- Data Vars ---
;; @desc The administrative principal authorized to manage oracle sources.
(define-data-var admin principal tx-sender)
;; @desc Flag indicating if the contract has been initialized.
(define-data-var initialized bool false)
;; @desc Minimum number of sources required for a valid aggregated price.
(define-data-var required-sources uint u3)
;; @desc Current count of active oracle sources.
(define-data-var active-sources-count uint u0)
;; @desc List of all registered oracle source principals.
(define-data-var oracle-source-list (list 20 principal) (list))

;; --- Maps ---
;; @desc Stores metadata for each authorized oracle source.
(define-map oracle-sources
  { source: principal }
  {
    active: bool,
    last-update: uint,
    weight: uint }
)

;; @desc Stores the final aggregated price data for each asset.
(define-map price-data
  { asset: principal }
  {
    aggregated-price: uint,
    last-update: uint,
    source-count: uint }
)

;; @desc Stores individual price observations from specific sources.
(define-map individual-prices
  { asset: principal, source: principal }
  {
    price: uint,
    timestamp: uint }
)

;; --- Read-Only Functions ---

;; @desc Returns the aggregated price for a given asset.
;; @param asset: The principal of the asset.
;; @returns (response uint uint)
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

;; @desc Returns the aggregated price for a given asset (trait compliance).
;; @param asset: The principal of the asset.
;; @returns (response uint uint)
(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

;; @desc Returns the name of the adapter.
;; @returns (response (string-ascii 32) uint)
(define-read-only (get-name)
  (ok "Federated-Oracle-Adapter")
)

;; --- Public Functions ---

;; @desc Initialize the contract with a DAO-governed admin.
;; @param new-admin: The admin principal.
;; @returns (response bool uint)
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (not (var-get initialized)) (err ERR_ALREADY_INITIALIZED))
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Submits a new price observation for an asset.
;; @param asset: The principal of the asset.
;; @param price: The observed price value.
;; @returns (response bool uint)
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

;; --- Admin Functions ---

;; @desc Adds a new authorized oracle source. Admin only.
;; @param source: The source principal.
;; @param weight: The weight assigned to this source.
;; @returns (response bool uint)
(define-public (add-oracle-source (source principal) (weight uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (let (
      (existing-source (map-get? oracle-sources { source: source }))
    )
      (begin
        (if (is-none existing-source)
          (begin
            (var-set oracle-source-list (unwrap! (as-max-len? (append (var-get oracle-source-list) source) u20) (err ERR_NOT_IMPLEMENTED)))
            (var-set active-sources-count (+ (var-get active-sources-count) u1))
          )
          (if (not (default-to true (get active existing-source)))
            (var-set active-sources-count (+ (var-get active-sources-count) u1))
            true
          )
        )
        (map-set oracle-sources { source: source } {
          active: true,
          last-update: burn-block-height,
          weight: weight })
        (ok true)
      )
    )
  )
)

;; @desc Removes or deactivates an authorized oracle source. Admin only.
;; @param source: The source principal.
;; @returns (response bool uint)
(define-public (remove-oracle-source (source principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (let (
      (existing-source (map-get? oracle-sources { source: source }))
    )
      (if (and (is-some existing-source) (get active (unwrap-panic existing-source)))
        (var-set active-sources-count (- (var-get active-sources-count) u1))
        true
      )
    )
    (map-set oracle-sources { source: source } {
      active: false,
      last-update: burn-block-height,
      weight: u0 })
    (ok true)
  )
)

;; @desc Sets the minimum number of sources required for aggregation. Admin only.
;; @param count: The required source count.
;; @returns (response bool uint)
(define-public (set-required-sources (count uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set required-sources count)
    (ok true)
  )
)

;; @desc Updates the administrator principal. Admin only.
;; @param new-admin: The new admin principal.
;; @returns (response bool uint)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- Private Functions ---

;; @desc Recalculates the aggregated price for an asset based on all active sources.
;; @param asset: The asset principal.
;; @returns (response bool uint)
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
        (ok false)
      )
      (ok false)
    )
  )
)

;; @desc Fold helper to calculate weighted price sum across sources.
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
          acc
        )
      )
      acc
    )
  )
)
