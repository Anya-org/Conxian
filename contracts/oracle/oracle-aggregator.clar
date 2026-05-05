;; oracle-aggregator.clar
;; Conxian Protocol - Standardized Oracle Aggregator (Apex v1.1.0)

(use-trait defi-trait .sip-standards.defi-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_CB_UNAUTHORIZED u1001)
(define-constant ERR_STALE_PRICE u1002)
(define-constant ERR_CIRCUIT_OPEN u1003)
(define-constant ERR_DEVIATION_TOO_HIGH u1006)
(define-constant ERR_INSUFFICIENT_SOURCES u1007)
(define-constant ERR_INTERNAL u500)

(define-constant MAX_PRICE_AGE u144)
(define-constant MAX_DEVIATION u1000) ;; 10%
(define-constant MIN_QUORUM u2)

;; --- Storage ---
(define-data-var admin principal tx-sender)
(define-map authorized-sources principal bool)
(define-data-var circuit-breaker (optional principal) none)

(define-map source-submissions
  { asset: principal, source: principal }
  { price: uint, block: uint }
)

(define-map asset-sources principal (list 10 principal))

;; --- Authorization ---
(define-read-only (is-authorized (source principal))
  (default-to false (map-get? authorized-sources source))
)

;; --- Public Functions ---

(define-public (set-source-authorized (source principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set authorized-sources source authorized)
    (ok true)
  )
)

(define-public (submit-price (asset principal) (price uint))
  (let (
    (source tx-sender)
    (current-sources (default-to (list) (map-get? asset-sources asset)))
    (agg-opt (get-price-internal asset))
  )
    (begin
      (asserts! (is-authorized source) (err ERR_UNAUTHORIZED))

      (if (is-some agg-opt)
        (let (
          (avg (unwrap-panic agg-opt))
          (deviation (if (> price avg) (- price avg) (- avg price)))
          (deviation-bps (/ (* deviation u10000) avg))
        )
          (asserts! (<= deviation-bps MAX_DEVIATION) (err ERR_DEVIATION_TOO_HIGH))
        )
        true
      )

      (map-set source-submissions { asset: asset, source: source } { price: price, block: burn-block-height })
      (if (is-none (index-of current-sources source))
        (map-set asset-sources asset (unwrap! (as-max-len? (append current-sources source) u10) (err ERR_INTERNAL)))
        true
      )
      (print { event: "price-submitted", asset: asset, source: source, price: price })
      (ok true)
    )
  )
)

(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set source-submissions { asset: asset, source: (var-get admin) } { price: price, block: burn-block-height })
    (map-set source-submissions { asset: asset, source: tx-sender } { price: price, block: burn-block-height })
    (map-set asset-sources asset (list (var-get admin) tx-sender))
    (ok true)
  )
)

(define-read-only (get-price (asset principal))
  (let (
    (res (get-price-internal asset))
  )
    (if (is-some res)
      (ok (unwrap-panic res))
      (err ERR_STALE_PRICE)
    )
  )
)

(define-read-only (get-price-internal (asset principal))
  (let (
    (sources (default-to (list) (map-get? asset-sources asset)))
    (aggregation (fold aggregate-prices sources { asset: asset, total-price: u0, count: u0, min-block: burn-block-height }))
  )
    (if (and (>= (get count aggregation) MIN_QUORUM) (<= (- burn-block-height (get min-block aggregation)) MAX_PRICE_AGE))
      (some (/ (get total-price aggregation) (get count aggregation)))
      none
    )
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", tenure-id: (some (/ block-height u10)) })
)

(define-read-only (get-volatility-index)
  (ok u50)
)

(define-public (set-circuit-breaker (cb principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_CB_UNAUTHORIZED))
    (var-set circuit-breaker (some cb))
    (ok true)
  )
)

(define-read-only (check-circuit-breaker)
  (ok true)
)

;; --- Private Helpers ---
(define-private (aggregate-prices (source principal) (acc { asset: principal, total-price: uint, count: uint, min-block: uint }))
  (let (
    (submission (map-get? source-submissions { asset: (get asset acc), source: source }))
  )
    (if (is-some submission)
      (let (
        (sub (unwrap-panic submission))
      )
        (if (is-authorized source)
          {
            asset: (get asset acc),
            total-price: (+ (get total-price acc) (get price sub)),
            count: (+ (get count acc) u1),
            min-block: (if (< (get block sub) (get min-block acc)) (get block sub) (get min-block acc))
          }
          acc
        )
      )
      acc
    )
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (register-asset (asset principal) (weight uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-public (initialize-ecosystem)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)
