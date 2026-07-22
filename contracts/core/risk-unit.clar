;; risk-unit.clar
;; Canonical risk-management unit for the Conxian Protocol.
;; The legacy risk-manager contract is a compatibility facade only.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

;; --- Errors ---

(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_INVALID_POSITION (err u1001))
(define-constant ERR_HEALTHY_POSITION (err u1002))
(define-constant ERR_CACHE_MISS (err u1003))
(define-constant ERR_CACHE_STALE (err u1004))
(define-constant ERR_INVALID_RISK_SCORE (err u1005))
(define-constant ERR_NOT_INITIALIZED (err u1006))

;; --- Risk units and freshness policy ---

;; Health factors are expressed in basis points: u10000 = 1.0x.
(define-constant LIQUIDATION_THRESHOLD u10000)
(define-constant EMERGENCY_THRESHOLD u11000)

;; System risk is explicitly bounded to 0..10000. Higher values are riskier.
(define-constant SYSTEM_RISK_LIMIT u5000)
(define-constant MAX_SYSTEM_RISK_SCORE u10000)

;; A cache remains decision-grade for six burn blocks. A stale cache is still
;; observable, but cannot be used by read-only liquidation decisions.
(define-constant CACHE_MAX_AGE u6)

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-data-var dimensional-engine (optional principal) none)
(define-data-var ops-engine-contract (optional principal) none)
(define-data-var system-risk-score uint u0)
(define-data-var risk-agent (optional principal) none)
(define-data-var initialized bool false)

;; Efficient O(1) position-health cache. last-update is a burn-block height.
(define-map position-health
  uint
  {
    health-factor: uint,
    last-update: uint
  }
)

;; --- Authorization ---

(define-private (is-authorized-admin)
  (or
    (is-eq tx-sender (var-get contract-owner))
    (is-eq (contract-call? .conxian-access has-role tx-sender u1) (ok true))
  )
)

(define-private (is-configured-principal (candidate principal) (configured (optional principal)))
  (match configured
    configured-principal (is-eq candidate configured-principal)
    false
  )
)

(define-private (is-authorized-liquidator)
  (or
    ;; The canonical dimensional facade is an execution caller, not a role.
    (is-configured-principal contract-caller (var-get dimensional-engine))
    (is-configured-principal contract-caller (var-get risk-agent))
    (is-configured-principal contract-caller (var-get ops-engine-contract))
    (is-authorized-admin)
  )
)

(define-private (is-cache-fresh (last-update uint))
  (if (>= burn-block-height last-update)
    (<= (- burn-block-height last-update) CACHE_MAX_AGE)
    false
  )
)

(define-private (get-current-liquidation-threshold)
  (if (>= (var-get system-risk-score) SYSTEM_RISK_LIMIT)
    EMERGENCY_THRESHOLD
    LIQUIDATION_THRESHOLD
  )
)

;; --- Pure health math ---

;; Returns the canonical health factor. Zero debt is represented by the
;; bounded sentinel u100000. Exact threshold values remain healthy because
;; liquidation decisions use a strict less-than comparison.
(define-read-only (calculate-health-factor (collateral-value uint) (total-debt uint))
  (if (is-eq total-debt u0)
    u100000
    (/ (* collateral-value u10000) total-debt)
  )
)

;; --- Internal position/cache helpers ---

(define-private (refresh-position-health (position-id uint))
  (let (
    (owner (unwrap! (unwrap! (contract-call? .position-nft get-owner position-id) ERR_INVALID_POSITION) ERR_INVALID_POSITION))
    (position (unwrap! (contract-call? .dimensional-core get-position owner position-id) ERR_INVALID_POSITION))
    (collateral-value (get collateral position))
    (maintenance-margin (get maintenance-margin position))
    (health-factor (calculate-health-factor collateral-value maintenance-margin))
  )
    (begin
      (map-set position-health position-id {
        health-factor: health-factor,
        last-update: burn-block-height
      })
      (ok health-factor)
    )
  )
)

(define-private (get-fresh-health-factor (position-id uint))
  (match (map-get? position-health position-id)
    data (if (is-cache-fresh (get last-update data))
      (ok (get health-factor data))
      ERR_CACHE_STALE
    )
    ERR_CACHE_MISS
  )
)

;; --- Risk score publication and observability ---

;; Only the configured agent contract or an admin may publish a score. The
;; configured agent is intentionally checked through contract-caller; tx-sender
;; alone must not authorize arbitrary callers.
(define-public (update-system-risk (new-score uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (or
      (is-configured-principal contract-caller (var-get risk-agent))
      (is-authorized-admin)
    ) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-score MAX_SYSTEM_RISK_SCORE) ERR_INVALID_RISK_SCORE)
    (let ((previous-score (var-get system-risk-score)))
      (begin
        (var-set system-risk-score new-score)
        (print {
          event: "risk-score-updated",
          previous-score: previous-score,
          new-score: new-score,
          publisher: contract-caller,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-read-only (get-system-risk-score)
  (ok (var-get system-risk-score))
)

(define-read-only (get-risk-config)
  (ok {
    initialized: (var-get initialized),
    contract-owner: (var-get contract-owner),
    dimensional-engine: (var-get dimensional-engine),
    ops-engine: (var-get ops-engine-contract),
    risk-agent: (var-get risk-agent),
    system-risk-score: (var-get system-risk-score),
    active-liquidation-threshold: (get-current-liquidation-threshold),
    liquidation-threshold: LIQUIDATION_THRESHOLD,
    emergency-threshold: EMERGENCY_THRESHOLD,
    system-risk-limit: SYSTEM_RISK_LIMIT,
    max-system-risk-score: MAX_SYSTEM_RISK_SCORE,
    cache-max-age: CACHE_MAX_AGE
  })
)

;; Returns cached data even when stale so operators can distinguish stale from
;; absent state. Decision functions below reject stale entries.
(define-read-only (get-position-health (position-id uint))
  (match (map-get? position-health position-id)
    data (ok {
      health-factor: (get health-factor data),
      last-update: (get last-update data),
      fresh: (is-cache-fresh (get last-update data))
    })
    ERR_CACHE_MISS
  )
)

;; --- Position health and liquidation ---

(define-public (get-health-factor (position-id uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (refresh-position-health position-id)
  )
)

(define-read-only (get-health-factor-read-only (position-id uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (get-fresh-health-factor position-id)
  )
)

;; Authorization deliberately precedes refresh-position-health. An
;; unauthorized liquidation attempt therefore cannot refresh or otherwise
;; mutate the cache.
(define-public (liquidate (position-id uint))
  (begin
    (asserts! (is-authorized-liquidator) ERR_NOT_AUTHORIZED)
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (let (
      (owner (unwrap! (unwrap! (contract-call? .position-nft get-owner position-id) ERR_INVALID_POSITION) ERR_INVALID_POSITION))
      (health-factor (try! (refresh-position-health position-id)))
      (current-risk (var-get system-risk-score))
      (adjusted-threshold (get-current-liquidation-threshold))
    )
      (begin
        (asserts! (< health-factor adjusted-threshold) ERR_HEALTHY_POSITION)
        (try! (contract-call? .dimensional-core liquidate-position owner position-id .oracle-aggregator))
        (map-delete position-health position-id)
        (print {
          event: "risk-triggered-liquidation",
          position-id: position-id,
          health-factor: health-factor,
          system-risk: current-risk,
          threshold: adjusted-threshold,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

;; Read-only decisions fail closed when cache state is absent or stale.
(define-read-only (is-liquidatable (position-id uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (let (
      (health-factor (try! (get-fresh-health-factor position-id)))
      (threshold (get-current-liquidation-threshold))
    )
      (ok (< health-factor threshold))
    )
  )
)

;; --- Initialization and wiring ---

;; The deploying principal is the bootstrap trust anchor until conxian-access
;; has an initialized ROLE_ADMIN. The caller must already be that trust anchor;
;; the supplied owner is configuration, not authorization.
(define-public (initialize (owner principal) (agent principal) (engine principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_NOT_AUTHORIZED)
    (asserts! (or
      (is-eq tx-sender (var-get contract-owner))
      (is-eq (contract-call? .conxian-access has-role tx-sender u1) (ok true))
    ) ERR_NOT_AUTHORIZED)
    (var-set contract-owner owner)
    (var-set risk-agent (some agent))
    (var-set dimensional-engine (some engine))
    (var-set initialized true)
    (print {
      event: "risk-unit-initialized",
      owner: owner,
      agent: agent,
      dimensional-engine: engine
    })
    (ok true)
  )
)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set dimensional-engine (some new-engine))
    (ok true)
  )
)

(define-public (set-risk-agent (new-agent principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set risk-agent (some new-agent))
    (ok true)
  )
)

(define-public (set-ops-engine (new-ops principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set ops-engine-contract (some new-ops))
    (ok true)
  )
)
