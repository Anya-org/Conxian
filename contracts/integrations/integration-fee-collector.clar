;; integration-fee-collector.clar
;; STX-first integration usage accounting and exact settlement.
;; Trusted reporter principals are the MVP authorization boundary. Raw API
;; keys are authenticated off-chain and never enter this contract.

(impl-trait .integration-fee-trait.integration-fee-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u2000))
(define-constant ERR_REGISTRY_FAILURE (err u2001))
(define-constant ERR_INTEGRATION_NOT_FOUND (err u2002))
(define-constant ERR_INTEGRATION_INACTIVE (err u2003))
(define-constant ERR_INVALID_BILLING_MODE (err u2004))
(define-constant ERR_INVALID_USAGE (err u2005))
(define-constant ERR_USAGE_REPLAYED (err u2006))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u2007))
(define-constant ERR_LEDGER_NOT_FOUND (err u2008))
(define-constant ERR_PERIOD_NOT_CLOSED (err u2009))
(define-constant ERR_INVALID_PERIOD (err u2010))
(define-constant ERR_NOTHING_TO_SETTLE (err u2011))
(define-constant ERR_SETTLEMENT_AMOUNT (err u2012))
(define-constant ERR_SETTLEMENT_REPLAYED (err u2013))
(define-constant ERR_LEDGER_INVARIANT (err u2014))

(define-constant BILLING_MODE_PER_USE u1)
(define-constant BILLING_MODE_MONTHLY u2)
(define-constant MONTHLY_PERIOD_BURN_BLOCKS u4320)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; --- Accounting state ---
(define-map usage-records (buff 32) {
  integration: principal,
  reporter: principal,
  usage-units: uint,
  fee-amount: uint,
  period: uint,
  recorded-at: uint
})

(define-map period-ledgers { integration: principal, period: uint } {
  ;; These fields are immutable billing snapshots for this period. Registry
  ;; changes apply only when a future period ledger is first created.
  billing-mode: uint,
  fee-per-unit: uint,
  monthly-fee: uint,
  usage-count: uint,
  usage-units: uint,
  accrued-fees: uint,
  settled-fees: uint,
  last-settlement-id: (optional (buff 32)),
  last-updated: uint
})

(define-map settlement-records (buff 32) {
  integration: principal,
  period: uint,
  payer: principal,
  amount: uint,
  settled-at: uint
})

;; --- Safe arithmetic ---

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right)))
)

(define-private (safe-multiply (left uint) (right uint))
  (if (or (is-eq left u0) (is-eq right u0))
    (some u0)
    (if (> left (/ MAX_UINT right))
      none
      (some (* left right))))
)

(define-private (current-period)
  (/ burn-block-height MONTHLY_PERIOD_BURN_BLOCKS)
)

(define-private (load-integration (integration principal))
  (let ((config-opt (unwrap! (contract-call? .integration-registry get-integration integration) ERR_REGISTRY_FAILURE)))
    (ok (unwrap! config-opt ERR_INTEGRATION_NOT_FOUND)))
)

(define-private (empty-ledger
    (billing-mode uint)
    (fee-per-unit uint)
    (monthly-fee uint))
  {
    billing-mode: billing-mode,
    fee-per-unit: fee-per-unit,
    monthly-fee: monthly-fee,
    usage-count: u0,
    usage-units: u0,
    accrued-fees: u0,
    settled-fees: u0,
    last-settlement-id: none,
    last-updated: burn-block-height
  }
)

;; --- Usage recording ---

;; @desc Record one reporter-authorized usage event and accrue its STX fee.
;; Per-use integrations charge fee-amount * usage-units. Monthly integrations
;; charge their fixed fee once per period while still tracking every usage.
(define-public (record-usage (integration principal) (usage-id (buff 32)) (usage-units uint))
  (let ((config (try! (load-integration integration))))
    (begin
      ;; Active status is required for new usage. Settlement deliberately uses
      ;; the existing ledger and payer even if the integration is later off.
      (asserts! (get active config) ERR_INTEGRATION_INACTIVE)
      (asserts!
        (or
          (is-eq contract-caller (get reporter config))
          (is-eq tx-sender (get reporter config)))
        ERR_UNAUTHORIZED)
      (asserts! (> usage-units u0) ERR_INVALID_USAGE)
      (asserts! (or
        (is-eq (get billing-mode config) BILLING_MODE_PER_USE)
        (is-eq (get billing-mode config) BILLING_MODE_MONTHLY)) ERR_INVALID_BILLING_MODE)
      (asserts! (is-none (map-get? usage-records usage-id)) ERR_USAGE_REPLAYED)
      (let (
        (period (current-period))
        (ledger-key { integration: integration, period: period })
        ;; The first usage in a period snapshots both fee representations. The
        ;; ledger's billing mode selects which snapshot is subsequently used.
        (ledger (default-to
          (empty-ledger
            (get billing-mode config)
            (get fee-amount config)
            (get fee-amount config))
          (map-get? period-ledgers ledger-key)))
        (charge (if
          (is-eq (get billing-mode ledger) BILLING_MODE_PER_USE)
          (unwrap! (safe-multiply (get fee-per-unit ledger) usage-units) ERR_ARITHMETIC_OVERFLOW)
          (get monthly-fee ledger)))
        (period-charge (if
          (is-eq (get billing-mode ledger) BILLING_MODE_MONTHLY)
          (if (is-eq (get accrued-fees ledger) u0) charge u0)
          charge))
        (new-usage-count (unwrap! (safe-add (get usage-count ledger) u1) ERR_ARITHMETIC_OVERFLOW))
        (new-usage-units (unwrap! (safe-add (get usage-units ledger) usage-units) ERR_ARITHMETIC_OVERFLOW))
        (new-accrued-fees (unwrap! (safe-add (get accrued-fees ledger) period-charge) ERR_ARITHMETIC_OVERFLOW))
      )
        (begin
          ;; All validation and arithmetic complete before state is written.
          (map-set usage-records usage-id {
            integration: integration,
            reporter: contract-caller,
            usage-units: usage-units,
            fee-amount: period-charge,
            period: period,
            recorded-at: burn-block-height
          })
          (map-set period-ledgers ledger-key {
            billing-mode: (get billing-mode ledger),
            fee-per-unit: (get fee-per-unit ledger),
            monthly-fee: (get monthly-fee ledger),
            usage-count: new-usage-count,
            usage-units: new-usage-units,
            accrued-fees: new-accrued-fees,
            settled-fees: (get settled-fees ledger),
            last-settlement-id: (get last-settlement-id ledger),
            last-updated: burn-block-height
          })
          (print {
            event: "integration-usage-recorded",
            integration: integration,
            usage-id: usage-id,
            reporter: contract-caller,
            usage-units: usage-units,
            fee-amount: period-charge,
            period: period
          })
          (ok period-charge)
        )
      )
    )
  )
)

;; --- Settlement ---

(define-private (settle-period-internal
    (integration principal)
    (period uint)
    (amount uint)
    (settlement-id (buff 32)))
  (let (
    (config (try! (load-integration integration)))
    (current-period-value (current-period))
    (ledger (unwrap! (map-get? period-ledgers { integration: integration, period: period }) ERR_LEDGER_NOT_FOUND))
    (outstanding (if
      (>= (get accrued-fees ledger) (get settled-fees ledger))
      (- (get accrued-fees ledger) (get settled-fees ledger))
      u0))
  )
    (begin
      (asserts! (is-eq tx-sender (get payer config)) ERR_UNAUTHORIZED)
      ;; Settlement is authorized by the current payer for an existing
      ;; immutable ledger; deactivation must not strand already-accrued debt.
      (asserts! (or
        (is-eq (get billing-mode ledger) BILLING_MODE_PER_USE)
        (is-eq (get billing-mode ledger) BILLING_MODE_MONTHLY)) ERR_INVALID_BILLING_MODE)
      (asserts! (<= period current-period-value) ERR_INVALID_PERIOD)
      (asserts!
        (or
          (is-eq (get billing-mode ledger) BILLING_MODE_PER_USE)
          (< period current-period-value))
        ERR_PERIOD_NOT_CLOSED)
      (asserts! (is-none (map-get? settlement-records settlement-id)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (> outstanding u0) ERR_NOTHING_TO_SETTLE)
      (asserts! (is-eq amount outstanding) ERR_SETTLEMENT_AMOUNT)
      (asserts! (<= (get settled-fees ledger) (get accrued-fees ledger)) ERR_LEDGER_INVARIANT)

      ;; Transfer payer -> collector, then collector -> the existing revenue
      ;; distributor path. Any route failure reverts the whole transaction.
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (try! (as-contract (contract-call? .revenue-distributor distribute-stx amount)))

      (map-set settlement-records settlement-id {
        integration: integration,
        period: period,
        payer: tx-sender,
        amount: amount,
        settled-at: burn-block-height
      })
      (map-set period-ledgers { integration: integration, period: period } (merge ledger {
        settled-fees: (get accrued-fees ledger),
        last-settlement-id: (some settlement-id),
        last-updated: burn-block-height
      }))
      (print {
        event: "integration-fee-settled",
        integration: integration,
        period: period,
        settlement-id: settlement-id,
        payer: tx-sender,
        amount: amount
      })
      (ok true)
    )
  )
)

;; @desc Settle the exact outstanding fee for a period.
(define-public (settle-period
    (integration principal)
    (period uint)
    (amount uint)
    (settlement-id (buff 32)))
  (settle-period-internal integration period amount settlement-id)
)

;; Explicit alias for callers that use fee-oriented terminology.
(define-public (settle-fees
    (integration principal)
    (period uint)
    (amount uint)
    (settlement-id (buff 32)))
  (settle-period-internal integration period amount settlement-id)
)

;; --- Read-only audit API ---

(define-read-only (get-usage-record (usage-id (buff 32)))
  (ok (map-get? usage-records usage-id))
)

(define-read-only (get-period-ledger (integration principal) (period uint))
  (ok (map-get? period-ledgers { integration: integration, period: period }))
)

(define-read-only (get-current-period)
  (ok (current-period))
)

(define-read-only (get-monthly-period-burn-blocks)
  (ok MONTHLY_PERIOD_BURN_BLOCKS)
)

(define-read-only (get-outstanding-fee (integration principal) (period uint))
  (match (map-get? period-ledgers { integration: integration, period: period })
    ledger (if (>= (get accrued-fees ledger) (get settled-fees ledger))
      (ok (- (get accrued-fees ledger) (get settled-fees ledger)))
      (err ERR_LEDGER_INVARIANT))
    (ok u0))
)

(define-read-only (get-settlement (settlement-id (buff 32)))
  (ok (map-get? settlement-records settlement-id))
)
