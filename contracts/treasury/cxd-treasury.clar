;; @contract cxd-treasury
;; @desc Intelligence-Led Adaptive Yield Engine (AYE) for revenue allocation.
;; @version 1.3.0

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_SHARE u1001)
(define-constant ERR_POLICY_LOCKED u1002)
(define-constant ERR_OUT_OF_BOUNDS u1003)
(define-constant ERR_ARITHMETIC_OVERFLOW u1004)
(define-constant ERR_REVENUE_UNAUTHORIZED u1005)
(define-constant ERR_REVENUE_REPLAYED u1006)
(define-constant ERR_SOURCE_UNAUTHORIZED u1007)
(define-constant ERR_INVALID_AMOUNT u1008)
(define-constant ERR_INVALID_BUCKET u1009)
(define-constant ERR_RECIPIENT_NOT_CONFIGURED u1010)
(define-constant ERR_RELEASE_REPLAYED u1011)
(define-constant ERR_INSUFFICIENT_BUCKET u1012)
(define-constant ERR_INVALID_RECIPIENT u1013)
(define-constant ERR_INVALID_RELEASE_ID u1014)

;; Stable bucket identifiers. Recipients are deliberately unset at deploy time;
;; governance must configure each destination before any release can succeed.
(define-constant BUCKET_TREASURY u1)
(define-constant BUCKET_BOUNTY u2)
(define-constant BUCKET_LP u3)
(define-constant BUCKET_GRANT u4)
(define-constant BUCKET_BUYBACK u5)
(define-constant BUCKET_INSURANCE u6)

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
(define-data-var total-gross-stx-received uint u0)
(define-data-var total-released-stx uint u0)
(define-data-var policy-version uint u1)

(define-map authorized-stx-sources principal bool)
(define-map stx-bucket-recipients uint principal)

(define-map stx-release-receipts
  { bucket: uint, release-id: uint }
  {
    bucket: uint,
    release-id: uint,
    recipient: principal,
    amount: uint,
    caller: principal,
    released-at: uint
  })

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
    policy-version: uint,
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

(define-private (is-valid-bucket (bucket uint))
  (and (>= bucket BUCKET_TREASURY) (<= bucket BUCKET_INSURANCE))
)

(define-private (get-bucket-balance (bucket uint))
  (if (is-eq bucket BUCKET_TREASURY)
    (var-get treasury-stx-balance)
    (if (is-eq bucket BUCKET_BOUNTY)
      (var-get bounty-stx-balance)
      (if (is-eq bucket BUCKET_LP)
        (var-get lp-stx-balance)
        (if (is-eq bucket BUCKET_GRANT)
          (var-get grant-stx-balance)
          (if (is-eq bucket BUCKET_BUYBACK)
            (var-get buyback-stx-balance)
            (var-get insurance-stx-balance))))))
)

(define-private (set-bucket-balance (bucket uint) (amount uint))
  (if (is-eq bucket BUCKET_TREASURY)
    (var-set treasury-stx-balance amount)
    (if (is-eq bucket BUCKET_BOUNTY)
      (var-set bounty-stx-balance amount)
      (if (is-eq bucket BUCKET_LP)
        (var-set lp-stx-balance amount)
        (if (is-eq bucket BUCKET_GRANT)
          (var-set grant-stx-balance amount)
          (if (is-eq bucket BUCKET_BUYBACK)
            (var-set buyback-stx-balance amount)
            (var-set insurance-stx-balance amount))))))
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
    ;; These bounds are governance-configured safety rails. Keep them in force
    ;; in addition to the exact 10,000-bps conservation rule.
    (asserts! (>= lp (var-get min-lp-allowed)) (err ERR_OUT_OF_BOUNDS))
    (asserts! (<= insurance (var-get max-insurance-allowed)) (err ERR_OUT_OF_BOUNDS))

    (let ((next-policy-version (unwrap!
        (safe-add (var-get policy-version) u1)
        (err ERR_ARITHMETIC_OVERFLOW))))
      (begin
        (var-set treasury-share treasury)
        (var-set bounty-share bounty)
        (var-set lp-share lp)
        (var-set grant-share grant)
        (var-set buyback-share buyback)
        (var-set insurance-share insurance)
        (var-set policy-version next-policy-version)

        (print {
          event: "rebalanced",
          policy-version: next-policy-version,
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

;; Governance safety rails for future policy changes. No new economic values
;; are introduced here; callers must choose bounds within the existing bps
;; domain and rebalance continues to enforce them.
(define-public (set-bounds (min-lp uint) (max-insurance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (<= min-lp u10000) (err ERR_OUT_OF_BOUNDS))
    (asserts! (<= max-insurance u10000) (err ERR_OUT_OF_BOUNDS))
    (var-set min-lp-allowed min-lp)
    (var-set max-insurance-allowed max-insurance)
    (print {
      event: "fiscal-dam-bounds-updated",
      min-lp: min-lp,
      max-insurance: max-insurance
    })
    (ok true)
  )
)

;; Recipients are intentionally fail-closed after deployment. Governance must
;; configure an audited destination for each bucket before release is possible.
(define-public (set-stx-bucket-recipient (bucket uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-valid-bucket bucket) (err ERR_INVALID_BUCKET))
    (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR_INVALID_RECIPIENT))
    (map-set stx-bucket-recipients bucket recipient)
    (print {
      event: "stx-bucket-recipient-configured",
      bucket: bucket,
      recipient: recipient
    })
    (ok true)
  )
)

(define-public (clear-stx-bucket-recipient (bucket uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-valid-bucket bucket) (err ERR_INVALID_BUCKET))
    (map-delete stx-bucket-recipients bucket)
    (print {
      event: "stx-bucket-recipient-cleared",
      bucket: bucket
    })
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

;; Releases only from an explicitly configured bucket recipient. The receipt
;; key is {bucket, release-id}; the chosen bucket is decremented only after the
;; custody transfer succeeds, and the release ID cannot be replayed.
(define-public (release-stx-bucket
    (bucket uint)
    (release-id uint)
    (amount uint))
  (begin
    (asserts!
      (or
        (is-eq contract-caller (var-get admin))
        (is-eq contract-caller (var-get agent-treasury-principal)))
      (err ERR_UNAUTHORIZED))
    (asserts! (is-valid-bucket bucket) (err ERR_INVALID_BUCKET))
    (asserts! (> release-id u0) (err ERR_INVALID_RELEASE_ID))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts!
      (is-none (map-get? stx-release-receipts { bucket: bucket, release-id: release-id }))
      (err ERR_RELEASE_REPLAYED))
    (let (
      (recipient (unwrap! (map-get? stx-bucket-recipients bucket) (err ERR_RECIPIENT_NOT_CONFIGURED)))
      (balance (get-bucket-balance bucket))
      (next-total-released (unwrap!
        (safe-add (var-get total-released-stx) amount)
        (err ERR_ARITHMETIC_OVERFLOW)))
    )
      (begin
        (asserts! (<= amount balance) (err ERR_INSUFFICIENT_BUCKET))
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (set-bucket-balance bucket (- balance amount))
        (var-set total-released-stx next-total-released)
        (map-set stx-release-receipts { bucket: bucket, release-id: release-id } {
          bucket: bucket,
          release-id: release-id,
          recipient: recipient,
          amount: amount,
          caller: contract-caller,
          released-at: burn-block-height
        })
        (print {
          event: "stx-bucket-released",
          bucket: bucket,
          release-id: release-id,
          recipient: recipient,
          amount: amount,
          caller: contract-caller,
          released-at: burn-block-height
        })
        (ok true)
      )
    )
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
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))

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
        (next-total-gross (unwrap! (safe-add (var-get total-gross-stx-received) amount) (err ERR_ARITHMETIC_OVERFLOW)))
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
            policy-version: (var-get policy-version),
            recorded-at: burn-block-height
          })
          (var-set treasury-stx-balance next-treasury)
          (var-set bounty-stx-balance next-bounty)
          (var-set lp-stx-balance next-lp)
          (var-set grant-stx-balance next-grant)
          (var-set buyback-stx-balance next-buyback)
          (var-set insurance-stx-balance next-insurance)
          (var-set total-gross-stx-received next-total-gross)
          (print {
            event: "gross-stx-fiscal-dam-received",
            source: source,
            payment-id: payment-id,
            gross-amount: amount,
            policy-version: (var-get policy-version),
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
  (ok { compliant: true, version: "v1.3.0" })
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
  (if (is-eq bucket BUCKET_TREASURY)
    (ok (var-get treasury-stx-balance))
    (if (is-eq bucket BUCKET_BOUNTY)
      (ok (var-get bounty-stx-balance))
      (if (is-eq bucket BUCKET_LP)
        (ok (var-get lp-stx-balance))
        (if (is-eq bucket BUCKET_GRANT)
          (ok (var-get grant-stx-balance))
          (if (is-eq bucket BUCKET_BUYBACK)
            (ok (var-get buyback-stx-balance))
            (if (is-eq bucket BUCKET_INSURANCE)
              (ok (var-get insurance-stx-balance))
              (err ERR_OUT_OF_BOUNDS)))))))
)

(define-read-only (get-stx-bucket-recipient (bucket uint))
  (if (is-valid-bucket bucket)
    (ok (map-get? stx-bucket-recipients bucket))
    (err ERR_INVALID_BUCKET))
)

(define-read-only (get-stx-release-receipt (bucket uint) (release-id uint))
  (ok (map-get? stx-release-receipts { bucket: bucket, release-id: release-id }))
)

(define-read-only (get-policy-version)
  (ok (var-get policy-version))
)

(define-read-only (get-bounds)
  (ok {
    min-lp: (var-get min-lp-allowed),
    max-insurance: (var-get max-insurance-allowed)
  })
)

(define-read-only (get-total-gross-stx-received)
  (ok (var-get total-gross-stx-received))
)

(define-read-only (get-total-released-stx)
  (ok (var-get total-released-stx))
)

;; Gross receipt evidence is conserved as the sum of current bucket balances
;; plus governed releases. No bucket is reduced without a release receipt.
(define-read-only (get-stx-accounting)
  (let ((bucket-total (+
      (var-get treasury-stx-balance)
      (+ (var-get bounty-stx-balance)
        (+ (var-get lp-stx-balance)
          (+ (var-get grant-stx-balance)
            (+ (var-get buyback-stx-balance) (var-get insurance-stx-balance))))))))
    (ok {
      gross-received: (var-get total-gross-stx-received),
      released: (var-get total-released-stx),
      bucket-total: bucket-total,
      accounted-total: (+ bucket-total (var-get total-released-stx))
    })
  )
)
