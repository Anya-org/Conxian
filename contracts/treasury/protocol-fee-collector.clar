;; protocol-fee-collector.clar
;;
;; Canonical scheduled protocol-fee settlement for explicitly registered
;; source/stream/asset combinations. The collector replaces a legacy charge on
;; a designated fee base; it must not be called in addition to that charge.
;;
;; Phase 1 deliberately supports only two concrete settlement paths:
;; - SIP-010 fungible tokens through the existing revenue-distributor route.
;; - native STX through the existing revenue-distributor route.
;;
;; The payer is always tx-sender. This is intentional: standard SIP-010
;; transfer implementations require the transaction sender to equal `from`,
;; and STX settlement has the same atomic sender requirement. A source contract
;; can call this contract on behalf of a payer only when that payer initiated
;; the transaction. No allowance or generic token behavior is assumed.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Errors ---

(define-constant ERR_UNAUTHORIZED (err u4100))
(define-constant ERR_PAUSED (err u4101))
(define-constant ERR_NOT_ACTIVE (err u4102))
(define-constant ERR_INVALID_CONFIG (err u4103))
(define-constant ERR_SOURCE_NOT_AUTHORIZED (err u4104))
(define-constant ERR_STREAM_NOT_FOUND (err u4105))
(define-constant ERR_STREAM_INACTIVE (err u4106))
(define-constant ERR_INVALID_ROUTE (err u4107))
(define-constant ERR_INVALID_AMOUNT (err u4109))
(define-constant ERR_SETTLEMENT_REPLAYED (err u4110))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u4111))
(define-constant ERR_INVALID_ACTIVATION (err u4112))
(define-constant ERR_ACTIVATION_LOCKED (err u4113))
(define-constant ERR_ACCOUNTING_OVERFLOW (err u4114))
(define-constant ERR_INVALID_ASSET_KIND (err u4115))

;; --- Constants ---

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant BPS_DENOMINATOR u10000)
(define-constant BPS_ROUNDING_OFFSET u9999)

;; Six ten-minute Bitcoin blocks per hour and thirty days per calendar month
;; is the documented approximation used for phase labels. The schedule itself
;; is block-based and has no wall-clock dependency.
(define-constant BURN_BLOCKS_PER_MONTH u4320)
(define-constant GROWTH_PHASE_MONTHS u12)
(define-constant MATURE_PHASE_MONTHS u36)
(define-constant GROWTH_PHASE_BLOCKS u51840)
(define-constant MATURE_PHASE_BLOCKS u155520)

(define-constant RATE_LAUNCH_BPS u200)
(define-constant RATE_GROWTH_BPS u150)
(define-constant RATE_MATURE_BPS u100)

(define-constant PHASE_LAUNCH u1)
(define-constant PHASE_GROWTH u2)
(define-constant PHASE_MATURE u3)

(define-constant ASSET_KIND_FT u1)
(define-constant ASSET_KIND_STX u2)
(define-constant ROUTE_REVENUE_DISTRIBUTOR u1)

;; --- Administrative and schedule state ---

(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var activation-burn-height uint burn-block-height)
(define-data-var total-settlements uint u0)

;; An authorized source is the immediate contract caller. A direct EOA source
;; is also supported because contract-caller equals tx-sender for a top-level
;; call. Stream registration remains admin-only and binds one asset to one
;; source/stream pair.
(define-map authorized-sources principal bool)

(define-map stream-configs
  {
    source: principal,
    stream-id: uint,
    asset-kind: uint,
    asset: (optional principal)
  }
  {
    active: bool,
    route: uint
  }
)

;; Asset identity is native: an FT uses (some token-contract-principal); STX
;; uses none together with asset-kind = ASSET_KIND_STX. The asset kind keeps
;; the two namespaces distinct without inventing a fake STX token principal.
(define-map fee-accounting
  {
    source: principal,
    stream-id: uint,
    asset-kind: uint,
    asset: (optional principal)
  }
  {
    eligible-base: uint,
    assessed-fees: uint,
    settled-fees: uint,
    settlement-count: uint,
    last-settled-burn-height: uint,
    last-settled-stacks-height: uint
  }
)

(define-map settlements (buff 32)
  ;; `block-height` is the Stacks context keyword exposed by the repository's
  ;; Clarinet 3.21 SDK; indexers should normalize this field as stacks height.
  {
    source: principal,
    stream-id: uint,
    asset-kind: uint,
    asset: (optional principal),
    payer: principal,
    eligible-base: uint,
    rate-bps: uint,
    phase: uint,
    assessed-amount: uint,
    settled-amount: uint,
    burn-height: uint,
    stacks-height: uint
  }
)

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

(define-private (calculate-fee-at-rate (eligible-fee-base uint) (rate-bps uint))
  (if (is-eq eligible-fee-base u0)
    (some u0)
    (let (
      (product-opt (safe-multiply eligible-fee-base rate-bps))
    )
      (if (is-none product-opt)
        none
        (let (
          (rounded-product-opt (safe-add
            (default-to u0 product-opt)
            BPS_ROUNDING_OFFSET))
        )
          (if (is-none rounded-product-opt)
            none
            (some (/ (default-to u0 rounded-product-opt) BPS_DENOMINATOR))))))))

(define-private (empty-accounting)
  {
    eligible-base: u0,
    assessed-fees: u0,
    settled-fees: u0,
    settlement-count: u0,
    last-settled-burn-height: u0,
    last-settled-stacks-height: u0
  }
)

;; --- Schedule resolution ---

;; Boundaries are exact and half-open:
;; [activation, activation + 12 months) = 200 bps
;; [activation + 12 months, activation + 36 months) = 150 bps
;; [activation + 36 months, infinity) = 100 bps
(define-private (resolve-phase-at (height uint))
  (let (
    (activation (var-get activation-burn-height))
    (growth-boundary (unwrap! (safe-add activation GROWTH_PHASE_BLOCKS) ERR_ARITHMETIC_OVERFLOW))
    (mature-boundary (unwrap! (safe-add activation MATURE_PHASE_BLOCKS) ERR_ARITHMETIC_OVERFLOW))
  )
    (if (< height activation)
      ERR_NOT_ACTIVE
      (if (< height growth-boundary)
        (ok { phase: PHASE_LAUNCH, rate-bps: RATE_LAUNCH_BPS })
        (if (< height mature-boundary)
          (ok { phase: PHASE_GROWTH, rate-bps: RATE_GROWTH_BPS })
          (ok { phase: PHASE_MATURE, rate-bps: RATE_MATURE_BPS })
        )
      )
    )
  )
)

;; --- Configuration helpers ---

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (load-stream-config
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal)))
  (let (
    (source-authorized (default-to false (map-get? authorized-sources source)))
    (config-opt (map-get? stream-configs {
      source: source,
      stream-id: stream-id,
      asset-kind: asset-kind,
      asset: asset
    }))
  )
    (begin
      (asserts! source-authorized ERR_SOURCE_NOT_AUTHORIZED)
      (let ((config (unwrap! config-opt ERR_STREAM_NOT_FOUND)))
        (begin
          (asserts! (get active config) ERR_STREAM_INACTIVE)
          (asserts! (is-eq (get route config) ROUTE_REVENUE_DISTRIBUTOR) ERR_INVALID_ROUTE)
          (ok config)
        )
      )
    )
  )
)

;; --- Admin controls ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-authorized-source (source principal) (authorized bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (map-set authorized-sources source authorized)
    (ok authorized)
  )
)

(define-public (register-ft-stream
    (source principal)
    (stream-id uint)
    (token principal)
    (route uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? authorized-sources source)) ERR_SOURCE_NOT_AUTHORIZED)
    (asserts! (> stream-id u0) ERR_INVALID_CONFIG)
    (asserts! (is-eq route ROUTE_REVENUE_DISTRIBUTOR) ERR_INVALID_ROUTE)
    (map-set stream-configs {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_FT,
      asset: (some token)
    } {
      active: true,
      route: route
    })
    (ok true)
  )
)

(define-public (register-stx-stream
    (source principal)
    (stream-id uint)
    (route uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? authorized-sources source)) ERR_SOURCE_NOT_AUTHORIZED)
    (asserts! (> stream-id u0) ERR_INVALID_CONFIG)
    (asserts! (is-eq route ROUTE_REVENUE_DISTRIBUTOR) ERR_INVALID_ROUTE)
    (map-set stream-configs {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_STX,
      asset: none
    } {
      active: true,
      route: route
    })
    (ok true)
  )
)

(define-public (set-stream-active
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal))
    (active bool))
  (let (
    (key {
      source: source,
      stream-id: stream-id,
      asset-kind: asset-kind,
      asset: asset
    })
  )
    (begin
      (asserts! (is-admin) ERR_UNAUTHORIZED)
      (asserts! (or (is-eq asset-kind ASSET_KIND_FT) (is-eq asset-kind ASSET_KIND_STX)) ERR_INVALID_ASSET_KIND)
      (asserts!
        (or
          (and (is-eq asset-kind ASSET_KIND_FT) (is-some asset))
          (and (is-eq asset-kind ASSET_KIND_STX) (is-none asset)))
        ERR_INVALID_CONFIG)
      (let ((config (unwrap! (map-get? stream-configs key) ERR_STREAM_NOT_FOUND)))
        (begin
          (map-set stream-configs key (merge config { active: active }))
          (ok active)
        )
      )
    )
  )
)

(define-public (pause)
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

(define-public (set-activation-burn-height (new-height uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get total-settlements) u0) ERR_ACTIVATION_LOCKED)
    (asserts! (>= new-height burn-block-height) ERR_INVALID_ACTIVATION)
    (asserts! (is-some (safe-add new-height MATURE_PHASE_BLOCKS)) ERR_INVALID_ACTIVATION)
    (var-set activation-burn-height new-height)
    (ok new-height)
  )
)

;; --- Settlement ---

;; The FT path transfers payer -> revenue-distributor, then invokes the
;; distributor under collector custody. Both calls and all accounting updates
;; are in one Clarity transaction and therefore roll back together on failure.
(define-public (settle-ft
    (token <sip-010-ft-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (let (
    (source contract-caller)
    (asset (some (contract-of token)))
    (config (try! (load-stream-config source stream-id ASSET_KIND_FT asset)))
    (phase (try! (resolve-phase-at burn-block-height)))
    (assessed-amount (unwrap! (calculate-fee-at-rate eligible-fee-base (get rate-bps phase)) ERR_ARITHMETIC_OVERFLOW))
    (accounting-key {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> eligible-fee-base u0) ERR_INVALID_AMOUNT)
      (asserts! (> assessed-amount u0) ERR_INVALID_AMOUNT)
      (asserts! (is-none (map-get? settlements settlement-id)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq (get route config) ROUTE_REVENUE_DISTRIBUTOR) ERR_INVALID_ROUTE)

      (try! (contract-call? token transfer assessed-amount tx-sender .revenue-distributor none))
      (try! (as-contract (contract-call? .revenue-distributor distribute-token token assessed-amount)))

      (map-set settlements settlement-id {
        source: source,
        stream-id: stream-id,
        asset-kind: ASSET_KIND_FT,
        asset: asset,
        payer: tx-sender,
        eligible-base: eligible-fee-base,
        rate-bps: (get rate-bps phase),
        phase: (get phase phase),
        assessed-amount: assessed-amount,
        settled-amount: assessed-amount,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-settled",
        settlement-id: settlement-id,
        source: source,
        stream-id: stream-id,
        payer: tx-sender,
        asset-kind: ASSET_KIND_FT,
        asset: asset,
        eligible-fee-base: eligible-fee-base,
        rate-bps: (get rate-bps phase),
        phase: (get phase phase),
        assessed-amount: assessed-amount,
        settled-amount: assessed-amount,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok assessed-amount)
    )
  )
)

;; Native STX uses the same schedule and accounting shape, but a separate
;; function so no caller can pretend an arbitrary FT has native transfer
;; semantics.
(define-public (settle-stx
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (let (
    (source contract-caller)
    (asset none)
    (config (try! (load-stream-config source stream-id ASSET_KIND_STX asset)))
    (phase (try! (resolve-phase-at burn-block-height)))
    (assessed-amount (unwrap! (calculate-fee-at-rate eligible-fee-base (get rate-bps phase)) ERR_ARITHMETIC_OVERFLOW))
    (accounting-key {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> eligible-fee-base u0) ERR_INVALID_AMOUNT)
      (asserts! (> assessed-amount u0) ERR_INVALID_AMOUNT)
      (asserts! (is-none (map-get? settlements settlement-id)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq (get route config) ROUTE_REVENUE_DISTRIBUTOR) ERR_INVALID_ROUTE)

      ;; Keep custody in the collector until the downstream route succeeds.
      ;; `as-contract tx-sender` evaluates to this collector principal.
      (try! (stx-transfer? assessed-amount tx-sender (as-contract tx-sender)))
      (try! (as-contract (contract-call? .revenue-distributor distribute-stx assessed-amount)))

      (map-set settlements settlement-id {
        source: source,
        stream-id: stream-id,
        asset-kind: ASSET_KIND_STX,
        asset: asset,
        payer: tx-sender,
        eligible-base: eligible-fee-base,
        rate-bps: (get rate-bps phase),
        phase: (get phase phase),
        assessed-amount: assessed-amount,
        settled-amount: assessed-amount,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-settled",
        settlement-id: settlement-id,
        source: source,
        stream-id: stream-id,
        payer: tx-sender,
        asset-kind: ASSET_KIND_STX,
        asset: asset,
        eligible-fee-base: eligible-fee-base,
        rate-bps: (get rate-bps phase),
        phase: (get phase phase),
        assessed-amount: assessed-amount,
        settled-amount: assessed-amount,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok assessed-amount)
    )
  )
)

;; --- Read-only audit API ---

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (is-authorized-source (source principal))
  (ok (default-to false (map-get? authorized-sources source)))
)

(define-read-only (get-stream-config
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal)))
  (ok (map-get? stream-configs {
    source: source,
    stream-id: stream-id,
    asset-kind: asset-kind,
    asset: asset
  }))
)

(define-read-only (get-accounting
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal)))
  (ok (map-get? fee-accounting {
    source: source,
    stream-id: stream-id,
    asset-kind: asset-kind,
    asset: asset
  }))
)

(define-read-only (get-settlement (settlement-id (buff 32)))
  (ok (map-get? settlements settlement-id))
)

(define-read-only (get-total-settlements)
  (ok (var-get total-settlements))
)

(define-read-only (get-activation-burn-height)
  (ok (var-get activation-burn-height))
)

(define-read-only (get-schedule)
  (let (
    (activation (var-get activation-burn-height))
    (growth-boundary (unwrap! (safe-add activation GROWTH_PHASE_BLOCKS) ERR_ARITHMETIC_OVERFLOW))
    (mature-boundary (unwrap! (safe-add activation MATURE_PHASE_BLOCKS) ERR_ARITHMETIC_OVERFLOW))
  )
    (ok {
      activation-burn-height: activation,
      launch-rate-bps: RATE_LAUNCH_BPS,
      growth-rate-bps: RATE_GROWTH_BPS,
      mature-rate-bps: RATE_MATURE_BPS,
      growth-boundary-inclusive: growth-boundary,
      mature-boundary-inclusive: mature-boundary,
      burn-blocks-per-month: BURN_BLOCKS_PER_MONTH,
      growth-phase-months: GROWTH_PHASE_MONTHS,
      mature-phase-months: MATURE_PHASE_MONTHS
    })
  )
)

(define-read-only (get-rate-at-burn-height (height uint))
  (resolve-phase-at height)
)

(define-read-only (get-current-rate)
  (resolve-phase-at burn-block-height)
)

(define-read-only (calculate-fee-at
    (eligible-fee-base uint)
    (height uint))
  (let (
    (phase (try! (resolve-phase-at height)))
  )
    (if (is-eq eligible-fee-base u0)
      (ok u0)
      (ok (unwrap! (calculate-fee-at-rate eligible-fee-base (get rate-bps phase)) ERR_ARITHMETIC_OVERFLOW))
    )
  )
)

(define-read-only (calculate-current-fee (eligible-fee-base uint))
  (calculate-fee-at eligible-fee-base burn-block-height)
)
