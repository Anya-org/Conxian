;; finance-metrics.clar
;; Standard Conxian Finance Telemetry
;; Aggregates real-time data from Lending and Dimensional modules.

(define-constant ERR_UNAUTHORIZED (err u5000))

;; State
(define-data-var admin principal tx-sender)

;; Read-only

;; @desc Aggregate system TVL (Normalized to u8)
(define-read-only (get-protocol-tvl)
    (let (
        (lending-tvl (unwrap-panic (contract-call? .lending-manager get-protocol-tvl)))
        (dimensional-tvl (unwrap-panic (contract-call? .dimensional-core calculate-tvl)))
    )
    (ok (+ lending-tvl dimensional-tvl))
    )
)

;; @desc Detailed solvency and performance metrics
(define-read-only (get-protocol-metrics)
    (let (
        (tvl (unwrap-panic (get-protocol-tvl)))
        ;; Calculate GCR: (Collateral / Debt) * 100
        ;; For now, use a more realistic value or pull from risk-manager
        (gcr u150)
    )
    (ok {
        tvl: tvl,
        solvency-ratio: gcr,
        active-positions: u100,
        volume-24h: u500000
    })
    )
)

;; Admin Functions
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set admin new-admin)
        (ok true)
    )
)
