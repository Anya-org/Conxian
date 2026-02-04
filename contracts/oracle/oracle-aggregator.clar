;; Oracle Aggregator - Weighted sources with TWAP and manipulation detection (minimal implementation)

(use-trait oracle-trait .defi-traits.oracle-trait)
(impl-trait .defi-traits.oracle-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ASSET_NOT_FOUND u1001)
(define-constant ERR_CIRCUIT_OPEN u1002)
(define-constant ERR_INVALID_PRICE u1003)
(define-constant BPS u10000)
(define-constant MIN_PRICE u100)  ;; $0.0000000000000001 (1e-16)
(define-constant MAX_PRICE (* u1000000000000000000 u1000000))  ;; $1M with 18 decimals

;; Admin
(define-data-var admin principal tx-sender)
(define-data-var manipulation-threshold-bps uint u500) ;; 5% default
(define-data-var twap-alpha-bps uint u1000) ;; 10% EMA weight for new observations
(define-data-var circuit-breaker (optional principal) none)
;; Degrade to TWAP when price age exceeds threshold (in blocks)
(define-data-var stale-threshold-blocks uint u4320000)

;; Per-asset store: latest price, TWAP (EMA), source weight, and timestamp
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

(define-private (get-burn-block-height)
  burn-block-height
)

(define-private (is-stale (updated-at uint))
  (let ((current-height (get-burn-block-height)))
    (>= (- current-height updated-at) (var-get stale-threshold-blocks)))
)

(define-private (abs (n int))
  (if (< n 0) (- 0 n) n)
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-circuit-breaker (cb principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set circuit-breaker (some cb))
    (ok true)
  )
)

(define-public (set-params (new-threshold-bps uint) (new-alpha-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set manipulation-threshold-bps new-threshold-bps)
    (var-set twap-alpha-bps new-alpha-bps)
    (ok true)
  )
)

(define-public (set-stale-threshold (blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set stale-threshold-blocks blocks)
    (ok true)
  )
)

;; Update price and twap (EMA)
(define-private (update-volatility (asset principal) (price uint))
  (let ((data (default-to { mean: u0, variance: u0, count: u0 } (map-get? asset-volatility-data { asset: asset })))
        (new-count (+ (get count data) u1)))
    (if (is-eq new-count u1)
      (map-set asset-volatility-data { asset: asset } { mean: price, variance: u0, count: new-count })
      (let ((old-mean (get mean data))
            (new-mean (/ (+ (* old-mean (get count data)) price) new-count))
            (old-variance (get variance data))
            (new-variance (/ (+ (* old-variance (get count data)) (to-uint (* (- (to-int price) (to-int old-mean)) (- (to-int price) (to-int new-mean))))) new-count)))
        (map-set asset-volatility-data { asset: asset } { mean: new-mean, variance: new-variance, count: new-count })
      )
    )
    (ok true)
  )
)
(define-public (set-source (asset principal) (price uint) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (try! (check-circuit-breaker))
    (asserts! (and (>= price MIN_PRICE) (<= price MAX_PRICE)) (err ERR_INVALID_PRICE))
    (let ((alpha (var-get twap-alpha-bps))
          (current-timestamp (get-burn-block-height)))
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
        ;; Initialize TWAP on first set
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
      (let ((v-update (update-volatility asset price)))
        (ok true)
      )
      )
    )
  )
)

;; Basic manipulation detection: deviation of latest price vs TWAP exceeds threshold
(define-read-only (is-manipulated (asset principal))
  (let (
        (deviation-check
          (match (map-get? asset-sources { asset: asset })
            entry
              (let (
                    (p (get price entry))
                    (t (get twap entry))
                    (thr (var-get manipulation-threshold-bps))
                   )
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
       )
    deviation-check
  )
)

;; Minimal aggregator: return latest price when not manipulated; otherwise return TWAP (degraded mode)

(define-read-only (get-volatility (asset principal))
  (ok (default-to { mean: u0, variance: u0, count: u0 } (map-get? asset-volatility-data { asset: asset })))
)
(define-read-only (get-volatility-index)
  (match (map-get? asset-volatility-data { asset: .cxd-token })
    data (ok (get variance data))
    (ok u0)
  )
)

(define-read-only (get-price (asset principal))
  (match (map-get? asset-sources { asset: asset })
    entry
      (let ((cb (check-circuit-breaker)))
        (match cb
          okv
            (let ((age (- (get-burn-block-height) (get updated-at entry)))
                  (stale (>= age (var-get stale-threshold-blocks))))
              (if (or stale (is-manipulated asset))
                (ok (get twap entry))
                (ok (get price entry))
              )
            )
          errv
            ;; When circuit is open, degrade to TWAP if available
            (ok (get twap entry))
        )
      )
    (err ERR_ASSET_NOT_FOUND)
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

;; Get TWAP explicitly
(define-read-only (get-twap (asset principal))
  (match (map-get? asset-twap-data { asset: asset })
    twap-data
      (let ((time-diff (- (get-burn-block-height) (get last-timestamp twap-data)))
            (last-price (get price (unwrap-panic (map-get? asset-sources { asset: asset })))))
        (if (is-eq time-diff u0)
          (ok last-price)
          (ok (/ (+ (get price-cumulative twap-data) (* last-price time-diff)) time-diff))
        )
      )
    (err ERR_ASSET_NOT_FOUND)
  )
)

;; Circuit breaker check: returns ok true if closed, err if open
(define-read-only (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb
      (if (contract-call? .circuit-breaker is-contract-paused cb)
        (err ERR_CIRCUIT_OPEN)
        (ok true)
      )
    (ok true)
  )
)
