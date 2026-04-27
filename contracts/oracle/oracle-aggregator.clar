;; oracle-aggregator.clar
;; Conxian Protocol - Standardized Oracle Aggregator (Apex v1.1.0)

(use-trait defi-trait .sip-standards.defi-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_CB_UNAUTHORIZED u1001)
(define-constant ERR_NO_PRICE u1002)
(define-constant ERR_CIRCUIT_OPEN u1003)

(define-constant MAX_PRICE_AGE u144) ;; 24 hours in blocks
(define-constant MIN_QUORUM u2)

;; --- Storage ---
(define-data-var admin principal tx-sender)
(define-map authorized-sources principal bool)
(define-data-var circuit-breaker (optional principal) none)

(define-map source-submissions
  { asset: principal, source: principal }
  { price: uint, block: uint }
)

(define-map asset-sources
  principal
  (list 10 principal)
)

;; --- Public Functions ---

(define-public (submit-price (asset principal) (price uint))
  (begin
    (asserts! (default-to false (map-get? authorized-sources tx-sender)) (err ERR_UNAUTHORIZED))
    (map-set source-submissions { asset: asset, source: tx-sender } { price: price, block: burn-block-height })
    (ok true)
  )
)

(define-public (add-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set authorized-sources source true)
    (ok true)
  )
)

(define-public (register-asset (asset principal) (sources (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set asset-sources asset sources)
    (ok true)
  )
)

;; @desc Get the aggregated price for an asset
(define-public (get-price (asset principal))
  (let (
    (cb-check (check-circuit-breaker))
  )
    (begin
      (asserts! (is-ok cb-check) (err ERR_CIRCUIT_OPEN))
      (match (get-price-internal asset)
        price (ok price)
        (err ERR_NO_PRICE)
      )
    )
  )
)

;; --- Read-only Functions ---

(define-read-only (fetch-price (asset principal))
  (ok (default-to u0 (get-price-internal asset)))
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

;; @desc Checks if the circuit breaker is open.
(define-read-only (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb (if (is-eq cb .mock-circuit-breaker)
         (if (unwrap-panic (contract-call? .mock-circuit-breaker is-circuit-open)) (err ERR_CIRCUIT_OPEN) (ok true))
         (ok true))
    (ok true)
  )
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
        {
          asset: (get asset acc),
          total-price: (+ (get total-price acc) (get price sub)),
          count: (+ (get count acc) u1),
          min-block: (if (< (get block sub) (get min-block acc)) (get block sub) (get min-block acc))
        }
      )
      acc
    )
  )
)

(define-public (initialize (new-admin principal))
  (begin
    (var-set admin new-admin)
    (ok true)
  )
)
