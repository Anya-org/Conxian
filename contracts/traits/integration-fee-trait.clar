;; integration-fee-trait.clar
;; Collector-facing interface for STX integration fee accounting.
;; Raw API keys are intentionally outside this on-chain interface; the
;; registry stores only SHA-256 key commitments for lifecycle/audit purposes.

(define-trait integration-fee-trait
  (
    ;; Record reporter-authorized usage and accrue the configured fee.
    (record-usage (principal (buff 32) uint) (response uint uint))

    ;; Settle the exact outstanding amount for one integration/period.
    (settle-period (principal uint uint (buff 32)) (response bool uint))
    (settle-fees (principal uint uint (buff 32)) (response bool uint))

    ;; Read-only usage and period audit records.
    (get-usage-record ((buff 32)) (response (optional {
      integration: principal,
      reporter: principal,
      usage-units: uint,
      fee-amount: uint,
      period: uint,
      recorded-at: uint
    }) uint))
    (get-period-ledger (principal uint) (response (optional {
      billing-mode: uint,
      fee-per-unit: uint,
      monthly-fee: uint,
      usage-count: uint,
      usage-units: uint,
      accrued-fees: uint,
      settled-fees: uint,
      last-settlement-id: (optional (buff 32)),
      last-updated: uint
    }) uint))
    (get-current-period () (response uint uint))
  )
)
