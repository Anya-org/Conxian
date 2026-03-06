;; finance-metrics.clar
;; Unified Financial Metrics for Conxian Protocol
;; Normalizes TVL across diverse assets and decimals
;; Nakamoto-Aligned (Clarity 4)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; Scaling Factors
(define-constant STX_SCALING u100) ;; u6 -> u8 (x100)

(define-read-only (get-tvl)
  (let (
    ;; 1. Dimensional Engine TVL
    (dim-tvl (unwrap-panic (contract-call? .dimensional-core calculate-tvl)))

    ;; 2. Lending Manager Deposits (Normalize to u8)
    (lending-res (contract-call? .lending-manager get-reserve-data .cxd-token))
    (lending-cxd (match lending-res data (get total-deposits data) u0))

    ;; 3. Stacks Balances (Normalize u6 to u8)
    (treasury-stx (* (stx-get-balance .operational-treasury) STX_SCALING))
    (insurance-stx (* (stx-get-balance .conxian-insurance-fund) STX_SCALING))

    ;; 4. Token Balances (Native u8)
    (treasury-cxd (unwrap-panic (contract-call? .cxd-token get-balance .operational-treasury)))
    (insurance-cxd (unwrap-panic (contract-call? .cxd-token get-balance .conxian-insurance-fund)))
  )
    (ok (+ (+ (+ (+ dim-tvl lending-cxd) treasury-stx) insurance-stx) (+ treasury-cxd insurance-cxd)))
  )
)

(define-read-only (get-protocol-metrics)
  (let (
    (tvl (unwrap-panic (get-tvl)))
    (supply (unwrap-panic (contract-call? .cxd-token get-total-supply)))
  )
    (ok {
      tvl: tvl,
      supply: supply,
      health: (if (> tvl u0) "HEALTHY" "INIT")
    })
  )
)
