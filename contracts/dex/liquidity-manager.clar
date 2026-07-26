;; liquidity-manager.clar
;; Conxian Protocol: production-safe concentrated-liquidity intent ledger.
;;
;; The current concentrated-liquidity-pool contract does not expose liquidity
;; custody, pool reads, fee accounting, or LP position APIs. This contract
;; therefore records validated user intents and risk metadata only. It never
;; transfers tokens, claims pool liquidity, changes pool state, or represents
;; an executed LP position.
;;
;; pool-id and token principals are caller-supplied intent metadata. They are
;; stored for later execution, but this ledger does not verify them against an
;; on-chain pool or token registry.

(use-trait oracle-trait .defi-traits.oracle-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Stable public error identifiers.
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_POSITION_NOT_FOUND (err u2001))
(define-constant ERR_NON_COMPLIANT (err u2003))
(define-constant ERR_INVALID_POOL (err u2004))
(define-constant ERR_ZERO_LIQUIDITY (err u2005))
(define-constant ERR_INVALID_TICK_RANGE (err u2006))
(define-constant ERR_ORACLE_NOT_CONFIGURED (err u2007))
(define-constant ERR_ORACLE_MISMATCH (err u2008))
(define-constant ERR_INVALID_PRICE_MOVE_LIMIT (err u2009))
(define-constant ERR_ZERO_ORACLE_PRICE (err u2010))
(define-constant ERR_INVALID_TOKEN_PAIR (err u2011))
(define-constant ERR_POSITION_CLOSED (err u2012))
(define-constant ERR_ENTRY_PRICES_REQUIRED (err u2013))
(define-constant ERR_REBALANCE_EXISTS (err u2014))
(define-constant ERR_REBALANCE_NOT_FOUND (err u2015))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u2016))
(define-constant ERR_POSITION_ID_OVERFLOW (err u2017))
(define-constant ERR_INVALID_OBSERVED_TICK (err u2018))
(define-constant ERR_V2_POSITION_NOT_MANAGED (err u2019))
(define-constant ERR_V2_STATE_MISMATCH (err u2020))
(define-constant ERR_V2_POOL_NOT_FOUND (err u2021))
(define-constant ERR_V2_INVALID_PAIR (err u2022))

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant BASIS_POINTS u10000)
(define-constant DEFAULT_MAX_PRICE_MOVE_BPS u10000)

;; Contract configuration and monotonically increasing intent IDs.
(define-data-var contract-owner principal tx-sender)
(define-data-var configured-oracle (optional principal) none)
(define-data-var next-position-id uint u1)

;; A position is an intent record. accounted-liquidity intentionally remains
;; zero until a future pool API can prove actual custody and execution.
(define-map positions uint
  {
    owner: principal,
    pool-id: uint,
    tick-lower: int,
    tick-upper: int,
    requested-liquidity: uint,
    accounted-liquidity: uint,
    active: bool,
    opened-at: uint,
    closed-at: (optional uint),
    token-0: (optional principal),
    token-1: (optional principal),
    entry-price-0: (optional uint),
    entry-price-1: (optional uint),
    max-price-move-bps: uint
  }
)

;; At most one active rebalance intent is tracked for a position. This record
;; is advisory and never mutates the position's requested/accounted liquidity.
(define-map rebalance-plans uint
  {
    target-tick-lower: int,
    target-tick-upper: int,
    target-liquidity: uint,
    requested-at: uint,
    cancelled-at: (optional uint),
    active: bool
  }
)

;; V2 execution metadata is keyed by the canonical pool position ID. The V2
;; pool remains authoritative for ownership, range, liquidity, custody, fees,
;; settlement, and PnL; this map records only manager linkage and lifecycle.
(define-map v2-managed-positions uint
  {
    owner: principal,
    pool-id: uint,
    token-0: principal,
    token-1: principal,
    tick-lower: int,
    tick-upper: int,
    liquidity: uint,
    deposited-0: uint,
    deposited-1: uint,
    active: bool,
    opened-at: uint,
    closed-at: (optional uint),
    replaces: (optional uint),
    replaced-by: (optional uint)
  }
)

;; --- Private helpers -----------------------------------------------------

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-position-owner (position { owner: principal, pool-id: uint, tick-lower: int, tick-upper: int, requested-liquidity: uint, accounted-liquidity: uint, active: bool, opened-at: uint, closed-at: (optional uint), token-0: (optional principal), token-1: (optional principal), entry-price-0: (optional uint), entry-price-1: (optional uint), max-price-move-bps: uint }))
  (is-eq tx-sender (get owner position))
)

(define-private (can-manage-position (position { owner: principal, pool-id: uint, tick-lower: int, tick-upper: int, requested-liquidity: uint, accounted-liquidity: uint, active: bool, opened-at: uint, closed-at: (optional uint), token-0: (optional principal), token-1: (optional principal), entry-price-0: (optional uint), entry-price-1: (optional uint), max-price-move-bps: uint }))
  (or (is-owner) (is-position-owner position))
)

(define-private (deactivate-rebalance-plan (position-id uint))
  (match (map-get? rebalance-plans position-id)
    plan
      (if (get active plan)
        (begin
          (map-set rebalance-plans position-id (merge plan {
            cancelled-at: (some burn-block-height),
            active: false
          }))
          (print {
            event: "unexecuted-rebalance-intent-invalidated",
            execution: "not-executed",
            position-id: position-id,
            reason: "position-closed"
          })
          true
        )
        true
      )
    true
  )
)

(define-private (valid-tick-range (tick-lower int) (tick-upper int))
  (and
    (< tick-lower tick-upper)
    (contract-call? .concentrated-math is-valid-tick tick-lower)
    (contract-call? .concentrated-math is-valid-tick tick-upper)
  )
)

(define-private (validate-position-inputs
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
  )
  (begin
    (asserts! (> pool-id u0) ERR_INVALID_POOL)
    (asserts! (> liquidity u0) ERR_ZERO_LIQUIDITY)
    (asserts! (valid-tick-range tick-lower tick-upper) ERR_INVALID_TICK_RANGE)
    (ok true)
  )
)

(define-private (assert-compliance)
  ;; A failed compliance response is converted to the stable local error, and
  ;; an explicit false response is rejected as well.
  (let ((compliant (unwrap!
      (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)
      ERR_NON_COMPLIANT
    )))
    (asserts! compliant ERR_NON_COMPLIANT)
    (ok true)
  )
)

(define-private (assert-configured-oracle (oracle-source <oracle-trait>))
  (begin
    ;; Configuration and all consuming calls are restricted to the canonical
    ;; facade, while the stored principal comparison preserves the injected
    ;; trait/principal guard pattern.
    (asserts! (is-eq (contract-of oracle-source) .oracle) ERR_ORACLE_MISMATCH)
    (match (var-get configured-oracle)
      configured
        (if (is-eq configured (contract-of oracle-source))
          (ok true)
          ERR_ORACLE_MISMATCH
        )
      ERR_ORACLE_NOT_CONFIGURED
    )
  )
)

;; Read the canonical aggregate spot only after the facade validates it against
;; its configured TWAP deviation. Upstream response errors are preserved so
;; missing, stale, or divergent data remains deterministic to callers.
(define-private (fetch-nonzero-validated-price (token principal))
  (match (contract-call? .oracle get-validated-price token)
    price
      (if (> price u0)
        (ok price)
        ERR_ZERO_ORACLE_PRICE
      )
    error-value (err error-value)
  )
)

;; Compute ceil(reference * bps / 10,000) without multiplying the full
;; reference by bps. bps is bounded to 10,000, so the two products are safe.
(define-private (ceil-reference-times-bps (reference uint) (bps uint))
  (let (
      (whole-part (* (/ reference BASIS_POINTS) bps))
      (remainder-part (* (mod reference BASIS_POINTS) bps))
    )
    (+ whole-part
      (if (is-eq remainder-part u0)
        u0
        (if (is-eq (mod remainder-part BASIS_POINTS) u0)
          (/ remainder-part BASIS_POINTS)
          (+ (/ remainder-part BASIS_POINTS) u1)
        )
      )
    )
  )
)

;; Find floor(remainder * 10,000 / reference), where remainder < reference,
;; using bounded binary steps instead of an overflow-prone multiplication.
(define-private (accumulate-fractional-bps
    (step uint)
    (acc { candidate: uint, difference: uint, reference: uint }))
  (let ((candidate (+ (get candidate acc) step)))
    (if (and
        (<= candidate BASIS_POINTS)
        (>=
          (get difference acc)
          (ceil-reference-times-bps (get reference acc) candidate)
        )
      )
      {
        candidate: candidate,
        difference: (get difference acc),
        reference: (get reference acc)
      }
      acc
    )
  )
)

(define-private (calculate-fractional-bps (difference uint) (reference uint))
  (get candidate
    (fold accumulate-fractional-bps
      (list u8192 u4096 u2048 u1024 u512 u256 u128 u64 u32 u16 u8 u4 u2 u1)
      { candidate: u0, difference: difference, reference: reference }
    )
  )
)

;; Compute floor(abs(current-entry) * 10,000 / entry) without overflowing.
;; At the quotient boundary, the fractional portion must also fit in
;; MAX_UINT before the final addition is evaluated.
(define-private (calculate-movement-bps (entry-price uint) (current-price uint))
  (if (is-eq entry-price u0)
    ERR_ZERO_ORACLE_PRICE
    (let (
        (difference (if (> current-price entry-price)
          (- current-price entry-price)
          (- entry-price current-price)
        ))
        (whole-part (/ difference entry-price))
        (fractional-part (calculate-fractional-bps (mod difference entry-price) entry-price))
      )
      (if (> whole-part (/ MAX_UINT BASIS_POINTS))
        ERR_ARITHMETIC_OVERFLOW
        (if (and
            (is-eq whole-part (/ MAX_UINT BASIS_POINTS))
            (> fractional-part (mod MAX_UINT BASIS_POINTS))
          )
          ERR_ARITHMETIC_OVERFLOW
          (ok (+ (* whole-part BASIS_POINTS) fractional-part))
        )
      )
    )
  )
)

(define-private (create-position
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
    (token-0 (optional principal))
    (token-1 (optional principal))
    (entry-price-0 (optional uint))
    (entry-price-1 (optional uint))
    (max-price-move-bps uint)
  )
  (let ((position-id (var-get next-position-id)))
    (begin
      (asserts! (< position-id MAX_UINT) ERR_POSITION_ID_OVERFLOW)
      (map-set positions position-id {
        owner: tx-sender,
        pool-id: pool-id,
        tick-lower: tick-lower,
        tick-upper: tick-upper,
        requested-liquidity: liquidity,
        accounted-liquidity: u0,
        active: true,
        opened-at: burn-block-height,
        closed-at: none,
        token-0: token-0,
        token-1: token-1,
        entry-price-0: entry-price-0,
        entry-price-1: entry-price-1,
        max-price-move-bps: max-price-move-bps
      })
      (var-set next-position-id (+ position-id u1))
      (print {
        event: "unexecuted-position-intent-opened",
        intent: "unexecuted-position-intent",
        execution: "not-executed",
        position-id: position-id,
        owner: tx-sender,
        pool-id: pool-id,
        pool-id-source: "caller-supplied-intent-metadata",
        pool-registry-verified: false,
        token-0: token-0,
        token-1: token-1,
        token-source: "caller-supplied-intent-metadata",
        token-registry-verified: false,
        requested-liquidity: liquidity,
        accounted-liquidity: u0
      })
      (ok position-id)
    )
  )
)

(define-private (update-position-risk-limit-internal
    (position-id uint)
    (max-price-move-bps uint)
  )
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (can-manage-position position) ERR_UNAUTHORIZED)
      (asserts! (get active position) ERR_POSITION_CLOSED)
      (asserts! (<= max-price-move-bps BASIS_POINTS) ERR_INVALID_PRICE_MOVE_LIMIT)
      (map-set positions position-id (merge position {
        max-price-move-bps: max-price-move-bps
      }))
      (print {
        event: "position-risk-limit-updated",
        position-id: position-id,
        max-price-move-bps: max-price-move-bps
      })
      (ok true)
    )
  )
)

;; --- Configuration -------------------------------------------------------

;; @desc Configure the canonical oracle contract principal. No price is read
;; here; every consuming API re-checks that its trait argument matches this
;; stored principal.
(define-public (set-oracle (oracle-source <oracle-trait>))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (contract-of oracle-source) .oracle) ERR_ORACLE_MISMATCH)
    (var-set configured-oracle (some (contract-of oracle-source)))
    (print {
      event: "liquidity-manager-oracle-configured",
      oracle: (contract-of oracle-source)
    })
    (ok true)
  )
)

;; Compatibility name for callers that use the more explicit configuration
;; verb. It has identical owner-only and principal-matching semantics.
(define-public (set-oracle-source (oracle-source <oracle-trait>))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (contract-of oracle-source) .oracle) ERR_ORACLE_MISMATCH)
    (var-set configured-oracle (some (contract-of oracle-source)))
    (print {
      event: "liquidity-manager-oracle-configured",
      oracle: (contract-of oracle-source)
    })
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Position intents ----------------------------------------------------

;; @desc Record a validated, unexecuted position intent. No token or pool
;; operation is performed and accounted-liquidity is always initialized to u0.
(define-public (open-position
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
  )
  (begin
    (try! (assert-compliance))
    (try! (validate-position-inputs pool-id tick-lower tick-upper liquidity))
    (create-position
      pool-id
      tick-lower
      tick-upper
      liquidity
      none
      none
      none
      none
      DEFAULT_MAX_PRICE_MOVE_BPS
    )
  )
)

;; @desc Record an intent with caller-supplied token/pool metadata and
;; nonzero entry prices validated by the canonical oracle facade. The oracle
;; trait argument must be the configured .oracle principal. This still
;; performs no token transfer, custody, pool execution, registry lookup, or
;; balance claim.
(define-public (open-position-with-assets
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
    (token-0 principal)
    (token-1 principal)
    (oracle-source <oracle-trait>)
    (max-price-move-bps uint)
  )
  (begin
    (try! (assert-compliance))
    (try! (validate-position-inputs pool-id tick-lower tick-upper liquidity))
    (asserts! (not (is-eq token-0 token-1)) ERR_INVALID_TOKEN_PAIR)
    (asserts! (<= max-price-move-bps BASIS_POINTS) ERR_INVALID_PRICE_MOVE_LIMIT)
    (try! (assert-configured-oracle oracle-source))
    (let (
        (entry-price-0 (try! (fetch-nonzero-validated-price token-0)))
        (entry-price-1 (try! (fetch-nonzero-validated-price token-1)))
      )
      (create-position
        pool-id
        tick-lower
        tick-upper
        liquidity
        (some token-0)
        (some token-1)
        (some entry-price-0)
        (some entry-price-1)
        max-price-move-bps
      )
    )
  )
)

;; @desc Read a position intent and its accounting boundary.
(define-read-only (get-position (position-id uint))
  (map-get? positions position-id)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-configured-oracle)
  (var-get configured-oracle)
)

;; @desc Close only the local intent record. There is deliberately no token
;; transfer or pool call because no custody/execution API exists yet.
(define-public (close-position (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (can-manage-position position) ERR_UNAUTHORIZED)
      (asserts! (get active position) ERR_POSITION_CLOSED)
      (map-set positions position-id (merge position {
        active: false,
        closed-at: (some burn-block-height)
      }))
      (deactivate-rebalance-plan position-id)
      (print {
        event: "position-intent-closed",
        execution: "not-executed",
        position-id: position-id,
        accounted-liquidity: (get accounted-liquidity position)
      })
      (ok true)
    )
  )
)

;; @desc Update the price-movement protection proxy threshold.
(define-public (update-risk-limit (position-id uint) (max-price-move-bps uint))
  (update-position-risk-limit-internal position-id max-price-move-bps)
)

;; Compatibility name for integrations that call the operation a setter.
(define-public (set-risk-limit (position-id uint) (max-price-move-bps uint))
  (update-position-risk-limit-internal position-id max-price-move-bps)
)

;; @desc Read the price-movement protection proxy. This is not exact
;; concentrated-liquidity impermanent-loss accounting. It compares current
;; injected-oracle prices with recorded entry prices and triggers only when
;; movement is strictly greater than the configured threshold; equality is safe.
(define-read-only (get-il-protection-status
    (position-id uint)
    (oracle-source <oracle-trait>)
  )
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (get active position) ERR_POSITION_CLOSED)
      (try! (assert-configured-oracle oracle-source))
      (let (
          (token-0 (unwrap! (get token-0 position) ERR_ENTRY_PRICES_REQUIRED))
          (token-1 (unwrap! (get token-1 position) ERR_ENTRY_PRICES_REQUIRED))
          (entry-price-0 (unwrap! (get entry-price-0 position) ERR_ENTRY_PRICES_REQUIRED))
          (entry-price-1 (unwrap! (get entry-price-1 position) ERR_ENTRY_PRICES_REQUIRED))
          (current-price-0 (try! (fetch-nonzero-validated-price token-0)))
          (current-price-1 (try! (fetch-nonzero-validated-price token-1)))
          (movement-bps-0 (try! (calculate-movement-bps entry-price-0 current-price-0)))
          (movement-bps-1 (try! (calculate-movement-bps entry-price-1 current-price-1)))
          (max-price-move-bps (get max-price-move-bps position))
        )
        (ok {
          protection-type: "price-movement-proxy",
          observation: "oracle-price-movement-not-exact-il",
          position-id: position-id,
          entry-price-0: entry-price-0,
          current-price-0: current-price-0,
          movement-bps-0: movement-bps-0,
          entry-price-1: entry-price-1,
          current-price-1: current-price-1,
          movement-bps-1: movement-bps-1,
          max-price-move-bps: max-price-move-bps,
          triggered: (or
            (> movement-bps-0 max-price-move-bps)
            (> movement-bps-1 max-price-move-bps)
          ),
          threshold-equality-safe: true
        })
      )
    )
  )
)

;; --- Rebalance intents ---------------------------------------------------

;; @desc Request a position-owner-only rebalance intent. It validates the
;; target range but never changes the position, accounted liquidity, or pool.
(define-public (request-rebalance
    (position-id uint)
    (target-tick-lower int)
    (target-tick-upper int)
    (target-liquidity uint)
  )
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-position-owner position) ERR_UNAUTHORIZED)
      (asserts! (get active position) ERR_POSITION_CLOSED)
      (asserts! (valid-tick-range target-tick-lower target-tick-upper) ERR_INVALID_TICK_RANGE)
      (asserts! (> target-liquidity u0) ERR_ZERO_LIQUIDITY)
      (asserts!
        (match (map-get? rebalance-plans position-id)
          plan (not (get active plan))
          true
        )
        ERR_REBALANCE_EXISTS
      )
      (map-set rebalance-plans position-id {
        target-tick-lower: target-tick-lower,
        target-tick-upper: target-tick-upper,
        target-liquidity: target-liquidity,
        requested-at: burn-block-height,
        cancelled-at: none,
        active: true
      })
      (print {
        event: "unexecuted-rebalance-intent-requested",
        execution: "not-executed",
        position-id: position-id,
        target-tick-lower: target-tick-lower,
        target-tick-upper: target-tick-upper,
        target-liquidity: target-liquidity
      })
      (ok true)
    )
  )
)

(define-read-only (get-rebalance (position-id uint))
  (map-get? rebalance-plans position-id)
)

(define-read-only (get-rebalance-plan (position-id uint))
  (map-get? rebalance-plans position-id)
)

;; @desc Cancel an active rebalance intent without mutating position liquidity.
(define-public (cancel-rebalance (position-id uint))
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-position-owner position) ERR_UNAUTHORIZED)
      (let ((plan (unwrap! (map-get? rebalance-plans position-id) ERR_REBALANCE_NOT_FOUND)))
        (begin
          (asserts! (get active plan) ERR_REBALANCE_NOT_FOUND)
          (map-set rebalance-plans position-id (merge plan {
            cancelled-at: (some burn-block-height),
            active: false
          }))
          (print {
            event: "unexecuted-rebalance-intent-cancelled",
            execution: "not-executed",
            position-id: position-id
          })
          (ok true)
        )
      )
    )
  )
)

;; @desc Return advisory in/out-of-range guidance from a caller-supplied
;; observed tick. The pool has no current-tick getter, so this never claims
;; that the observation came from the pool and never executes a rebalance.
(define-read-only (get-rebalance-advice (position-id uint) (observed-tick int))
  (let ((position (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (get active position) ERR_POSITION_CLOSED)
      (asserts!
        (and
          (contract-call? .concentrated-math is-valid-tick observed-tick)
        )
        ERR_INVALID_OBSERVED_TICK
      )
      (let (
          (tick-lower (get tick-lower position))
          (tick-upper (get tick-upper position))
          (in-range (and
            (>= observed-tick tick-lower)
            (<= observed-tick tick-upper)
          ))
        )
        (ok {
          position-id: position-id,
          observed-tick: observed-tick,
          tick-lower: tick-lower,
          tick-upper: tick-upper,
          in-range: in-range,
          should-rebalance: (not in-range),
          observation-source: "caller-observed-advisory",
          pool-current-tick-available: false,
          execution: "not-executed"
        })
      )
    )
  )
)

;; --- Executable V2 positions --------------------------------------------

;; @desc Open a canonical V2 position directly from tx-sender custody. The
;; manager never pre-custodies funds and records metadata only after the pool
;; has created and returned the authoritative position lot.
(define-public (open-position-v2
    (pool-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (tick-lower int)
    (tick-upper int)
    (max-amount0 uint)
    (max-amount1 uint)
    (min-liquidity uint)
  )
  (begin
    (try! (assert-compliance))
    (let ((pool (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-pool pool-id)
      ERR_V2_POOL_NOT_FOUND)))
      (begin
        (asserts! (get active pool) (err u2307))
        (asserts! (and
          (is-eq (contract-of token-0) (get token-0 pool))
          (is-eq (contract-of token-1) (get token-1 pool))) ERR_V2_INVALID_PAIR)
        (let (
            (opened (try! (contract-call? .concentrated-liquidity-pool-v2 add-liquidity
              pool-id token-0 token-1 tick-lower tick-upper
              max-amount0 max-amount1 min-liquidity)))
            (position-id (get position-id opened))
            (position (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-position
              (get position-id opened)) ERR_V2_STATE_MISMATCH))
          )
          (begin
            (asserts! (and
              (is-eq (get owner position) tx-sender)
              (is-eq (get pool-id position) pool-id)
              (is-eq (get lower-tick position) tick-lower)
              (is-eq (get upper-tick position) tick-upper)
              (is-eq (get liquidity position) (get liquidity opened))
              (is-eq (get deposited-0 position) (get amount0 opened))
              (is-eq (get deposited-1 position) (get amount1 opened))
              (get active position)
              (not (get closed position))) ERR_V2_STATE_MISMATCH)
            (map-set v2-managed-positions position-id {
              owner: tx-sender,
              pool-id: pool-id,
              token-0: (contract-of token-0),
              token-1: (contract-of token-1),
              tick-lower: tick-lower,
              tick-upper: tick-upper,
              liquidity: (get liquidity opened),
              deposited-0: (get amount0 opened),
              deposited-1: (get amount1 opened),
              active: true,
              opened-at: block-height,
              closed-at: none,
              replaces: none,
              replaced-by: none
            })
            (print {
              event: "v2-managed-position-opened",
              position-id: position-id,
              owner: tx-sender,
              pool-id: pool-id,
              liquidity: (get liquidity opened),
              amount0: (get amount0 opened),
              amount1: (get amount1 opened)
            })
            (ok opened)
          )
        )
      )
    )
  )
)

;; @desc Close an owner-controlled V2 lot in full. Legacy manager admin rights
;; do not apply: tx-sender must match both manager metadata and V2 ownership.
(define-public (close-position-v2
    (position-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (min-amount0 uint)
    (min-amount1 uint)
  )
  (let (
      (managed (unwrap! (map-get? v2-managed-positions position-id) ERR_V2_POSITION_NOT_MANAGED))
      (position (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-position position-id)
        ERR_V2_STATE_MISMATCH))
      (pool (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-pool (get pool-id managed))
        ERR_V2_POOL_NOT_FOUND))
    )
    (begin
      (asserts! (is-eq tx-sender (get owner managed)) ERR_UNAUTHORIZED)
      (asserts! (and (get active managed)
        (get active position) (not (get closed position))
        (is-eq (get owner position) tx-sender)
        (is-eq (get pool-id position) (get pool-id managed))
        (is-eq (get lower-tick position) (get tick-lower managed))
        (is-eq (get upper-tick position) (get tick-upper managed))
        (is-eq (get liquidity position) (get liquidity managed))
        (is-eq (get token-0 managed) (get token-0 pool))
        (is-eq (get token-1 managed) (get token-1 pool))
        (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR_V2_STATE_MISMATCH)
      (let ((closed (try! (contract-call? .concentrated-liquidity-pool-v2 remove-liquidity
        position-id token-0 token-1 min-amount0 min-amount1 tx-sender))))
        (begin
          (map-set v2-managed-positions position-id (merge managed {
            active: false,
            closed-at: (some block-height)
          }))
          (print {
            event: "v2-managed-position-closed",
            position-id: position-id,
            owner: tx-sender,
            amount0: (get amount0 closed),
            amount1: (get amount1 closed)
          })
          (ok closed)
        )
      )
    )
  )
)

;; @desc Atomically close one canonical V2 lot to tx-sender and open its
;; replacement from tx-sender. If replacement creation fails, Clarity rolls
;; back the close, transfers, tick changes, pool accounting, and manager maps.
(define-public (rebalance-position-v2
    (position-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (target-tick-lower int)
    (target-tick-upper int)
    (max-amount0 uint)
    (max-amount1 uint)
    (min-liquidity uint)
    (min-close-amount0 uint)
    (min-close-amount1 uint)
  )
  (let (
      (managed (unwrap! (map-get? v2-managed-positions position-id) ERR_V2_POSITION_NOT_MANAGED))
      (position (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-position position-id)
        ERR_V2_STATE_MISMATCH))
      (pool (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-pool (get pool-id managed))
        ERR_V2_POOL_NOT_FOUND))
    )
    (begin
      (try! (assert-compliance))
      (asserts! (is-eq tx-sender (get owner managed)) ERR_UNAUTHORIZED)
      (asserts! (and (get active managed)
        (get active position) (not (get closed position))
        (is-eq (get owner position) tx-sender)
        (is-eq (get pool-id position) (get pool-id managed))
        (is-eq (get lower-tick position) (get tick-lower managed))
        (is-eq (get upper-tick position) (get tick-upper managed))
        (is-eq (get liquidity position) (get liquidity managed))
        (is-eq (get token-0 managed) (get token-0 pool))
        (is-eq (get token-1 managed) (get token-1 pool))
        (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR_V2_STATE_MISMATCH)
      (let (
          (closed (try! (contract-call? .concentrated-liquidity-pool-v2 remove-liquidity
            position-id token-0 token-1 min-close-amount0 min-close-amount1 tx-sender)))
          (opened (try! (contract-call? .concentrated-liquidity-pool-v2 add-liquidity
            (get pool-id managed) token-0 token-1 target-tick-lower target-tick-upper
            max-amount0 max-amount1 min-liquidity)))
          (replacement-id (get position-id opened))
          (replacement (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-position
            (get position-id opened)) ERR_V2_STATE_MISMATCH))
        )
        (begin
          (asserts! (and
            (is-eq (get owner replacement) tx-sender)
            (is-eq (get pool-id replacement) (get pool-id managed))
            (is-eq (get lower-tick replacement) target-tick-lower)
            (is-eq (get upper-tick replacement) target-tick-upper)
            (is-eq (get liquidity replacement) (get liquidity opened))
            (is-eq (get deposited-0 replacement) (get amount0 opened))
            (is-eq (get deposited-1 replacement) (get amount1 opened))
            (get active replacement)
            (not (get closed replacement))) ERR_V2_STATE_MISMATCH)
          (map-set v2-managed-positions position-id (merge managed {
            active: false,
            closed-at: (some block-height),
            replaced-by: (some replacement-id)
          }))
          (map-set v2-managed-positions replacement-id {
            owner: tx-sender,
            pool-id: (get pool-id managed),
            token-0: (get token-0 managed),
            token-1: (get token-1 managed),
            tick-lower: target-tick-lower,
            tick-upper: target-tick-upper,
            liquidity: (get liquidity opened),
            deposited-0: (get amount0 opened),
            deposited-1: (get amount1 opened),
            active: true,
            opened-at: block-height,
            closed-at: none,
            replaces: (some position-id),
            replaced-by: none
          })
          (print {
            event: "v2-managed-position-rebalanced",
            old-position-id: position-id,
            new-position-id: replacement-id,
            owner: tx-sender,
            closed-amount0: (get amount0 closed),
            closed-amount1: (get amount1 closed),
            opened-amount0: (get amount0 opened),
            opened-amount1: (get amount1 opened)
          })
          (ok {
            old-position-id: position-id,
            new-position-id: replacement-id,
            closed: closed,
            opened: opened
          })
        )
      )
    )
  )
)

;; @desc Read manager linkage only; use the V2 proxy reads below for economic
;; state. The key is the canonical V2 position ID, not a manager-local ID.
(define-read-only (get-v2-managed-position (position-id uint))
  (map-get? v2-managed-positions position-id)
)

;; @desc Proxy the authoritative V2 lot without reinterpreting ownership,
;; range, liquidity, fees, custody, or settlement state.
(define-read-only (get-v2-authoritative-position (position-id uint))
  (begin
    (asserts! (is-some (map-get? v2-managed-positions position-id)) ERR_V2_POSITION_NOT_MANAGED)
    (ok (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-position position-id)
      ERR_V2_STATE_MISMATCH))
  )
)

;; @desc Proxy V2 executable-state PnL. This is independent of the legacy
;; configured oracle and preserves the pool's gain-versus-loss distinction.
(define-read-only (get-v2-position-pnl (position-id uint))
  (begin
    (asserts! (is-some (map-get? v2-managed-positions position-id)) ERR_V2_POSITION_NOT_MANAGED)
    (contract-call? .concentrated-liquidity-pool-v2 get-position-pnl position-id)
  )
)

;; @desc Proxy V2 loss-only exact IL. Outperformance remains a separate field
;; and is never mislabeled as impermanent loss.
(define-read-only (get-v2-exact-il (position-id uint))
  (begin
    (asserts! (is-some (map-get? v2-managed-positions position-id)) ERR_V2_POSITION_NOT_MANAGED)
    (contract-call? .concentrated-liquidity-pool-v2 get-exact-il position-id)
  )
)
