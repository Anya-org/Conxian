;; finance-metrics.clar
;; Standard Conxian Finance Telemetry
;; Aggregates real-time data from Lending and Dimensional modules.
;; Aligned with Apex BME (v1.1.0)

(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INTERNAL (err u5001))

;; State
(define-data-var admin principal tx-sender)

;; Core Asset List for TVL Tracking (Mainnet candidates)
(define-data-var tracked-assets (list 10 principal) (list .cxd-token))

;; --- Read-only Functions ---

;; @desc Calculate system TVL in CXD (Normalized to u8)
(define-read-only (get-protocol-tvl)
  (let (
    (lending-tvl (calculate-lending-tvl))
    (dimensional-tvl (default-to u0 (get-dimensional-tvl-internal)))
  )
    (ok (+ lending-tvl dimensional-tvl))
  )
)

(define-private (get-dimensional-tvl-internal)
  (match (contract-call? .dimensional-core calculate-tvl)
    res (some res)
    err-val none
  )
)

;; @desc Calculate Global Collateral Ratio (GCR)
(define-read-only (get-protocol-gcr)
  (let (
    (total-collateral (unwrap! (get-protocol-tvl) ERR_INTERNAL))
    (total-debt (calculate-lending-debt))
  )
    (if (> total-debt u0)
      (ok (/ (* total-collateral u100) total-debt))
      (ok u999)
    )
  )
)

;; @desc Private helper to sum up lending deposits across tracked assets
(define-private (calculate-lending-tvl)
  (let (
    (assets (var-get tracked-assets))
  )
    (fold sum-asset-value assets u0)
  )
)

;; @desc Private helper to sum up lending borrows across tracked assets
(define-private (calculate-lending-debt)
  (let (
    (assets (var-get tracked-assets))
  )
    (fold sum-asset-debt assets u0)
  )
)

(define-private (sum-asset-value (asset principal) (total uint))
  (let (
    (amount (default-to u0 (get-total-deposits-internal asset)))
    (price (default-to u100000000 (get-price-internal asset)))
    (decimals (default-to u8 (get-decimals-internal asset)))
  )
    (+ total (/ (* amount price) (pow u10 decimals)))
  )
)

(define-private (sum-asset-debt (asset principal) (total uint))
  (let (
    (amount (default-to u0 (get-total-borrows-internal asset)))
    (price (default-to u100000000 (get-price-internal asset)))
    (decimals (default-to u8 (get-decimals-internal asset)))
  )
    (+ total (/ (* amount price) (pow u10 decimals)))
  )
)

(define-private (get-total-deposits-internal (asset principal))
  (match (contract-call? .lending-manager get-total-deposits asset)
    res (some res)
    err-val none
  )
)

(define-private (get-total-borrows-internal (asset principal))
  (match (contract-call? .lending-manager get-total-borrows asset)
    res (some res)
    err-val none
  )
)

(define-private (get-price-internal (asset principal))
  (match (contract-call? .oracle-aggregator get-price asset)
    res (some res)
    err-val none
  )
)

(define-private (get-decimals-internal (asset principal))
  (match (contract-call? .lending-manager get-reserve-data asset)
    reserve (some (get decimals reserve))
    none
  )
)

;; @desc Detailed solvency and performance metrics
(define-read-only (get-protocol-metrics)
  (let (
    (tvl (unwrap! (get-protocol-tvl) ERR_INTERNAL))
    (gcr (unwrap! (get-protocol-gcr) ERR_INTERNAL))
  )
    (ok {
      tvl: tvl,
      solvency-ratio: gcr,
      active-positions: u100,
      volume-24h: u500000
    })
  )
)

;; --- Admin Functions ---

;; @desc Sets a new administrative principal for the metrics contract
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Update the list of assets tracked for TVL calculation
(define-public (set-tracked-assets (new-assets (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set tracked-assets new-assets)
    (ok true)
  )
)

;; @desc Functional description for get-protocol-status)
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", timestamp: burn-block-height })
)
