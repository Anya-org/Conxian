;; @contract cxd-treasury
;; @desc Intelligence-Led Adaptive Yield Engine (AYE) for revenue allocation.
;; @version 1.2.0

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_SHARE u1001)
(define-constant ERR_POLICY_LOCKED u1002)
(define-constant ERR_OUT_OF_BOUNDS u1003)
(define-constant ERR_ARITHMETIC_OVERFLOW u1004)
(define-constant ERR_REVENUE_UNAUTHORIZED u1005)
(define-constant ERR_REVENUE_REPLAYED u1006)
(define-constant ERR_SOURCE_UNAUTHORIZED u1007)

;; CXIP-013 Baseline (Sum = 10000)
(define-constant TARGET_TREASURY_SHARE u4500)
(define-constant TARGET_BOUNTY_SHARE u3000)
(define-constant TARGET_LP_SHARE u1500)
(define-constant TARGET_GRANT_SHARE u500)
(define-constant TARGET_BUYBACK_SHARE u500)

;; Current allocations (Basis points: 10000 = 100%)
(define-data-var treasury-share uint u4500)
(define-data-var bounty-share uint u3000)
(define-data-var lp-share uint u1500)
(define-data-var grant-share uint u500)
(define-data-var buyback-share uint u500)
(define-data-var insurance-share uint u0)

;; Gross-STX Fiscal Dam balances. These are accounting buckets; no native
;; STX buyback primitive exists, so the buyback bucket remains governed STX.
(define-data-var treasury-stx-balance uint u0)
(define-data-var bounty-stx-balance uint u0)
(define-data-var lp-stx-balance uint u0)
(define-data-var grant-stx-balance uint u0)
(define-data-var buyback-stx-balance uint u0)
(define-data-var insurance-stx-balance uint u0)

(define-map authorized-stx-sources principal bool)

;; A receipt is written once for each source/payment pair and snapshots both
;; the gross amount and the allocation policy used for that payment.
(define-map stx-receipts
  { source: principal, payment-id: uint }
  {
    source: principal,
    payment-id: uint,
    gross-amount: uint,
    treasury-amount: uint,
    bounty-amount: uint,
    lp-amount: uint,
    grant-amount: uint,
    buyback-amount: uint,
    insurance-amount: uint,
    treasury-bps: uint,
    bounty-bps: uint,
    lp-bps: uint,
    grant-bps: uint,
    buyback-bps: uint,
    insurance-bps: uint,
    recorded-at: uint
  })

;; Accrued Claims for Stakers (Priority Claims)
(define-map accrued-claims principal uint)

;; Governance & Authorization
(define-data-var admin principal tx-sender)
(define-data-var agent-treasury-principal principal tx-sender)
(define-data-var revenue-distributor-principal principal tx-sender)
(define-data-var policy-locked bool false)

;; State Bounds
(define-data-var min-lp-allowed uint u0)
(define-data-var max-insurance-allowed uint u10000)

(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right)))
)

(define-private (safe-share (amount uint) (share uint))
  (if (is-eq share u0)
    (some u0)
    (if (> amount (/ MAX_UINT share))
      none
      (some (/ (* amount share) u10000))))
)

(define-private (is-authorized-stx-source (source principal))
  (default-to false (map-get? authorized-stx-sources source))
)

;; --- Read-Only Functions ---

;; @desc Returns the current allocation percentages for all protocol buckets.
(define-read-only (get-allocation-percentages)
  (ok {
    treasury: (var-get treasury-share),
    bounty: (var-get bounty-share),
    lp: (var-get lp-share),
    grant: (var-get grant-share),
    buyback: (var-get buyback-share),
    insurance: (var-get insurance-share),
    staking: (var-get lp-share),
    dev: (var-get treasury-share)
  })
)

;; @desc Returns the accrued claim for a specific token.
(define-read-only (get-accrued-claim (token principal))
  (default-to u0 (map-get? accrued-claims token))
)

;; --- Public Functions ---

;; @desc Rebalances the protocol revenue allocation across 6 buckets.
(define-public (rebalance
    (treasury uint)
    (bounty uint)
    (lp uint)
    (grant uint)
    (buyback uint)
    (insurance uint)
  )
  (begin
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller (var-get agent-treasury-principal))) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (asserts! (is-eq (+ treasury (+ bounty (+ lp (+ grant (+ buyback insurance))))) u10000) (err ERR_INVALID_SHARE))

    (var-set treasury-share treasury)
    (var-set bounty-share bounty)
    (var-set lp-share lp)
    (var-set grant-share grant)
    (var-set buyback-share buyback)
    (var-set insurance-share insurance)

    (print {
      event: "rebalanced",
      treasury: treasury,
      bounty: bounty,
      lp: lp,
      grant: grant,
      buyback: buyback,
      insurance: insurance,
      timestamp: block-height
    })
    (ok true)
  )
)

;; @desc Records a diverted claim for priority stakers.
(define-public (record-diverted-claim (token principal) (amount uint))
  (begin
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller (var-get revenue-distributor-principal))) (err ERR_UNAUTHORIZED))
    (let (
      (current (get-accrued-claim token))
    )
      (map-set accrued-claims token (+ current amount))
      (ok true)
    )
  )
)

;; --- Admin Functions ---

;; @desc Initializes the treasury with a new administrator.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Sets the authorized agent and distributor principals.
(define-public (set-authorized-principals (agent principal) (distributor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set agent-treasury-principal agent)
    (var-set revenue-distributor-principal distributor)
    (ok true)
  )
)

;; Explicitly allow a source contract to enter the canonical gross-STX route.
(define-public (authorize-stx-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set authorized-stx-sources source true)
    (ok true)
  )
)

(define-public (revoke-stx-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set authorized-stx-sources source false)
    (ok true)
  )
)

;; Canonical source -> revenue-automation -> revenue-distributor -> cxd-
;; treasury route. The immediate caller must be the distributor and the
;; source/payment pair is replay protected by an immutable receipt.
(define-public (record-stx-revenue
    (source principal)
    (payment-id uint)
    (amount uint))
  (begin
    (asserts!
      (or
        (is-eq contract-caller (var-get revenue-distributor-principal)))
      (err ERR_REVENUE_UNAUTHORIZED))
    (asserts! (is-authorized-stx-source source) (err ERR_SOURCE_UNAUTHORIZED))
    (asserts!
      (is-none (map-get? stx-receipts { source: source, payment-id: payment-id }))
      (err ERR_REVENUE_REPLAYED))

    ;; The distributor is the immediate STX payer. This final custody hop is
    ;; deliberately performed before accounting so any failure rolls back the
    ;; entire route and no intermediate contract retains STX.
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (let (
      (treasury-amount (unwrap! (safe-share amount (var-get treasury-share)) (err ERR_ARITHMETIC_OVERFLOW)))
      (bounty-amount (unwrap! (safe-share amount (var-get bounty-share)) (err ERR_ARITHMETIC_OVERFLOW)))
      (lp-amount (unwrap! (safe-share amount (var-get lp-share)) (err ERR_ARITHMETIC_OVERFLOW)))
      (grant-amount (unwrap! (safe-share amount (var-get grant-share)) (err ERR_ARITHMETIC_OVERFLOW)))
      (buyback-amount (unwrap! (safe-share amount (var-get buyback-share)) (err ERR_ARITHMETIC_OVERFLOW)))
    )
      (let (
        (first-five (unwrap!
          (safe-add
            (unwrap! (safe-add treasury-amount bounty-amount) (err ERR_ARITHMETIC_OVERFLOW))
            (unwrap!
              (safe-add
                (unwrap! (safe-add lp-amount grant-amount) (err ERR_ARITHMETIC_OVERFLOW))
                buyback-amount)
              (err ERR_ARITHMETIC_OVERFLOW)))
          (err ERR_ARITHMETIC_OVERFLOW)))
        (insurance-amount (- amount first-five))
        (next-treasury (unwrap! (safe-add (var-get treasury-stx-balance) treasury-amount) (err ERR_ARITHMETIC_OVERFLOW)))
        (next-bounty (unwrap! (safe-add (var-get bounty-stx-balance) bounty-amount) (err ERR_ARITHMETIC_OVERFLOW)))
        (next-lp (unwrap! (safe-add (var-get lp-stx-balance) lp-amount) (err ERR_ARITHMETIC_OVERFLOW)))
        (next-grant (unwrap! (safe-add (var-get grant-stx-balance) grant-amount) (err ERR_ARITHMETIC_OVERFLOW)))
        (next-buyback (unwrap! (safe-add (var-get buyback-stx-balance) buyback-amount) (err ERR_ARITHMETIC_OVERFLOW)))
        (next-insurance (unwrap! (safe-add (var-get insurance-stx-balance) insurance-amount) (err ERR_ARITHMETIC_OVERFLOW)))
      )
        (begin
          (asserts! (<= first-five amount) (err ERR_ARITHMETIC_OVERFLOW))
          (map-set stx-receipts { source: source, payment-id: payment-id } {
            source: source,
            payment-id: payment-id,
            gross-amount: amount,
            treasury-amount: treasury-amount,
            bounty-amount: bounty-amount,
            lp-amount: lp-amount,
            grant-amount: grant-amount,
            buyback-amount: buyback-amount,
            insurance-amount: insurance-amount,
            treasury-bps: (var-get treasury-share),
            bounty-bps: (var-get bounty-share),
            lp-bps: (var-get lp-share),
            grant-bps: (var-get grant-share),
            buyback-bps: (var-get buyback-share),
            insurance-bps: (var-get insurance-share),
            recorded-at: burn-block-height
          })
          (var-set treasury-stx-balance next-treasury)
          (var-set bounty-stx-balance next-bounty)
          (var-set lp-stx-balance next-lp)
          (var-set grant-stx-balance next-grant)
          (var-set buyback-stx-balance next-buyback)
          (var-set insurance-stx-balance next-insurance)
          (print {
            event: "gross-stx-fiscal-dam-received",
            source: source,
            payment-id: payment-id,
            gross-amount: amount,
            treasury-amount: treasury-amount,
            bounty-amount: bounty-amount,
            lp-amount: lp-amount,
            grant-amount: grant-amount,
            buyback-amount: buyback-amount,
            insurance-amount: insurance-amount,
            timestamp: burn-block-height
          })
          (ok true)
        )
      )
    )
  )
)

;; @desc Updates the administrative principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Returns the protocol status.
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.2.0" })
)

(define-read-only (get-stx-receipt (source principal) (payment-id uint))
  (ok (map-get? stx-receipts { source: source, payment-id: payment-id }))
)

(define-read-only (get-stx-bucket-balances)
  (ok {
    treasury: (var-get treasury-stx-balance),
    bounty: (var-get bounty-stx-balance),
    lp: (var-get lp-stx-balance),
    grant: (var-get grant-stx-balance),
    buyback: (var-get buyback-stx-balance),
    insurance: (var-get insurance-stx-balance)
  })
)

(define-read-only (get-stx-bucket-balance (bucket uint))
  (if (is-eq bucket u1)
    (ok (var-get treasury-stx-balance))
    (if (is-eq bucket u2)
      (ok (var-get bounty-stx-balance))
      (if (is-eq bucket u3)
        (ok (var-get lp-stx-balance))
        (if (is-eq bucket u4)
          (ok (var-get grant-stx-balance))
          (if (is-eq bucket u5)
            (ok (var-get buyback-stx-balance))
            (if (is-eq bucket u6)
              (ok (var-get insurance-stx-balance))
              (err ERR_OUT_OF_BOUNDS)))))))
)
