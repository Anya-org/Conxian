;; =============================================================================
;; DEX FACTORY V2 - Multi-pool type factory for Conxian
;; Matches interface expected by tests in tests/pool-integration.test.ts
;; =============================================================================

;; Error codes required by tests
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_POOL_ALREADY_EXISTS u6001)
(define-constant ERR_INVALID_POOL_TYPE u6002)
(define-constant ERR_INVALID_FEE_TIER u6003)
(define-constant ERR_INVALID_TOKENS u6004)
(define-constant ERR_INVALID_PARAMETERS u6005)

;; Max capacities
(define-constant MAX_SUPPORTED_TYPES u20)
(define-constant MAX_FEE_TIERS u10)
(define-constant MAX_POOLS_PER_PAIR u50)

;; -----------------------------------------------------------------------------
;; Factory global state
;; -----------------------------------------------------------------------------

(define-data-var admin principal tx-sender)
(define-data-var factory-enabled bool true)
(define-data-var protocol-fee-bps uint u0)
(define-data-var next-pool-id uint u1)
(define-data-var total-pools uint u0)
(define-data-var supported-types (list 20 (string-ascii 20)) (list))

;; -----------------------------------------------------------------------------
;; Registries and indices
;; -----------------------------------------------------------------------------

;; Pool type implementations and configuration
(define-map pool-implementations
  (string-ascii 20)
  {
    implementation: principal,
    enabled: bool,
    fee-tiers: (list 10 uint),
    min-liquidity: uint,
    max-positions: uint
  })

;; Pool metadata by id
(define-map pools-by-id
  uint
  {
    pool-address: principal,
    token-0: principal,
    token-1: principal,
    pool-type: (string-ascii 20),
    fee-tier: uint,
    implementation: principal,
    created-at: uint,
    creator: principal,
    params: (optional (tuple (weight-0 uint) (weight-1 uint) (amp uint)))
  })

;; Index to find pool by ordered pair + type + fee
(define-map pair-index
  {token-0: principal, token-1: principal, pool-type: (string-ascii 20), fee-tier: uint}
  principal)

;; For enumeration by pair (any type/fee)
(define-map pair-pools
  {token-0: principal, token-1: principal}
  (list 50 principal))

;; Pool statistics
(define-map pool-stats
  uint
  { total-volume-24h: uint, total-fees-24h: uint, liquidity-providers: uint })

;; -----------------------------------------------------------------------------
;; Helpers
;; -----------------------------------------------------------------------------

;; Deterministic principal ordering (uses < comparator on principals)
(define-private (order-tokens (a principal) (b principal))
  (if (is-eq a b)
      {token-0: a, token-1: b}
      (if (< a b) {token-0: a, token-1: b} {token-0: b, token-1: a})))

(define-private (contains-uint (xs (list 10 uint)) (x uint))
  (fold (lambda (item acc) (if (is-eq item x) true acc)) false xs))

;; Append a principal to pair list (bounded)
(define-private (append-pair-pool (t0 principal) (t1 principal) (pool principal))
  (let ((key {token-0: t0, token-1: t1})
        (current (default-to (list) (map-get? pair-pools {token-0: t0, token-1: t1}))))
    (if (< (len current) MAX_POOLS_PER_PAIR)
        (map-set pair-pools key (unwrap-panic (as-max-len? (append current pool) u50)))
        true)))

(define-private (is-type-enabled (pool-type (string-ascii 20)))
  (match (map-get? pool-implementations pool-type)
    cfg (get enabled cfg)
    false))

(define-private (get-impl-or-none (pool-type (string-ascii 20)))
  (map-get? pool-implementations pool-type))

(define-private (is-valid-fee-tier (pool-type (string-ascii 20)) (fee-tier uint))
  (match (map-get? pool-implementations pool-type)
    cfg (contains-uint (get fee-tiers cfg) fee-tier)
    false))

;; Parameter validation per type
(define-private (validate-params-internal (pool-type (string-ascii 20)) (params (optional (tuple (weight-0 uint) (weight-1 uint) (amp uint)))))
  (cond
    ;; weighted: require weights present and sum == 10000
    ((is-eq pool-type "weighted")
      (match params p
        (let ((w0 (get weight-0 p)) (w1 (get weight-1 p)))
          (ok (is-eq (+ w0 w1) u10000)))
        (err ERR_INVALID_PARAMETERS)))
    ;; stable: require amp present and 0 < amp <= 1000
    ((is-eq pool-type "stable")
      (match params p
        (let ((a (get amp p)))
          (ok (and (> a u0) (<= a u1000))))
        (err ERR_INVALID_PARAMETERS)))
    ;; default (constant-product, concentrated): allow no params
    (else (ok true))))

;; -----------------------------------------------------------------------------
;; Public/Read-only interface required by tests
;; -----------------------------------------------------------------------------

(define-public (initialize-factory)
  (begin
    ;; admin becomes caller
    (var-set admin tx-sender)
    (var-set factory-enabled true)
    (var-set protocol-fee-bps u0)
    (var-set total-pools u0)
    (var-set next-pool-id u1)

    ;; register default pool types
    (map-set pool-implementations "constant-product" {
      implementation: .dex-pool,
      enabled: true,
      fee-tiers: (list u50 u300 u1000 u3000 u5000),
      min-liquidity: u0,
      max-positions: u0
    })
    (map-set pool-implementations "concentrated" {
      implementation: .concentrated-liquidity-pool,
      enabled: true,
      fee-tiers: (list u50 u100 u300),
      min-liquidity: u0,
      max-positions: u0
    })
    (map-set pool-implementations "stable" {
      implementation: .stable-pool-enhanced,
      enabled: true,
      fee-tiers: (list u50 u300),
      min-liquidity: u0,
      max-positions: u0
    })
    (map-set pool-implementations "weighted" {
      implementation: .weighted-pool,
      enabled: true,
      fee-tiers: (list u300 u1000),
      min-liquidity: u0,
      max-positions: u0
    })

    ;; supported types list (for config)
    (var-set supported-types (list "constant-product" "concentrated" "stable" "weighted"))

    (ok true)))

;; Create a pool with typed params
(define-public (create-pool-typed
  (token-a principal)
  (token-b principal)
  (pool-type (string-ascii 20))
  (fee-tier uint)
  (optional-params (optional (tuple (weight-0 uint) (weight-1 uint) (amp uint)))))
  (begin
    (asserts! (var-get factory-enabled) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-eq token-a token-b)) (err ERR_INVALID_TOKENS))
    (asserts! (is-some (get-impl-or-none pool-type)) (err ERR_INVALID_POOL_TYPE))
    (asserts! (is-type-enabled pool-type) (err ERR_INVALID_POOL_TYPE))
    (asserts! (is-valid-fee-tier pool-type fee-tier) (err ERR_INVALID_FEE_TIER))

    ;; Validate parameters
    (match (validate-params-internal pool-type optional-params)
      (ok ok?) (asserts! ok? (err ERR_INVALID_PARAMETERS))
      e (err ERR_INVALID_PARAMETERS))

    (let ((ordered (order-tokens token-a token-b))
          (impl (get implementation (unwrap-panic (get-impl-or-none pool-type))))
          (new-id (var-get next-pool-id))
          (key {token-0: (get token-0 ordered), token-1: (get token-1 ordered), pool-type: pool-type, fee-tier: fee-tier}))

      ;; prevent duplicates for same ordered pair + type + fee
      (asserts! (is-none (map-get? pair-index key)) (err ERR_POOL_ALREADY_EXISTS))

      ;; register pool (use implementation principal as pool-address placeholder)
      (map-set pools-by-id new-id {
        pool-address: impl,
        token-0: (get token-0 ordered),
        token-1: (get token-1 ordered),
        pool-type: pool-type,
        fee-tier: fee-tier,
        implementation: impl,
        created-at: block-height,
        creator: tx-sender,
        params: optional-params
      })
      (map-set pair-index key impl)
      (append-pair-pool (get token-0 ordered) (get token-1 ordered) impl)

      ;; update counters
      (var-set total-pools (+ (var-get total-pools) u1))
      (var-set next-pool-id (+ new-id u1))

      (ok {
        pool-id: new-id,
        pool-address: impl,
        token-0: (get token-0 ordered),
        token-1: (get token-1 ordered),
        pool-type: pool-type,
        fee-tier: fee-tier
      }))))

;; Read-only: get implementation config
(define-read-only (get-pool-implementation (pool-type (string-ascii 20)))
  (map-get? pool-implementations pool-type))

;; Read-only: get a pool by pair + type + fee
(define-read-only (get-pool (token-a principal) (token-b principal) (pool-type (string-ascii 20)) (fee-tier uint))
  (let ((o (order-tokens token-a token-b)))
    (map-get? pair-index {token-0: (get token-0 o), token-1: (get token-1 o), pool-type: pool-type, fee-tier: fee-tier})))

;; Read-only: list all pools for a pair
(define-read-only (get-pools-for-pair (token-a principal) (token-b principal))
  (let ((o (order-tokens token-a token-b)))
    (default-to (list) (map-get? pair-pools {token-0: (get token-0 o), token-1: (get token-1 o)}))) )

;; Validate parameters helper (public)
(define-public (validate-pool-parameters (pool-type (string-ascii 20)) (fee-tier uint) (optional-params (optional (tuple (weight-0 uint) (weight-1 uint) (amp uint)))))
  (begin
    (asserts! (is-some (get-impl-or-none pool-type)) (err ERR_INVALID_POOL_TYPE))
    (asserts! (is-valid-fee-tier pool-type fee-tier) (err ERR_INVALID_FEE_TIER))
    (match (validate-params-internal pool-type optional-params)
      (ok ok?) (if ok? (ok true) (err ERR_INVALID_PARAMETERS))
      e (err ERR_INVALID_PARAMETERS))))

;; Migrate a pool to a new implementation principal (preserve metadata)
(define-public (migrate-pool (pool-id uint) (new-implementation principal))
  (match (map-get? pools-by-id pool-id)
    meta
      (begin
        (map-set pools-by-id pool-id {
          pool-address: new-implementation,
          token-0: (get token-0 meta),
          token-1: (get token-1 meta),
          pool-type: (get pool-type meta),
          fee-tier: (get fee-tier meta),
          implementation: new-implementation,
          created-at: (get created-at meta),
          creator: (get creator meta),
          params: (get params meta)
        })
        (ok true))
    (err u1)))

;; Read-only: get pool metadata by id
(define-read-only (get-pool-metadata (pool-id uint))
  (match (map-get? pools-by-id pool-id)
    meta (some {
      token-0: (get token-0 meta),
      token-1: (get token-1 meta),
      pool-type: (get pool-type meta),
      fee-tier: (get fee-tier meta),
      pool-address: (get pool-address meta)
    })
    none))

;; Update stats
(define-public (update-pool-stats (pool-id uint) (volume24h uint) (fees24h uint) (lp-count uint))
  (begin
    (map-set pool-stats pool-id { total-volume-24h: volume24h, total-fees-24h: fees24h, liquidity-providers: lp-count })
    (ok true)))

;; Read-only: get stats
(define-read-only (get-pool-stats (pool-id uint))
  (map-get? pool-stats pool-id))

;; Read-only: utilization metrics (simple projection of stats)
(define-read-only (get-pool-utilization-metrics (pool-id uint))
  (let ((s (default-to { total-volume-24h: u0, total-fees-24h: u0, liquidity-providers: u0 } (map-get? pool-stats pool-id))))
    { volume-24h: (get total-volume-24h s), fees-24h: (get total-fees-24h s), lp-count: (get liquidity-providers s) }))

;; Read-only: factory config
(define-read-only (get-factory-config)
  { enabled: (var-get factory-enabled), protocol-fee-bps: (var-get protocol-fee-bps), supported-types: (var-get supported-types) })

;; Read-only: total pools
(define-read-only (get-total-pools) (var-get total-pools))

;; Admin: toggle type enabled
(define-public (set-pool-type-enabled (pool-type (string-ascii 20)) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (match (map-get? pool-implementations pool-type)
      cfg (begin (map-set pool-implementations pool-type {
                          implementation: (get implementation cfg),
                          enabled: enabled,
                          fee-tiers: (get fee-tiers cfg),
                          min-liquidity: (get min-liquidity cfg),
                          max-positions: (get max-positions cfg) }) (ok true))
      (err ERR_INVALID_POOL_TYPE))))

;; Admin: set protocol fee
(define-public (set-protocol-fee (bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set protocol-fee-bps bps)
    (ok true)))

;; Admin: add new pool implementation
(define-public (add-pool-implementation (pool-type (string-ascii 20)) (implementation principal) (fee-tiers (list 10 uint)) (min-liquidity uint) (max-positions uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set pool-implementations pool-type {
      implementation: implementation,
      enabled: true,
      fee-tiers: fee-tiers,
      min-liquidity: min-liquidity,
      max-positions: max-positions
    })
    ;; best-effort update supported-types (no de-dup enforcement needed by tests)
    (let ((cur (var-get supported-types)))
      (if (< (len cur) MAX_SUPPORTED_TYPES)
          (var-set supported-types (unwrap-panic (as-max-len? (append cur pool-type) u20)))
          true))
    (ok true)))

;; Admin: factory enabled
(define-public (set-factory-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set factory-enabled enabled)
    (ok true)))
