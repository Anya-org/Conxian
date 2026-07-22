;; protocol-fee-collector.clar
;;
;; Canonical scheduled protocol-fee settlement for explicitly registered
;; source/stream/asset combinations. The collector replaces a legacy charge on
;; a designated fee base; it must not be called in addition to that charge.
;;
;; Phase 1 settles only into this contract's own principal. It does not call the
;; Fiscal Dam, a DEX, lending, or a burn route in the same transaction.
;; Downstream treasury routing is an explicit, separately authorized sweep.
;;
;; The payer is always tx-sender. A source contract may call this contract on
;; behalf of a payer only when that payer initiated the transaction. SIP-010
;; transfer implementations therefore receive tx-sender as `from`, while the
;; collector supplies `.protocol-fee-collector` as `to`.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-fee-source-trait .protocol-fee-source-trait.protocol-fee-source-trait)

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
(define-constant ERR_STREAM_ALREADY_REGISTERED (err u4117))
(define-constant ERR_TREASURY_NOT_INITIALIZED (err u4118))
(define-constant ERR_ROUTE_EXCEEDS_COLLECTED (err u4119))
(define-constant ERR_CUSTODY_ACCOUNTING_INCONSISTENT (err u4120))
(define-constant ERR_CUSTODY_BALANCE_SHORTFALL (err u4121))
(define-constant ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE (err u4122))
(define-constant ERR_ASSET_BALANCE_READ_FAILED (err u4123))
(define-constant ERR_SOURCE_CALLBACK_UNAUTHORIZED (err u4124))
(define-constant ERR_SOURCE_CUSTODY_DELTA_MISMATCH (err u4125))

;; --- Constants ---

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant BPS_DENOMINATOR u10000)

;; Six ten-minute Bitcoin blocks per hour. These are policy-clock
;; approximations: they are burn-block boundaries, not exact wall-clock dates.
;; 365 days * 24 hours * 6 burn blocks/hour = 52,560.
(define-constant BURN_BLOCKS_PER_YEAR u52560)
(define-constant GROWTH_PHASE_BLOCKS u52560)
(define-constant MATURE_PHASE_BLOCKS u157680)
(define-constant GROWTH_PHASE_YEARS u1)
(define-constant MATURE_PHASE_YEARS u3)

(define-constant RATE_LAUNCH_BPS u200)
(define-constant RATE_GROWTH_BPS u150)
(define-constant RATE_MATURE_BPS u100)

(define-constant PHASE_LAUNCH u1)
(define-constant PHASE_GROWTH u2)
(define-constant PHASE_MATURE u3)

(define-constant ASSET_KIND_FT u1)
(define-constant ASSET_KIND_STX u2)

;; The route is an invariant label for the phase-1 collector-ingress path. It is
;; intentionally not a claim of downstream Fiscal Dam allocation.
(define-constant ROUTE_PROTOCOL_INGRESS u1)

;; Settlement custody and route destination are compile-time fixed. There is no
;; setter or settlement argument that can redirect either boundary.
(define-constant COLLECTOR_INGRESS .protocol-fee-collector)
(define-constant OPERATIONAL_TREASURY .operational-treasury)

;; --- Administrative and schedule state ---

(define-data-var admin principal tx-sender)
(define-data-var governance principal tx-sender)
(define-data-var paused bool false)
(define-data-var activation-burn-height uint burn-block-height)
(define-data-var total-settlements uint u0)
(define-data-var total-routes uint u0)
(define-data-var total-collected-stx uint u0)
(define-data-var total-routed-stx uint u0)
(define-data-var total-recovered-excess-stx uint u0)

;; An authorized source is the immediate contract caller. Direct EOAs remain
;; available for simnet and controlled operations, but production KPI evidence
;; should prefer contract sources that derive the base from their own
;; successful economic operation. Clarity does not provide a safe general
;; contract-principal type test for this registry.
(define-map authorized-sources principal bool)

;; A source/stream identity is immutable after registration. Asset and route
;; are stored in the value rather than the key so a later registration cannot
;; silently create a new asset namespace and discard residual accounting.
(define-map stream-configs
  {
    source: principal,
    stream-id: uint
  }
  {
    asset-kind: uint,
    asset: (optional principal),
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
    fee-remainder: uint,
    last-rate-bps: uint,
    last-phase: uint,
    last-settled-burn-height: uint,
    last-settled-stacks-height: uint
  }
)

;; Asset totals deliberately separate collection at this contract's ingress
;; from later routing to operational-treasury. The key keeps FT totals in the
;; token's native unit and keeps native STX separate via asset-kind + none.
(define-map asset-accounting
  {
    asset-kind: uint,
    asset: (optional principal)
  }
  {
    collected-fees: uint,
    routed-fees: uint,
    route-count: uint
  }
)

;; Direct deposits are not fee collection. Keep their recovery totals in a
;; separate map so excess recovery cannot inflate normal collected/routed
;; custody or revenue counters.
(define-map excess-recovery-accounting
  {
    asset-kind: uint,
    asset: (optional principal)
  }
  {
    recovered-excess: uint
  }
)

;; Replay protection is scoped to the authorized source plus settlement ID.
;; This permits independent sources to use the same local ID while preserving
;; uniqueness for every source's own settlement stream.
(define-map settlements
  {
    source: principal,
    settlement-id: (buff 32)
  }
  {
    settlement-id: (buff 32),
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
    recipient: principal,
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

(define-private (safe-sub (left uint) (right uint))
  (if (< left right)
    none
    (some (- left right)))
)

(define-private (safe-multiply (left uint) (right uint))
  (if (or (is-eq left u0) (is-eq right u0))
    (some u0)
    (if (> left (/ MAX_UINT right))
      none
      (some (* left right))))
)

;; Fee arithmetic carries the numerator remainder, rather than rounding each
;; settlement independently:
;;   numerator = base * rate-bps + prior-remainder
;;   assessed = floor(numerator / 10,000)
;;   remainder = numerator mod 10,000
;; The remainder is keyed by source/stream/asset in fee-accounting and is
;; retained through phase changes because every phase uses the same denominator.
(define-private (calculate-fee-at-rate
    (eligible-fee-base uint)
    (rate-bps uint)
    (fee-remainder uint))
  (if (>= fee-remainder BPS_DENOMINATOR)
    none
    (let ((product-opt (safe-multiply eligible-fee-base rate-bps)))
      (if (is-none product-opt)
        none
        (let ((numerator-opt (safe-add
            (default-to u0 product-opt)
            fee-remainder)))
          (if (is-none numerator-opt)
            none
            (let ((numerator (default-to u0 numerator-opt)))
              (some {
                assessed-amount: (/ numerator BPS_DENOMINATOR),
                fee-remainder: (mod numerator BPS_DENOMINATOR)
              }))
          )
        )
      )
    )
  )
)

(define-private (empty-accounting)
  {
    eligible-base: u0,
    assessed-fees: u0,
    settled-fees: u0,
    settlement-count: u0,
    fee-remainder: u0,
    last-rate-bps: u0,
    last-phase: u0,
    last-settled-burn-height: u0,
    last-settled-stacks-height: u0
  }
)

(define-private (empty-asset-accounting)
  {
    collected-fees: u0,
    routed-fees: u0,
    route-count: u0
  }
)

(define-private (empty-excess-recovery)
  {
    recovered-excess: u0
  }
)

;; --- Schedule resolution ---

;; Boundaries are exact and half-open:
;; [activation, activation + 52,560) = 200 bps
;; [activation + 52,560, activation + 157,680) = 150 bps
;; [activation + 157,680, infinity) = 100 bps
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

;; Admin/configuration authorization deliberately distinguishes a direct EOA
;; from a contract-mediated call. An EOA admin is accepted only when
;; contract-caller = tx-sender = admin. A configured admin contract is accepted
;; only as the immediate contract-caller.
(define-private (is-admin-authorized)
  (or
    (and
      (is-eq contract-caller tx-sender)
      (is-eq tx-sender (var-get admin)))
    (is-eq contract-caller (var-get admin))
  )
)

;; Governance/emergency authority is intentionally contract-only. A configured
;; wallet cannot act as production governance merely by matching tx-sender;
;; deployments must configure an approved DAO or timelock contract here.
(define-private (is-governance-authorized)
  (and
    (not (is-eq contract-caller tx-sender))
    (is-eq contract-caller (var-get governance))
  )
)

(define-private (is-admin-or-governance)
  (or (is-admin-authorized) (is-governance-authorized))
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
      stream-id: stream-id
    }))
  )
    (begin
      (asserts! source-authorized ERR_SOURCE_NOT_AUTHORIZED)
      (let ((config (unwrap! config-opt ERR_STREAM_NOT_FOUND)))
        (begin
          (asserts! (is-eq (get asset-kind config) asset-kind) ERR_INVALID_CONFIG)
          (asserts! (is-eq (get asset config) asset) ERR_INVALID_CONFIG)
          (asserts! (get active config) ERR_STREAM_INACTIVE)
          (asserts! (is-eq (get route config) ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)
          (ok config)
        )
      )
    )
  )
)

;; --- Admin controls ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-governance (new-governance principal))
  (begin
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
    (var-set governance new-governance)
    (ok true)
  )
)

(define-public (set-authorized-source (source principal) (authorized bool))
  (begin
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
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
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? authorized-sources source)) ERR_SOURCE_NOT_AUTHORIZED)
    (asserts! (> stream-id u0) ERR_INVALID_CONFIG)
    (asserts! (is-eq route ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)
    (asserts!
      (is-none (map-get? stream-configs { source: source, stream-id: stream-id }))
      ERR_STREAM_ALREADY_REGISTERED)
    ;; The registered token must implement SIP-010 when settle-ft supplies the
    ;; trait argument. The collector never pretends to support arbitrary token
    ;; behavior or a downstream burn operation.
    (map-set stream-configs {
      source: source,
      stream-id: stream-id
    } {
      asset-kind: ASSET_KIND_FT,
      asset: (some token),
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
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? authorized-sources source)) ERR_SOURCE_NOT_AUTHORIZED)
    (asserts! (> stream-id u0) ERR_INVALID_CONFIG)
    (asserts! (is-eq route ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)
    (asserts!
      (is-none (map-get? stream-configs { source: source, stream-id: stream-id }))
      ERR_STREAM_ALREADY_REGISTERED)
    (map-set stream-configs {
      source: source,
      stream-id: stream-id
    } {
      asset-kind: ASSET_KIND_STX,
      asset: none,
      active: true,
      route: route
    })
    (ok true)
  )
)

;; Activation and route/asset identity are intentionally separate controls:
;; this setter can pause a stream, but it cannot replace its asset or route.
(define-public (set-stream-active
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal))
    (active bool))
  (let (
    (key {
      source: source,
      stream-id: stream-id
    })
  )
    (begin
      (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
      (asserts! (or (is-eq asset-kind ASSET_KIND_FT) (is-eq asset-kind ASSET_KIND_STX)) ERR_INVALID_ASSET_KIND)
      (asserts!
        (or
          (and (is-eq asset-kind ASSET_KIND_FT) (is-some asset))
          (and (is-eq asset-kind ASSET_KIND_STX) (is-none asset)))
        ERR_INVALID_CONFIG)
      (let ((config (unwrap! (map-get? stream-configs key) ERR_STREAM_NOT_FOUND)))
        (begin
          (asserts! (is-eq (get asset-kind config) asset-kind) ERR_INVALID_CONFIG)
          (asserts! (is-eq (get asset config) asset) ERR_INVALID_CONFIG)
          (map-set stream-configs key (merge config { active: active }))
          (ok active)
        )
      )
    )
  )
)

(define-public (pause)
  (begin
    (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

(define-public (set-activation-burn-height (new-height uint))
  (begin
    (asserts! (is-admin-authorized) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get total-settlements) u0) ERR_ACTIVATION_LOCKED)
    (asserts! (>= new-height burn-block-height) ERR_INVALID_ACTIVATION)
    (asserts! (is-some (safe-add new-height MATURE_PHASE_BLOCKS)) ERR_INVALID_ACTIVATION)
    (var-set activation-burn-height new-height)
    (ok new-height)
  )
)

;; --- Source preview ---

;; The preview is intentionally read-only and uses the same stream lookup,
;; schedule resolution, and residual arithmetic as settlement. A source uses
;; it immediately before creating its transaction-local pending debit record;
;; the settlement entrypoint recomputes the values and never trusts a
;; caller-supplied fee amount.
(define-private (build-settlement-preview
    (source principal)
    (stream-id uint)
    (asset-kind uint)
    (asset (optional principal))
    (eligible-fee-base uint))
  (let (
    (config (try! (load-stream-config source stream-id asset-kind asset)))
    (phase (try! (resolve-phase-at burn-block-height)))
    (accounting-key {
      source: source,
      stream-id: stream-id,
      asset-kind: asset-kind,
      asset: asset
    })
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (fee-calculation (unwrap! (calculate-fee-at-rate
      eligible-fee-base
      (get rate-bps phase)
      (get fee-remainder old-accounting)) ERR_ARITHMETIC_OVERFLOW))
  )
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> eligible-fee-base u0) ERR_INVALID_AMOUNT)
      (asserts! (is-eq (get route config) ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)
      (ok {
        source: source,
        stream-id: stream-id,
        asset-kind: asset-kind,
        asset: asset,
        eligible-fee-base: eligible-fee-base,
        rate-bps: (get rate-bps phase),
        phase: (get phase phase),
        assessed-amount: (get assessed-amount fee-calculation),
        fee-remainder: (get fee-remainder fee-calculation)
      })
    )
  )
)

(define-read-only (preview-source-stx
    (source principal)
    (stream-id uint)
    (eligible-fee-base uint))
  (build-settlement-preview
    source
    stream-id
    ASSET_KIND_STX
    none
    eligible-fee-base)
)

(define-read-only (preview-source-ft
    (source principal)
    (stream-id uint)
    (asset principal)
    (eligible-fee-base uint))
  (build-settlement-preview
    source
    stream-id
    ASSET_KIND_FT
    (some asset)
    eligible-fee-base)
)

;; --- Settlement ---

;; FT settlement transfers payer -> this collector's own principal. There is no
;; downstream contract call. All state writes and the event occur only after
;; that transfer succeeds; a failed transfer rolls the transaction back.
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
    (recipient COLLECTOR_INGRESS)
    (accounting-key {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (asset-key {
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (settlement-key {
      source: source,
      settlement-id: settlement-id
    })
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
    (fee-calculation (unwrap! (calculate-fee-at-rate
      eligible-fee-base
      (get rate-bps phase)
      (get fee-remainder old-accounting)) ERR_ARITHMETIC_OVERFLOW))
    (assessed-amount (get assessed-amount fee-calculation))
    (new-remainder (get fee-remainder fee-calculation))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-collected-fees (unwrap! (safe-add (get collected-fees old-asset-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> eligible-fee-base u0) ERR_INVALID_AMOUNT)
      (asserts! (is-none (map-get? settlements settlement-key)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq (get route config) ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)

      ;; A positive base can legitimately produce a zero assessed fee while
      ;; the residual is accumulated. Record that auditable settlement without
      ;; issuing an invalid zero-value transfer.
      (if (> assessed-amount u0)
        (begin
          (try! (contract-call? token transfer assessed-amount tx-sender COLLECTOR_INGRESS none))
          true)
        true)

      (map-set settlements settlement-key {
        settlement-id: settlement-id,
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
        recipient: recipient,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        fee-remainder: new-remainder,
        last-rate-bps: (get rate-bps phase),
        last-phase: (get phase phase),
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (map-set asset-accounting asset-key {
        collected-fees: new-collected-fees,
        routed-fees: (get routed-fees old-asset-accounting),
        route-count: (get route-count old-asset-accounting)
      })
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-collected",
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
        recipient: recipient,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok assessed-amount)
    )
  )
)

;; Native STX follows the same accounting and event shape, with a native
;; transfer from tx-sender to this collector's own principal.
(define-public (settle-stx
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (let (
    (source contract-caller)
    (asset none)
    (config (try! (load-stream-config source stream-id ASSET_KIND_STX asset)))
    (phase (try! (resolve-phase-at burn-block-height)))
    (recipient COLLECTOR_INGRESS)
    (accounting-key {
      source: source,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })
    (settlement-key {
      source: source,
      settlement-id: settlement-id
    })
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting {
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })))
    (fee-calculation (unwrap! (calculate-fee-at-rate
      eligible-fee-base
      (get rate-bps phase)
      (get fee-remainder old-accounting)) ERR_ARITHMETIC_OVERFLOW))
    (assessed-amount (get assessed-amount fee-calculation))
    (new-remainder (get fee-remainder fee-calculation))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-collected-fees (unwrap! (safe-add (get collected-fees old-asset-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-total-collected-stx (unwrap! (safe-add (var-get total-collected-stx) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> eligible-fee-base u0) ERR_INVALID_AMOUNT)
      (asserts! (is-none (map-get? settlements settlement-key)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq (get route config) ROUTE_PROTOCOL_INGRESS) ERR_INVALID_ROUTE)

      ;; A positive base can produce a zero assessed fee; retain its residual
      ;; and audit record without attempting a zero STX transfer.
      (if (> assessed-amount u0)
        (begin
          (try! (stx-transfer? assessed-amount tx-sender COLLECTOR_INGRESS))
          true)
        true)

      (map-set settlements settlement-key {
        settlement-id: settlement-id,
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
        recipient: recipient,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        fee-remainder: new-remainder,
        last-rate-bps: (get rate-bps phase),
        last-phase: (get phase phase),
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (map-set asset-accounting {
        asset-kind: ASSET_KIND_STX,
        asset: asset
      } {
        collected-fees: new-collected-fees,
        routed-fees: (get routed-fees old-asset-accounting),
        route-count: (get route-count old-asset-accounting)
      })
      (var-set total-collected-stx new-total-collected-stx)
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-collected",
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
        recipient: recipient,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok assessed-amount)
    )
  )
)

;; Source-custody FT settlement. The source must implement the focused callback
;; trait and must be the immediate contract caller. The callback receives only
;; the collector-computed debit and the fixed collector recipient. Exact live
;; balance delta around that callback proves custody while retaining any
;; untracked collector excess. A zero assessed amount still invokes the
;; authenticated no-op callback so the source can consume its transaction-local
;; pending record; no zero-value token transfer is attempted by the source.
(define-public (settle-source-ft
    (source <protocol-fee-source-trait>)
    (token <sip-010-ft-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (let (
    (source-principal (contract-of source))
    (asset (some (contract-of token)))
    (accounting-key {
      source: source-principal,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (asset-key {
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (settlement-key {
      source: source-principal,
      settlement-id: settlement-id
    })
    (preview (try! (build-settlement-preview
      source-principal
      stream-id
      ASSET_KIND_FT
      asset
      eligible-fee-base)))
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
    (assessed-amount (get assessed-amount preview))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-collected-fees (unwrap! (safe-add (get collected-fees old-asset-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (before-balance (unwrap! (contract-call? token get-balance COLLECTOR_INGRESS) ERR_ASSET_BALANCE_READ_FAILED))
    (after-balance (begin
      (asserts! (is-eq contract-caller source-principal) ERR_SOURCE_CALLBACK_UNAUTHORIZED)
      (try! (contract-call? source prepay-ft-fee token assessed-amount COLLECTOR_INGRESS))
      (unwrap! (contract-call? token get-balance COLLECTOR_INGRESS) ERR_ASSET_BALANCE_READ_FAILED)))
    (settled-amount (unwrap! (safe-sub after-balance before-balance) ERR_SOURCE_CUSTODY_DELTA_MISMATCH))
  )
    (begin
      (asserts! (is-none (map-get? settlements settlement-key)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq settled-amount assessed-amount) ERR_SOURCE_CUSTODY_DELTA_MISMATCH)

      (map-set settlements settlement-key {
        settlement-id: settlement-id,
        source: source-principal,
        stream-id: stream-id,
        asset-kind: ASSET_KIND_FT,
        asset: asset,
        payer: tx-sender,
        eligible-base: eligible-fee-base,
        rate-bps: (get rate-bps preview),
        phase: (get phase preview),
        assessed-amount: assessed-amount,
        settled-amount: settled-amount,
        recipient: COLLECTOR_INGRESS,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        fee-remainder: (get fee-remainder preview),
        last-rate-bps: (get rate-bps preview),
        last-phase: (get phase preview),
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (map-set asset-accounting asset-key {
        collected-fees: new-collected-fees,
        routed-fees: (get routed-fees old-asset-accounting),
        route-count: (get route-count old-asset-accounting)
      })
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-collected",
        settlement-id: settlement-id,
        source: source-principal,
        stream-id: stream-id,
        payer: tx-sender,
        asset-kind: ASSET_KIND_FT,
        asset: asset,
        eligible-fee-base: eligible-fee-base,
        rate-bps: (get rate-bps preview),
        phase: (get phase preview),
        assessed-amount: assessed-amount,
        settled-amount: settled-amount,
        recipient: COLLECTOR_INGRESS,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok settled-amount)
    )
  )
)

;; Source-custody STX settlement. This mirrors settle-source-ft while keeping
;; native STX balance proof and custody accounting in the STX namespace.
(define-public (settle-source-stx
    (source <protocol-fee-source-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (let (
    (source-principal (contract-of source))
    (asset none)
    (accounting-key {
      source: source-principal,
      stream-id: stream-id,
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })
    (asset-key {
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })
    (settlement-key {
      source: source-principal,
      settlement-id: settlement-id
    })
    (preview (try! (build-settlement-preview
      source-principal
      stream-id
      ASSET_KIND_STX
      asset
      eligible-fee-base)))
    (old-accounting (default-to (empty-accounting) (map-get? fee-accounting accounting-key)))
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
    (assessed-amount (get assessed-amount preview))
    (new-eligible-base (unwrap! (safe-add (get eligible-base old-accounting) eligible-fee-base) ERR_ACCOUNTING_OVERFLOW))
    (new-assessed-fees (unwrap! (safe-add (get assessed-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settled-fees (unwrap! (safe-add (get settled-fees old-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-settlement-count (unwrap! (safe-add (get settlement-count old-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-settlements (unwrap! (safe-add (var-get total-settlements) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-collected-fees (unwrap! (safe-add (get collected-fees old-asset-accounting) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (new-total-collected-stx (unwrap! (safe-add (var-get total-collected-stx) assessed-amount) ERR_ACCOUNTING_OVERFLOW))
    (before-balance (stx-get-balance COLLECTOR_INGRESS))
    (after-balance (begin
      (asserts! (is-eq contract-caller source-principal) ERR_SOURCE_CALLBACK_UNAUTHORIZED)
      (try! (contract-call? source prepay-stx-fee assessed-amount COLLECTOR_INGRESS))
      (stx-get-balance COLLECTOR_INGRESS)))
    (settled-amount (unwrap! (safe-sub after-balance before-balance) ERR_SOURCE_CUSTODY_DELTA_MISMATCH))
  )
    (begin
      (asserts! (is-none (map-get? settlements settlement-key)) ERR_SETTLEMENT_REPLAYED)
      (asserts! (is-eq settled-amount assessed-amount) ERR_SOURCE_CUSTODY_DELTA_MISMATCH)

      (map-set settlements settlement-key {
        settlement-id: settlement-id,
        source: source-principal,
        stream-id: stream-id,
        asset-kind: ASSET_KIND_STX,
        asset: asset,
        payer: tx-sender,
        eligible-base: eligible-fee-base,
        rate-bps: (get rate-bps preview),
        phase: (get phase preview),
        assessed-amount: assessed-amount,
        settled-amount: settled-amount,
        recipient: COLLECTOR_INGRESS,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (map-set fee-accounting accounting-key {
        eligible-base: new-eligible-base,
        assessed-fees: new-assessed-fees,
        settled-fees: new-settled-fees,
        settlement-count: new-settlement-count,
        fee-remainder: (get fee-remainder preview),
        last-rate-bps: (get rate-bps preview),
        last-phase: (get phase preview),
        last-settled-burn-height: burn-block-height,
        last-settled-stacks-height: block-height
      })
      (map-set asset-accounting asset-key {
        collected-fees: new-collected-fees,
        routed-fees: (get routed-fees old-asset-accounting),
        route-count: (get route-count old-asset-accounting)
      })
      (var-set total-collected-stx new-total-collected-stx)
      (var-set total-settlements new-total-settlements)
      (print {
        event: "protocol-fee-collected",
        settlement-id: settlement-id,
        source: source-principal,
        stream-id: stream-id,
        payer: tx-sender,
        asset-kind: ASSET_KIND_STX,
        asset: asset,
        eligible-fee-base: eligible-fee-base,
        rate-bps: (get rate-bps preview),
        phase: (get phase preview),
        assessed-amount: assessed-amount,
        settled-amount: settled-amount,
        recipient: COLLECTOR_INGRESS,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok settled-amount)
    )
  )
)

;; --- Explicit custody routes ---

;; Route collector-held FT custody only to the immutable operational treasury.
;; `as-contract` makes the collector the SIP-010 `from` principal. The transfer
;; is attempted before route accounting/event writes, so any failure rolls the
;; entire route back.
(define-public (route-ft (token <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (some (contract-of token)))
    (asset-key {
      asset-kind: ASSET_KIND_FT,
      asset: asset
    })
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
    (new-routed-fees (unwrap! (safe-add (get routed-fees old-asset-accounting) amount) ERR_ACCOUNTING_OVERFLOW))
    (new-route-count (unwrap! (safe-add (get route-count old-asset-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-routes (unwrap! (safe-add (var-get total-routes) u1) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (contract-call? .operational-treasury is-initialized) ERR_TREASURY_NOT_INITIALIZED)
      (asserts! (<= (get routed-fees old-asset-accounting) (get collected-fees old-asset-accounting)) ERR_INVALID_ROUTE)
      (asserts!
        (<= amount (- (get collected-fees old-asset-accounting) (get routed-fees old-asset-accounting)))
        ERR_ROUTE_EXCEEDS_COLLECTED)
      (try! (as-contract (contract-call? token transfer amount tx-sender OPERATIONAL_TREASURY none)))
      (map-set asset-accounting asset-key {
        collected-fees: (get collected-fees old-asset-accounting),
        routed-fees: new-routed-fees,
        route-count: new-route-count
      })
      (var-set total-routes new-total-routes)
      (print {
        event: "protocol-fee-routed-to-operational-treasury",
        asset-kind: ASSET_KIND_FT,
        asset: asset,
        amount: amount,
        collector: COLLECTOR_INGRESS,
        destination: OPERATIONAL_TREASURY,
        collected-total: (get collected-fees old-asset-accounting),
        routed-total: new-routed-fees,
        route-count: new-route-count,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok amount)
    )
  )
)

;; Route collector-held STX custody only to the immutable operational treasury.
;; Routing remains available while settlement is paused so emergency custody
;; forwarding cannot be blocked by the settlement switch.
(define-public (route-stx (amount uint))
  (let (
    (asset none)
    (asset-key {
      asset-kind: ASSET_KIND_STX,
      asset: asset
    })
    (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
    (new-routed-fees (unwrap! (safe-add (get routed-fees old-asset-accounting) amount) ERR_ACCOUNTING_OVERFLOW))
    (new-route-count (unwrap! (safe-add (get route-count old-asset-accounting) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-routes (unwrap! (safe-add (var-get total-routes) u1) ERR_ACCOUNTING_OVERFLOW))
    (new-total-routed-stx (unwrap! (safe-add (var-get total-routed-stx) amount) ERR_ACCOUNTING_OVERFLOW))
  )
    (begin
      (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (contract-call? .operational-treasury is-initialized) ERR_TREASURY_NOT_INITIALIZED)
      (asserts! (<= (get routed-fees old-asset-accounting) (get collected-fees old-asset-accounting)) ERR_INVALID_ROUTE)
      (asserts!
        (<= amount (- (get collected-fees old-asset-accounting) (get routed-fees old-asset-accounting)))
        ERR_ROUTE_EXCEEDS_COLLECTED)
      (try! (as-contract (stx-transfer? amount tx-sender OPERATIONAL_TREASURY)))
      (map-set asset-accounting asset-key {
        collected-fees: (get collected-fees old-asset-accounting),
        routed-fees: new-routed-fees,
        route-count: new-route-count
      })
      (var-set total-routed-stx new-total-routed-stx)
      (var-set total-routes new-total-routes)
      (print {
        event: "protocol-fee-routed-to-operational-treasury",
        asset-kind: ASSET_KIND_STX,
        asset: asset,
        amount: amount,
        collector: COLLECTOR_INGRESS,
        destination: OPERATIONAL_TREASURY,
        collected-total: (get collected-fees old-asset-accounting),
        routed-total: new-routed-fees,
        route-count: new-route-count,
        burn-height: burn-block-height,
        stacks-height: block-height
      })
      (ok amount)
    )
  )
)

;; Recover only direct STX deposits that are above the collector's tracked,
;; collected-but-not-yet-routed custody. The destination is immutable and the
;; operation never changes normal collection or route counters.
(define-public (recover-excess-stx (amount uint))
  (begin
    (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (contract-call? .operational-treasury is-initialized) ERR_TREASURY_NOT_INITIALIZED)
    (let (
      (asset none)
      (asset-key {
        asset-kind: ASSET_KIND_STX,
        asset: asset
      })
      (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
      (old-recovery (default-to (empty-excess-recovery) (map-get? excess-recovery-accounting asset-key)))
      (tracked-outstanding (unwrap! (safe-sub
        (get collected-fees old-asset-accounting)
        (get routed-fees old-asset-accounting)) ERR_CUSTODY_ACCOUNTING_INCONSISTENT))
      (actual-balance (stx-get-balance COLLECTOR_INGRESS))
      (excess-before-recovery (unwrap! (safe-sub actual-balance tracked-outstanding) ERR_CUSTODY_BALANCE_SHORTFALL))
      (new-recovered-excess (unwrap! (safe-add
        (get recovered-excess old-recovery)
        amount) ERR_ACCOUNTING_OVERFLOW))
      (new-total-recovered-excess (unwrap! (safe-add
        (var-get total-recovered-excess-stx)
        amount) ERR_ACCOUNTING_OVERFLOW))
    )
      (begin
        (asserts! (<= amount excess-before-recovery) ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE)
        (try! (as-contract (stx-transfer? amount tx-sender OPERATIONAL_TREASURY)))
        (map-set excess-recovery-accounting asset-key {
          recovered-excess: new-recovered-excess
        })
        (var-set total-recovered-excess-stx new-total-recovered-excess)
        (print {
          event: "protocol-fee-excess-recovered",
          asset-kind: ASSET_KIND_STX,
          asset: asset,
          amount: amount,
          collector: COLLECTOR_INGRESS,
          destination: OPERATIONAL_TREASURY,
          actual-balance: actual-balance,
          tracked-outstanding-custody: tracked-outstanding,
          excess-before-recovery: excess-before-recovery,
          recovered-total: new-recovered-excess,
          burn-height: burn-block-height,
          stacks-height: block-height
        })
        (ok amount)
      )
    )
  )
)

;; Recover only direct FT deposits above the tracked collected-but-not-yet-routed
;; custody for this token. The token transfer is attempted before recovery
;; accounting/event writes so a failed transfer rolls the entire operation back.
(define-public (recover-excess-ft (token <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (is-admin-or-governance) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (contract-call? .operational-treasury is-initialized) ERR_TREASURY_NOT_INITIALIZED)
    (let (
      (asset (some (contract-of token)))
      (asset-key {
        asset-kind: ASSET_KIND_FT,
        asset: asset
      })
      (old-asset-accounting (default-to (empty-asset-accounting) (map-get? asset-accounting asset-key)))
      (old-recovery (default-to (empty-excess-recovery) (map-get? excess-recovery-accounting asset-key)))
      (tracked-outstanding (unwrap! (safe-sub
        (get collected-fees old-asset-accounting)
        (get routed-fees old-asset-accounting)) ERR_CUSTODY_ACCOUNTING_INCONSISTENT))
      (actual-balance (unwrap! (contract-call? token get-balance COLLECTOR_INGRESS) ERR_ASSET_BALANCE_READ_FAILED))
      (excess-before-recovery (unwrap! (safe-sub actual-balance tracked-outstanding) ERR_CUSTODY_BALANCE_SHORTFALL))
      (new-recovered-excess (unwrap! (safe-add
        (get recovered-excess old-recovery)
        amount) ERR_ACCOUNTING_OVERFLOW))
    )
      (begin
        (asserts! (<= amount excess-before-recovery) ERR_EXCESS_RECOVERY_EXCEEDS_AVAILABLE)
        (try! (as-contract (contract-call? token transfer amount tx-sender OPERATIONAL_TREASURY none)))
        (map-set excess-recovery-accounting asset-key {
          recovered-excess: new-recovered-excess
        })
        (print {
          event: "protocol-fee-excess-recovered",
          asset-kind: ASSET_KIND_FT,
          asset: asset,
          amount: amount,
          collector: COLLECTOR_INGRESS,
          destination: OPERATIONAL_TREASURY,
          actual-balance: actual-balance,
          tracked-outstanding-custody: tracked-outstanding,
          excess-before-recovery: excess-before-recovery,
          recovered-total: new-recovered-excess,
          burn-height: burn-block-height,
          stacks-height: block-height
        })
        (ok amount)
      )
    )
  )
)

;; --- Read-only audit API ---

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-governance)
  (ok (var-get governance))
)

(define-read-only (get-collector-ingress)
  (ok COLLECTOR_INGRESS)
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
  (match (map-get? stream-configs { source: source, stream-id: stream-id })
    config
      (ok (if
        (and
          (is-eq (get asset-kind config) asset-kind)
          (is-eq (get asset config) asset))
        (some config)
        none))
    (ok none))
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

(define-read-only (get-settlement
    (source principal)
    (settlement-id (buff 32)))
  (ok (map-get? settlements {
    source: source,
    settlement-id: settlement-id
  }))
)

(define-read-only (get-total-settlements)
  (ok (var-get total-settlements))
)

(define-read-only (get-total-routes)
  (ok (var-get total-routes))
)

(define-read-only (get-total-collected-stx)
  (ok (var-get total-collected-stx))
)

(define-read-only (get-total-routed-stx)
  (ok (var-get total-routed-stx))
)

(define-read-only (get-asset-accounting
    (asset-kind uint)
    (asset (optional principal)))
  (ok (map-get? asset-accounting {
    asset-kind: asset-kind,
    asset: asset
  }))
)

(define-read-only (get-collected-ft (token principal))
  (match (map-get? asset-accounting {
      asset-kind: ASSET_KIND_FT,
      asset: (some token)
    })
    accounting (ok (get collected-fees accounting))
    (ok u0)
  )
)

(define-read-only (get-routed-ft (token principal))
  (match (map-get? asset-accounting {
      asset-kind: ASSET_KIND_FT,
      asset: (some token)
    })
    accounting (ok (get routed-fees accounting))
    (ok u0)
  )
)

(define-read-only (get-excess-recovery-accounting
    (asset-kind uint)
    (asset (optional principal)))
  (ok (map-get? excess-recovery-accounting {
    asset-kind: asset-kind,
    asset: asset
  }))
)

(define-read-only (get-excess-recovered-stx)
  (match (map-get? excess-recovery-accounting {
      asset-kind: ASSET_KIND_STX,
      asset: none
    })
    accounting (ok (get recovered-excess accounting))
    (ok u0)
  )
)

(define-read-only (get-excess-recovered-ft (token principal))
  (match (map-get? excess-recovery-accounting {
      asset-kind: ASSET_KIND_FT,
      asset: (some token)
    })
    accounting (ok (get recovered-excess accounting))
    (ok u0)
  )
)

(define-read-only (get-total-recovered-excess-stx)
  (ok (var-get total-recovered-excess-stx))
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
      burn-blocks-per-year: BURN_BLOCKS_PER_YEAR,
      growth-phase-years: GROWTH_PHASE_YEARS,
      mature-phase-years: MATURE_PHASE_YEARS
    })
  )
)

(define-read-only (get-rate-at-burn-height (height uint))
  (resolve-phase-at height)
)

(define-read-only (get-current-rate)
  (resolve-phase-at burn-block-height)
)

;; This read-only calculation starts with zero residual. Settlement calls use
;; the source/stream/asset residual from fee-accounting instead.
(define-read-only (calculate-fee-at
    (eligible-fee-base uint)
    (height uint))
  (let (
    (phase (try! (resolve-phase-at height)))
    (fee-calculation (unwrap! (calculate-fee-at-rate
      eligible-fee-base
      (get rate-bps phase)
      u0) ERR_ARITHMETIC_OVERFLOW))
  )
    (ok (get assessed-amount fee-calculation))
  )
)

(define-read-only (calculate-current-fee (eligible-fee-base uint))
  (calculate-fee-at eligible-fee-base burn-block-height)
)
