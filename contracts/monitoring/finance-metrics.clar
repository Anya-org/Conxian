;; finance-metrics.clar
;; Unified Financial Metrics for Conxian Protocol

(define-read-only (get-tvl)
  (let (
    (dim-tvl (default-to u0 (some (unwrap-panic (contract-call? .dimensional-core calculate-tvl)))))
    (lending-cxd (default-to u0 (some (get total-deposits (unwrap-panic (contract-call? .lending-manager get-reserve-data .cxd-token))))))
    (treasury-stx (* (stx-get-balance .operational-treasury) u100))
    (insurance-stx (* (stx-get-balance .conxian-insurance-fund) u100))
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
      health: "operational"
    })
  )
)
