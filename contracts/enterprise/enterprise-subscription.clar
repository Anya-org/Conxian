;; enterprise-subscription.clar
;; STX-only prepaid enterprise subscriptions.
;;
;; Purchases are explicit and never pull funds automatically. Subscription
;; state is written only after the full gross payment succeeds through:
;; enterprise-subscription -> revenue-automation -> revenue-distributor ->
;; cxd-treasury.

(impl-trait .enterprise-subscription-trait.enterprise-subscription-trait)

(define-constant ERR_UNAUTHORIZED u5100)
(define-constant ERR_PLAN_NOT_FOUND u5101)
(define-constant ERR_PLAN_INACTIVE u5102)
(define-constant ERR_INVALID_PERIOD u5103)
(define-constant ERR_SUBSCRIPTION_EXISTS u5104)
(define-constant ERR_SUBSCRIPTION_NOT_FOUND u5105)
(define-constant ERR_SUBSCRIPTION_EXPIRED u5106)
(define-constant ERR_PAYMENT_REPLAYED u5107)
(define-constant ERR_ARITHMETIC_OVERFLOW u5108)
(define-constant ERR_CONSUMER_UNAUTHORIZED u5109)
(define-constant ERR_FEATURE_NOT_FOUND u5110)
(define-constant ERR_FEATURE_DISABLED u5111)
(define-constant ERR_USAGE_INVALID u5112)
(define-constant ERR_USAGE_REPLAYED u5113)
(define-constant ERR_USAGE_LIMIT u5114)
(define-constant ERR_SUBSCRIBER_MISMATCH u5115)
(define-constant ERR_PLAN_REGISTRY u5116)
(define-constant ERR_INVALID_AMOUNT u5117)

(define-constant MONTHLY_PERIOD_BLOCKS u4320)
(define-constant ANNUAL_PERIOD_BLOCKS u51840)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-data-var owner principal tx-sender)

(define-map subscriptions
  principal
  {
    tier-id: uint,
    plan-version: uint,
    billing-period: uint,
    paid-from: uint,
    paid-through: uint,
    cancelled: bool,
    usage-period-start: uint
  }
)

;; Payment IDs are globally unique across this subscription route. The same
;; ID is therefore also unique in the downstream {source, payment-id}
;; treasury receipt because every payment uses this contract as its source.
(define-map payment-records
  uint
  {
    subscriber: principal,
    payment-id: uint,
    amount: uint,
    tier-id: uint,
    plan-version: uint,
    billing-period: uint,
    paid-at: uint
  }
)

(define-map authorized-consumers principal bool)

(define-map usage-totals
  { subscriber: principal, feature-id: (string-ascii 32), period-start: uint }
  uint
)

(define-map usage-records
  {
    consumer: principal,
    subscriber: principal,
    feature-id: (string-ascii 32),
    period-start: uint,
    usage-id: (buff 32)
  }
  {
    units: uint,
    period-start: uint,
    recorded-at: uint
  }
)

(define-private (is-owner)
  (is-eq tx-sender (var-get owner))
)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right)))
)

(define-private (load-plan (tier-id uint) (version uint))
  (let ((plan-option (unwrap!
    (contract-call? .enterprise-plan-registry get-plan tier-id version)
    (err ERR_PLAN_REGISTRY))))
    (ok (unwrap! plan-option (err ERR_PLAN_NOT_FOUND)))
  )
)

(define-private (load-feature
    (tier-id uint)
    (version uint)
    (feature-id (string-ascii 32)))
  (let ((feature-option (unwrap!
    (contract-call? .enterprise-plan-registry get-plan-feature tier-id version feature-id)
    (err ERR_PLAN_REGISTRY))))
    (ok (unwrap! feature-option (err ERR_FEATURE_NOT_FOUND)))
  )
)

(define-private (price-for (plan {
    tier-id: uint,
    version: uint,
    monthly-price: uint,
    annual-price: uint,
    required-kyc-tier: uint,
    active: bool
  }) (billing-period uint))
  (if (is-eq billing-period MONTHLY_PERIOD_BLOCKS)
    (ok (get monthly-price plan))
    (if (is-eq billing-period ANNUAL_PERIOD_BLOCKS)
      (ok (get annual-price plan))
      (err ERR_INVALID_PERIOD)))
)

(define-private (route-payment
    (amount uint)
    (source principal)
    (payment-id uint))
  (begin
    ;; The source contract receives exact custody first. The adapter then
    ;; moves that same amount through each canonical route hop.
    (try! (stx-transfer? amount tx-sender source))
    (try! (as-contract
      (contract-call? .revenue-automation route-stx-revenue amount source payment-id)))
    (ok true)
  )
)

(define-private (get-used
    (subscriber principal)
    (feature-id (string-ascii 32))
    (period-start uint))
  (default-to u0 (map-get? usage-totals {
    subscriber: subscriber,
    feature-id: feature-id,
    period-start: period-start
  }))
)

(define-private (read-entitlement
    (subscriber principal)
    (feature-id (string-ascii 32)))
  (match (map-get? subscriptions subscriber)
    subscription
      (let ((feature (try! (load-feature
        (get tier-id subscription)
        (get plan-version subscription)
        feature-id))))
        (let (
          (used (get-used subscriber feature-id (get usage-period-start subscription)))
          (active (< burn-block-height (get paid-through subscription)))
          (remaining (if (>= used (get limit feature))
            u0
            (- (get limit feature) used)))
        )
          (ok (some {
            entitled: (and active (get enabled feature)),
            limit: (get limit feature),
            used: used,
            remaining: remaining,
            paid-through: (get paid-through subscription),
            tier-id: (get tier-id subscription),
            plan-version: (get plan-version subscription)
          }))
        )
      )
    (ok none))
)

(define-public (initialize (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (register-consumer (consumer principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set authorized-consumers consumer true)
    (ok true)
  )
)

(define-public (revoke-consumer (consumer principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set authorized-consumers consumer false)
    (ok true)
  )
)

(define-public (subscribe
    (tier-id uint)
    (version uint)
    (billing-period uint)
    (payment-id uint)
    (amount uint))
  (let (
    (subscriber tx-sender)
    (source (as-contract tx-sender))
  )
    (begin
      (asserts! (is-none (map-get? subscriptions subscriber)) (err ERR_SUBSCRIPTION_EXISTS))
      (asserts! (is-none (map-get? payment-records payment-id)) (err ERR_PAYMENT_REPLAYED))
      (let (
        (plan (try! (load-plan tier-id version)))
        (price (try! (price-for plan billing-period)))
        (paid-through (unwrap!
          (safe-add burn-block-height billing-period)
          (err ERR_ARITHMETIC_OVERFLOW)))
      )
        (begin
          (asserts! (get active plan) (err ERR_PLAN_INACTIVE))
          (try! (contract-call? .compliance-hooks
            validate-enterprise-compliance
            subscriber
            (get required-kyc-tier plan)))
          (asserts! (is-eq amount price) (err ERR_INVALID_AMOUNT))
          (try! (route-payment amount source payment-id))
          (map-set payment-records payment-id {
            subscriber: subscriber,
            payment-id: payment-id,
            amount: amount,
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            paid-at: burn-block-height
          })
          (map-set subscriptions subscriber {
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            paid-from: burn-block-height,
            paid-through: paid-through,
            cancelled: false,
            usage-period-start: burn-block-height
          })
          (print {
            event: "enterprise-subscription-created",
            subscriber: subscriber,
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            amount: amount,
            payment-id: payment-id,
            paid-through: paid-through
          })
          (ok true)
        )
      )
    )
  )
)

(define-public (renew
    (tier-id uint)
    (version uint)
    (billing-period uint)
    (payment-id uint)
    (amount uint))
  (let (
    (subscriber tx-sender)
    (source (as-contract tx-sender))
    (subscription (unwrap! (map-get? subscriptions tx-sender) (err ERR_SUBSCRIPTION_NOT_FOUND)))
    (base-height (if (< burn-block-height (get paid-through subscription))
      (get paid-through subscription)
      burn-block-height))
  )
    (begin
      (asserts! (is-none (map-get? payment-records payment-id)) (err ERR_PAYMENT_REPLAYED))
      (let (
        (plan (try! (load-plan tier-id version)))
        (price (try! (price-for plan billing-period)))
        (paid-through (unwrap!
          (safe-add base-height billing-period)
          (err ERR_ARITHMETIC_OVERFLOW)))
      )
        (begin
          (asserts! (get active plan) (err ERR_PLAN_INACTIVE))
          (asserts! (is-eq amount price) (err ERR_INVALID_AMOUNT))
          (try! (contract-call? .compliance-hooks
            validate-enterprise-compliance
            subscriber
            (get required-kyc-tier plan)))
          (try! (route-payment amount source payment-id))
          (map-set payment-records payment-id {
            subscriber: subscriber,
            payment-id: payment-id,
            amount: amount,
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            paid-at: burn-block-height
          })
          (map-set subscriptions subscriber {
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            paid-from: base-height,
            paid-through: paid-through,
            cancelled: false,
            usage-period-start: base-height
          })
          (print {
            event: "enterprise-subscription-renewed",
            subscriber: subscriber,
            tier-id: tier-id,
            plan-version: version,
            billing-period: billing-period,
            amount: amount,
            payment-id: payment-id,
            paid-through: paid-through
          })
          (ok true)
        )
      )
    )
  )
)

;; Cancellation is period-end only: it marks the record without changing the
;; paid-through block or active entitlement before that block.
(define-public (cancel)
  (let ((subscription (unwrap! (map-get? subscriptions tx-sender) (err ERR_SUBSCRIPTION_NOT_FOUND))))
    (begin
      (asserts! (< burn-block-height (get paid-through subscription)) (err ERR_SUBSCRIPTION_EXPIRED))
      (asserts! (not (get cancelled subscription)) (err ERR_SUBSCRIPTION_EXPIRED))
      (map-set subscriptions tx-sender (merge subscription { cancelled: true }))
      (print {
        event: "enterprise-subscription-cancelled-at-period-end",
        subscriber: tx-sender,
        paid-through: (get paid-through subscription)
      })
      (ok true)
    )
  )
)

(define-public (record-usage
    (subscriber principal)
    (feature-id (string-ascii 32))
    (usage-id (buff 32))
    (units uint))
  (let (
    (consumer contract-caller)
    (subscription (unwrap! (map-get? subscriptions subscriber) (err ERR_SUBSCRIPTION_NOT_FOUND)))
    (usage-key {
      consumer: consumer,
      subscriber: subscriber,
      feature-id: feature-id,
      period-start: (get usage-period-start subscription),
      usage-id: usage-id
    })
  )
    (begin
      ;; The original payer must be the subscription owner. This check lives
      ;; at the authoritative boundary, not only in the generic facade.
      (asserts! (is-eq tx-sender subscriber) (err ERR_SUBSCRIBER_MISMATCH))
      (asserts! (default-to false (map-get? authorized-consumers consumer)) (err ERR_CONSUMER_UNAUTHORIZED))
      (asserts! (> units u0) (err ERR_USAGE_INVALID))
      (asserts! (< burn-block-height (get paid-through subscription)) (err ERR_SUBSCRIPTION_EXPIRED))
      (asserts! (is-none (map-get? usage-records usage-key)) (err ERR_USAGE_REPLAYED))
      (let ((feature (try! (load-feature
        (get tier-id subscription)
        (get plan-version subscription)
        feature-id))))
        (begin
          (asserts! (get enabled feature) (err ERR_FEATURE_DISABLED))
          (let (
            (used (get-used subscriber feature-id (get usage-period-start subscription)))
            (new-used (unwrap!
              (safe-add used units)
              (err ERR_ARITHMETIC_OVERFLOW)))
          )
            (begin
              (asserts! (<= new-used (get limit feature)) (err ERR_USAGE_LIMIT))
              (map-set usage-records usage-key {
                units: units,
                period-start: (get usage-period-start subscription),
                recorded-at: burn-block-height
              })
              (map-set usage-totals {
                subscriber: subscriber,
                feature-id: feature-id,
                period-start: (get usage-period-start subscription)
              } new-used)
              (print {
                event: "enterprise-subscription-usage-recorded",
                consumer: consumer,
                subscriber: subscriber,
                feature-id: feature-id,
                usage-id: usage-id,
                period-start: (get usage-period-start subscription),
                units: units,
                used: new-used
              })
              (ok new-used)
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-owner)
  (var-get owner)
)

(define-read-only (get-consumer-status (consumer principal))
  (default-to false (map-get? authorized-consumers consumer))
)

(define-read-only (get-subscription (subscriber principal))
  (ok (match (map-get? subscriptions subscriber)
    subscription (some {
      tier-id: (get tier-id subscription),
      plan-version: (get plan-version subscription),
      billing-period: (get billing-period subscription),
      paid-from: (get paid-from subscription),
      paid-through: (get paid-through subscription),
      active: (< burn-block-height (get paid-through subscription)),
      cancelled: (get cancelled subscription),
      usage-period-start: (get usage-period-start subscription)
    })
    none))
)

(define-read-only (is-entitled
    (subscriber principal)
    (feature-id (string-ascii 32)))
  (let ((entitlement (try! (read-entitlement subscriber feature-id))))
    (ok (match entitlement
      data (get entitled data)
      false)))
)

(define-read-only (get-entitlement
    (subscriber principal)
    (feature-id (string-ascii 32)))
  (read-entitlement subscriber feature-id)
)

(define-read-only (get-usage-record
    (consumer principal)
    (subscriber principal)
    (feature-id (string-ascii 32))
    (period-start uint)
    (usage-id (buff 32)))
  (ok (map-get? usage-records {
    consumer: consumer,
    subscriber: subscriber,
    feature-id: feature-id,
    period-start: period-start,
    usage-id: usage-id
  }))
)

(define-read-only (get-usage-total
    (subscriber principal)
    (feature-id (string-ascii 32))
    (period-start uint))
  (ok (get-used subscriber feature-id period-start))
)

(define-read-only (get-payment-record (payment-id uint))
  (ok (map-get? payment-records payment-id))
)
