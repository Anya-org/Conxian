;; finance-metrics.clar
;; Unified Financial Metrics for Conxian Protocol
;; Aligned with CXIP-013 and Nakamoto Standards

(define-read-only (get-tvl)
  (let (
    ;; Dimensional Core TVL
    (dim-tvl (match (contract-call? .dimensional-core calculate-tvl) ok-val ok-val err-val u0))

    ;; Lending Manager TVL (CXD deposits)
    (lending-res (contract-call? .lending-manager get-reserve-data .cxd-token))
    (lending-cxd (match lending-res res (get total-deposits res) u0))

    ;; Treasury Balances (STX)
    (treasury-stx (stx-get-balance .operational-treasury))
    (insurance-stx (stx-get-balance .conxian-insurance-fund))

    ;; Treasury Balances (CXD)
    (treasury-cxd (match (contract-call? .cxd-token get-balance .operational-treasury) ok-val ok-val err-val u0))
    (insurance-cxd (match (contract-call? .cxd-token get-balance .conxian-insurance-fund) ok-val ok-val err-val u0))
  )
    (ok (+ (+ (+ (+ dim-tvl lending-cxd) treasury-stx) insurance-stx) (+ treasury-cxd insurance-cxd)))
  )
)

(define-read-only (get-protocol-metrics)
  (let (
    (tvl-res (get-tvl))
    (supply-res (contract-call? .cxd-token get-total-supply))
  )
    (ok {
      total-value-locked: (match tvl-res val val u0),
      cxd-total-supply: (match supply-res val val u0),
      timestamp: burn-block-height
    })
  )
)
