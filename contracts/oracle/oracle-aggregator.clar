;; oracle-aggregator.clar
;; Oracle Aggregator - Weighted sources with TWAP and manipulation detection
;; Aligned with Clarity 3 / Nakamoto adherence

(use-trait oracle-trait .defi-traits.oracle-trait)
(impl-trait .defi-traits.oracle-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ASSET_NOT_FOUND u1001)
(define-constant ERR_CIRCUIT_OPEN u1002)
(define-constant ERR_INVALID_PRICE u1003)
(define-constant BPS u10000)
(define-constant MIN_PRICE u100)
(define-constant MAX_PRICE (* u1000000000000000000 u1000000))

;; State - BOLT: No dynamic top-level init
(define-data-var admin principal tx-sender)
(define-data-var manipulation-threshold-bps uint u500)
(define-data-var twap-alpha-bps uint u1000)
(define-data-var circuit-breaker-active bool false)
(define-data-var primary-asset principal tx-sender)
(define-data-var stale-threshold-blocks uint u4320000)

;; Per-asset store
(define-map asset-sources { asset: principal } {
  price: uint,
  twap: uint,
  weight: uint,
  total-weight: uint,
  updated-at: uint
})

(define-map asset-twap-data { asset: principal } {
  price-cumulative: uint,
  last-timestamp: uint
})

(define-map asset-volatility-data { asset: principal } {
  mean: uint,
  variance: uint,
  count: uint
})

;; Helper: Get block height from utils
(define-private (get-current-height)
  (contract-call? .block-utils get-burn-block-height)
)

(define-private (abs (n int))
  (if (< n 0) (- 0 n) n)
)

;; Circuit breaker check
(define-read-only (check-circuit-breaker)
  (if (var-get circuit-breaker-active)
      (err ERR_CIRCUIT_OPEN)
      (ok true)
  )
)

;; Authorization
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-breaker (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set circuit-breaker-active status)
    (ok true)
  )
)

;; Update volatility
(define-private (update-volatility (asset principal) (price uint))
  (let ((data (default-to { mean: u0, variance: u0, count: u0 } (map-get? asset-volatility-data { asset: asset })))
        (new-count (+ (get count data) u1)))
    (if (is-eq new-count u1)
      (begin
        (map-set asset-volatility-data { asset: asset } { mean: price, variance: u0, count: new-count })
        (ok true)
      )
      (let ((old-mean (get mean data))
            (new-mean (/ (+ (* old-mean (get count data)) price) new-count))
            (old-variance (get variance data))
            (diff1 (- (to-int price) (to-int old-mean)))
            (diff2 (- (to-int price) (to-int new-mean)))
            (new-variance-int (/ (+ (* (to-int old-variance) (to-int (get count data))) (* diff1 diff2)) (to-int new-count))))
        (begin
          (map-set asset-volatility-data { asset: asset } {
            mean: new-mean,
            variance: (to-uint (if (< new-variance-int (to-int u0)) (to-int u0) new-variance-int)),
            count: new-count
          })
          (ok true)
        )
      )
    )
  )
)

(define-public (set-source (asset principal) (price uint) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (try! (check-circuit-breaker))
    (asserts! (and (>= price MIN_PRICE) (<= price MAX_PRICE)) (err ERR_INVALID_PRICE))
    (let ((alpha (var-get twap-alpha-bps))
          (current-timestamp (get-current-height)))
      (begin
      (match (map-get? asset-sources { asset: asset })
        entry
          (let ((prev-twap (get twap entry))
                (prev-price (get price entry))
                (prev-total (get total-weight entry))
                (new-total-weight (+ prev-total weight))
                (agg-price (if (> new-total-weight u0)
                               (/ (+ (* prev-price prev-total) (* price weight)) new-total-weight)
                               price)))
            (map-set asset-sources { asset: asset } {
              price: agg-price,
              twap: (/ (+ (* alpha price) (* (- BPS alpha) prev-twap)) BPS),
              weight: weight,
              total-weight: new-total-weight,
              updated-at: current-timestamp
            })
          )
        (map-set asset-sources { asset: asset } {
          price: price,
          twap: price,
          weight: weight,
          total-weight: weight,
          updated-at: current-timestamp
        })
      )

      (match (map-get? asset-twap-data { asset: asset })
        twap-data
          (let ((time-diff (- current-timestamp (get last-timestamp twap-data)))
                (last-price (get price (unwrap-panic (map-get? asset-sources { asset: asset })))))
            (map-set asset-twap-data { asset: asset } {
              price-cumulative: (+ (get price-cumulative twap-data) (* last-price time-diff)),
              last-timestamp: current-timestamp
            })
          )
        (map-set asset-twap-data { asset: asset } {
          price-cumulative: u0,
          last-timestamp: current-timestamp
        })
      )

      (unwrap! (update-volatility asset price) (err u500))
      (ok true)
      )
    )
  )
)

(define-read-only (is-manipulated (asset principal))
  (match (map-get? asset-sources { asset: asset })
    entry
      (let ((p (get price entry))
            (t (get twap entry))
            (thr (var-get manipulation-threshold-bps)))
        (if (or (is-eq t u0) (is-eq p u0))
            false
            (let ((delta (if (>= p t) (- p t) (- t p))))
              (> (/ (* delta BPS) t) thr)
            )
        )
      )
    false
  )
)

(define-read-only (get-volatility-index)
  (let ((data (default-to { mean: u0, variance: u0, count: u0 } (map-get? asset-volatility-data { asset: (var-get primary-asset) }))))
    (if (is-eq (get mean data) u0)
      (ok u0)
      (ok (/ (* (get variance data) u100) (get mean data)))
    )
  )
)

(define-read-only (get-price (asset principal))
  (match (map-get? asset-sources { asset: asset })
    entry
      (let ((age (- (get-current-height) (get updated-at entry)))
            (stale (>= age (var-get stale-threshold-blocks))))
        (if (or stale (is-manipulated asset))
          (ok (get twap entry))
          (ok (get price entry))
        )
      )
    (err ERR_ASSET_NOT_FOUND)
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-twap (asset principal))
  (match (map-get? asset-twap-data { asset: asset })
    twap-data
      (let ((time-diff (- (get-current-height) (get last-timestamp twap-data)))
            (last-price (get price (unwrap-panic (map-get? asset-sources { asset: asset })))))
        (if (is-eq time-diff u0)
          (ok last-price)
          (ok (/ (+ (get price-cumulative twap-data) (* last-price time-diff)) time-diff))
        )
      )
    (err ERR_ASSET_NOT_FOUND)
  )
)
