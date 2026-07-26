;; concentrated-liquidity-pool-v2.clar
;; Executable, custody-backed, bounded concentrated-liquidity pool.
;;
;; V2 is intentionally isolated from the legacy CLP/CXLP compatibility model.
;; The non-transferable position record below is the sole withdrawal
;; entitlement. No CXLP mint, burn, transfer, or inferred range ownership is
;; exposed by this contract.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant Q u1000000000000)
(define-constant FEE-DENOMINATOR u1000000)
(define-constant PROTOCOL-SHARE-BPS u1000) ;; 10% of each assessed swap fee
(define-constant BPS-DENOMINATOR u10000)
(define-constant MAX-LIQUIDITY u1000000000000)
(define-constant MAX-AMOUNT u1000000000000)
(define-constant MAX-INITIALIZED-TICKS u16)
(define-constant MAX-CROSSINGS u8)
(define-constant SELF .concentrated-liquidity-pool-v2)

(define-constant ERR-UNAUTHORIZED (err u2300))
(define-constant ERR-INVALID-PAIR (err u2301))
(define-constant ERR-INVALID-FEE (err u2302))
(define-constant ERR-INVALID-TICK (err u2303))
(define-constant ERR-INVALID-RANGE (err u2304))
(define-constant ERR-INVALID-AMOUNT (err u2305))
(define-constant ERR-POOL-NOT-FOUND (err u2306))
(define-constant ERR-POOL-INACTIVE (err u2307))
(define-constant ERR-POSITION-NOT-FOUND (err u2308))
(define-constant ERR-POSITION-CLOSED (err u2309))
(define-constant ERR-TICK-LIMIT (err u2310))
(define-constant ERR-ARITHMETIC (err u2311))
(define-constant ERR-TRANSFER (err u2312))
(define-constant ERR-CUSTODY-DELTA (err u2313))
(define-constant ERR-MINIMUM (err u2314))
(define-constant ERR-NO-LIQUIDITY (err u2315))
(define-constant ERR-PRICE-LIMIT (err u2316))
(define-constant ERR-TOO-MANY-CROSSINGS (err u2317))
(define-constant ERR-EXACT-INPUT-NOT-CONSUMED (err u2318))
(define-constant ERR-INSUFFICIENT-CUSTODY (err u2319))
(define-constant ERR-COMPATIBILITY-UNAVAILABLE (err u2320))
(define-constant ERR-PROTOCOL-RELEASE-DISABLED (err u2321))
(define-constant ERR-ZERO-OUTPUT (err u2322))

(define-data-var admin principal tx-sender)
(define-data-var pool-nonce uint u0)
(define-data-var position-nonce uint u0)

(define-map pools uint {
  token-0: principal,
  token-1: principal,
  fee-pips: uint,
  tick-spacing: uint,
  active: bool,
  sqrt-price: uint,
  current-tick: int,
  active-liquidity: uint,
  total-position-liquidity: uint,
  principal-0: uint,
  principal-1: uint,
  lp-fee-liability-0: uint,
  lp-fee-liability-1: uint,
  fee-growth-global-0: uint,
  fee-growth-global-1: uint,
  protocol-fees-0: uint,
  protocol-fees-1: uint,
  fee-dust-0: uint,
  fee-dust-1: uint,
  initialized-ticks: (list 16 int),
  initialized-tick-count: uint,
  position-count: uint,
  audit-height: uint
})

;; liquidity-net is the signed active-liquidity change when crossing upward.
(define-map ticks { pool-id: uint, tick: int } {
  initialized: bool,
  liquidity-gross: uint,
  liquidity-net: int,
  fee-growth-outside-0: uint,
  fee-growth-outside-1: uint
})

(define-map positions uint {
  owner: principal,
  pool-id: uint,
  lower-tick: int,
  upper-tick: int,
  liquidity: uint,
  active: bool,
  closed: bool,
  fee-growth-inside-checkpoint-0: uint,
  fee-growth-inside-checkpoint-1: uint,
  tokens-owed-0: uint,
  tokens-owed-1: uint,
  fee-remainder-0: uint,
  fee-remainder-1: uint,
  deposited-0: uint,
  deposited-1: uint,
  entry-sqrt-price: uint,
  cumulative-settled-0: uint,
  cumulative-settled-1: uint,
  close-sqrt-price: uint,
  opened-height: uint,
  closed-height: uint
})

;; SIP-010 custody is contract-wide, not pool-local. This aggregate prevents
;; another pool's legitimate custody from being mislabeled as a donation.
(define-map asset-accounting principal {
  principal: uint,
  lp-fee-liability: uint,
  protocol-fees: uint,
  fee-dust: uint
})

;; ---- checked arithmetic -------------------------------------------------

(define-private (safe-add (a uint) (b uint))
  (if (> a (- MAX-UINT b)) none (some (+ a b))))
(define-private (safe-sub (a uint) (b uint))
  (if (< a b) none (some (- a b))))
(define-private (safe-mul (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (some u0)
    (if (> a (/ MAX-UINT b)) none (some (* a b)))))
(define-private (ceil-div (a uint) (b uint))
  (if (is-eq b u0)
    none
    (let ((q (/ a b)) (r (mod a b)))
      (if (is-eq r u0) (some q) (safe-add q u1)))))

(define-private (fee-spacing (fee uint))
  (if (is-eq fee u500)
    (some u10)
    (if (is-eq fee u3000)
      (some u60)
      (if (is-eq fee u10000) (some u200) none))))

(define-private (is-aligned (tick int) (spacing uint))
  (contract-call? .concentrated-math-v2 is-aligned-tick tick spacing))

(define-private (empty-tick)
  { initialized: false, liquidity-gross: u0, liquidity-net: 0,
    fee-growth-outside-0: u0, fee-growth-outside-1: u0 })

(define-private (empty-asset-accounting)
  { principal: u0, lp-fee-liability: u0, protocol-fees: u0, fee-dust: u0 })

(define-private (in-range (current int) (lower int) (upper int))
  (and (>= current lower) (< current upper)))

(define-private (signed-add-liquidity (liquidity uint) (net int))
  (if (>= net 0)
    (let ((amount (to-uint net)))
      (match (safe-add liquidity amount) value (ok value) ERR-ARITHMETIC))
    (let ((amount (to-uint (* net (- 1)))))
      (match (safe-sub liquidity amount) value (ok value) ERR-NO-LIQUIDITY))))

(define-private (signed-sub-liquidity (liquidity uint) (net int))
  (signed-add-liquidity liquidity (* net (- 1))))

;; ---- fee growth ---------------------------------------------------------

(define-private (fee-growth-inside (pool-id uint) (lower int) (upper int) (pool {
    token-0: principal, token-1: principal, fee-pips: uint, tick-spacing: uint,
    active: bool, sqrt-price: uint, current-tick: int, active-liquidity: uint,
    total-position-liquidity: uint, principal-0: uint, principal-1: uint,
    lp-fee-liability-0: uint, lp-fee-liability-1: uint,
    fee-growth-global-0: uint, fee-growth-global-1: uint,
    protocol-fees-0: uint, protocol-fees-1: uint, fee-dust-0: uint, fee-dust-1: uint,
    initialized-ticks: (list 16 int), initialized-tick-count: uint,
    position-count: uint, audit-height: uint }))
  (let (
    (lower-state (default-to (empty-tick) (map-get? ticks { pool-id: pool-id, tick: lower })))
    (upper-state (default-to (empty-tick) (map-get? ticks { pool-id: pool-id, tick: upper })))
    (global0 (get fee-growth-global-0 pool))
    (global1 (get fee-growth-global-1 pool))
    (below0 (if (>= (get current-tick pool) lower)
      (get fee-growth-outside-0 lower-state)
      (unwrap! (safe-sub global0 (get fee-growth-outside-0 lower-state)) ERR-ARITHMETIC)))
    (below1 (if (>= (get current-tick pool) lower)
      (get fee-growth-outside-1 lower-state)
      (unwrap! (safe-sub global1 (get fee-growth-outside-1 lower-state)) ERR-ARITHMETIC)))
    (above0 (if (< (get current-tick pool) upper)
      (get fee-growth-outside-0 upper-state)
      (unwrap! (safe-sub global0 (get fee-growth-outside-0 upper-state)) ERR-ARITHMETIC)))
    (above1 (if (< (get current-tick pool) upper)
      (get fee-growth-outside-1 upper-state)
      (unwrap! (safe-sub global1 (get fee-growth-outside-1 upper-state)) ERR-ARITHMETIC)))
  )
    (ok {
      growth0: (unwrap! (safe-sub (unwrap! (safe-sub global0 below0) ERR-ARITHMETIC) above0) ERR-ARITHMETIC),
      growth1: (unwrap! (safe-sub (unwrap! (safe-sub global1 below1) ERR-ARITHMETIC) above1) ERR-ARITHMETIC)
    })))

(define-private (settled-fees (position {
    owner: principal, pool-id: uint, lower-tick: int, upper-tick: int,
    liquidity: uint, active: bool, closed: bool,
    fee-growth-inside-checkpoint-0: uint, fee-growth-inside-checkpoint-1: uint,
    tokens-owed-0: uint, tokens-owed-1: uint, fee-remainder-0: uint, fee-remainder-1: uint,
    deposited-0: uint, deposited-1: uint, entry-sqrt-price: uint,
    cumulative-settled-0: uint, cumulative-settled-1: uint,
    close-sqrt-price: uint, opened-height: uint, closed-height: uint })
    (inside { growth0: uint, growth1: uint }))
  (let (
    (delta0 (unwrap! (safe-sub (get growth0 inside) (get fee-growth-inside-checkpoint-0 position)) ERR-ARITHMETIC))
    (delta1 (unwrap! (safe-sub (get growth1 inside) (get fee-growth-inside-checkpoint-1 position)) ERR-ARITHMETIC))
    (numerator0 (unwrap! (safe-add
      (unwrap! (safe-mul delta0 (get liquidity position)) ERR-ARITHMETIC)
      (get fee-remainder-0 position)) ERR-ARITHMETIC))
    (numerator1 (unwrap! (safe-add
      (unwrap! (safe-mul delta1 (get liquidity position)) ERR-ARITHMETIC)
      (get fee-remainder-1 position)) ERR-ARITHMETIC))
  )
    (ok {
      owed0: (unwrap! (safe-add (get tokens-owed-0 position) (/ numerator0 Q)) ERR-ARITHMETIC),
      owed1: (unwrap! (safe-add (get tokens-owed-1 position) (/ numerator1 Q)) ERR-ARITHMETIC),
      remainder0: (mod numerator0 Q), remainder1: (mod numerator1 Q),
      checkpoint0: (get growth0 inside), checkpoint1: (get growth1 inside)
    })))

;; ---- tick initialization ------------------------------------------------

(define-private (tick-list-contains-fold (candidate int) (state { target: int, found: bool }))
  (merge state { found: (or (get found state) (is-eq candidate (get target state))) }))

(define-private (tick-list-contains (items (list 16 int)) (tick int))
  (get found (fold tick-list-contains-fold items { target: tick, found: false })))

(define-private (tick-list-remove-fold
    (candidate int) (state { target: int, items: (list 16 int) }))
  (if (is-eq candidate (get target state))
    state
    ;; The accumulator cannot exceed the source list's length. The fallback is
    ;; unreachable for a list-16 input, but remains explicit and non-panicking.
    (merge state { items: (default-to (get items state)
      (as-max-len? (append (get items state) candidate) u16)) })))

(define-private (tick-list-remove (items (list 16 int)) (tick int))
  (get items (fold tick-list-remove-fold items { target: tick, items: (list) })))

(define-private (upsert-tick
    (pool-id uint) (tick int) (liquidity uint) (net-delta int)
    (pool {
      token-0: principal, token-1: principal, fee-pips: uint, tick-spacing: uint,
      active: bool, sqrt-price: uint, current-tick: int, active-liquidity: uint,
      total-position-liquidity: uint, principal-0: uint, principal-1: uint,
      lp-fee-liability-0: uint, lp-fee-liability-1: uint,
      fee-growth-global-0: uint, fee-growth-global-1: uint,
      protocol-fees-0: uint, protocol-fees-1: uint, fee-dust-0: uint, fee-dust-1: uint,
      initialized-ticks: (list 16 int), initialized-tick-count: uint,
      position-count: uint, audit-height: uint }))
  (let (
    (key { pool-id: pool-id, tick: tick })
    (prior (default-to (empty-tick) (map-get? ticks key)))
    (known (tick-list-contains (get initialized-ticks pool) tick))
  )
    (if (get initialized prior)
      (begin
        (map-set ticks key (merge prior {
          liquidity-gross: (unwrap! (safe-add (get liquidity-gross prior) liquidity) ERR-ARITHMETIC),
          liquidity-net: (+ (get liquidity-net prior) net-delta)
        }))
        (ok pool))
      (begin
        (asserts! (< (get initialized-tick-count pool) MAX-INITIALIZED-TICKS) ERR-TICK-LIMIT)
        (let ((new-list (if known
          (get initialized-ticks pool)
          (unwrap! (as-max-len? (append (get initialized-ticks pool) tick) u16) ERR-TICK-LIMIT))))
          (map-set ticks key {
            initialized: true, liquidity-gross: liquidity, liquidity-net: net-delta,
            fee-growth-outside-0: (if (<= tick (get current-tick pool)) (get fee-growth-global-0 pool) u0),
            fee-growth-outside-1: (if (<= tick (get current-tick pool)) (get fee-growth-global-1 pool) u0)
          })
          (ok (merge pool {
            initialized-ticks: new-list,
            initialized-tick-count: (+ (get initialized-tick-count pool) u1)
          })))))))

(define-private (remove-from-tick (pool-id uint) (tick int) (liquidity uint) (net-delta int))
  (let (
    (key { pool-id: pool-id, tick: tick })
    (prior (unwrap! (map-get? ticks key) ERR-INVALID-TICK))
    (new-gross (unwrap! (safe-sub (get liquidity-gross prior) liquidity) ERR-ARITHMETIC))
    (new-net (- (get liquidity-net prior) net-delta))
  )
    (if (is-eq new-gross u0)
      (begin
        (map-set ticks key (merge prior { initialized: false, liquidity-gross: u0, liquidity-net: 0 }))
        (ok true))
      (begin
        (map-set ticks key (merge prior { liquidity-gross: new-gross, liquidity-net: new-net }))
        (ok false)))))

;; ---- nearest initialized tick search -----------------------------------

(define-private (nearest-tick-fold (candidate int) (state {
    pool-id: uint, zero-for-one: bool, current-tick: int, limit: uint,
    found: bool, best-tick: int, best-sqrt: uint }))
  (let (
    (tick-state (default-to (empty-tick) (map-get? ticks { pool-id: (get pool-id state), tick: candidate })))
    (sqrt (match (contract-call? .concentrated-math-v2 tick-to-sqrt-price candidate)
      value value
      error-code (get limit state)))
    (eligible
      (and (get initialized tick-state)
        (if (get zero-for-one state)
          (and (<= candidate (get current-tick state)) (>= sqrt (get limit state)))
          (and (> candidate (get current-tick state)) (<= sqrt (get limit state))))))
    (better
      (and eligible
        (or (not (get found state))
          (if (get zero-for-one state)
            (> candidate (get best-tick state))
            (< candidate (get best-tick state))))))
  )
    (if better
      (merge state { found: true, best-tick: candidate, best-sqrt: sqrt })
      state)))

(define-private (nearest-tick (pool-id uint) (pool {
    token-0: principal, token-1: principal, fee-pips: uint, tick-spacing: uint,
    active: bool, sqrt-price: uint, current-tick: int, active-liquidity: uint,
    total-position-liquidity: uint, principal-0: uint, principal-1: uint,
    lp-fee-liability-0: uint, lp-fee-liability-1: uint,
    fee-growth-global-0: uint, fee-growth-global-1: uint,
    protocol-fees-0: uint, protocol-fees-1: uint, fee-dust-0: uint, fee-dust-1: uint,
    initialized-ticks: (list 16 int), initialized-tick-count: uint,
    position-count: uint, audit-height: uint })
    (zero-for-one bool) (limit uint))
  (fold nearest-tick-fold (get initialized-ticks pool) {
    pool-id: pool-id, zero-for-one: zero-for-one,
    current-tick: (get current-tick pool), limit: limit,
    found: false, best-tick: 0, best-sqrt: limit
  }))

;; ---- swap engine: fixed fold of eight possible crossings ---------------

(define-private (swap-step (iteration uint) (result (response {
    pool-id: uint, zero-for-one: bool, fee-pips: uint, limit: uint,
    remaining: uint, amount-out: uint, sqrt-price: uint, current-tick: int,
    active-liquidity: uint, crossings: uint,
    principal-0: uint, principal-1: uint,
    liability-0: uint, liability-1: uint,
    growth-0: uint, growth-1: uint,
    protocol-0: uint, protocol-1: uint, dust-0: uint, dust-1: uint
  } uint)))
  (match result state
    (if (is-eq (get remaining state) u0)
      (ok state)
      (begin
        (asserts! (> (get active-liquidity state) u0) ERR-NO-LIQUIDITY)
        (let (
          (pool (unwrap! (map-get? pools (get pool-id state)) ERR-POOL-NOT-FOUND))
          (search (nearest-tick (get pool-id state)
            (merge pool {
              sqrt-price: (get sqrt-price state), current-tick: (get current-tick state),
              active-liquidity: (get active-liquidity state),
              fee-growth-global-0: (get growth-0 state), fee-growth-global-1: (get growth-1 state)
            })
            (get zero-for-one state) (get limit state)))
          (target (if (get found search) (get best-sqrt search) (get limit state)))
          (net-needed
            (if (is-eq target (get sqrt-price state))
              u0
              (if (get zero-for-one state)
                (unwrap! (contract-call? .concentrated-math-v2 amount0-delta
                  target (get sqrt-price state) (get active-liquidity state) true) ERR-ARITHMETIC)
                (unwrap! (contract-call? .concentrated-math-v2 amount1-delta
                  (get sqrt-price state) target (get active-liquidity state) true) ERR-ARITHMETIC))))
          ;; Net input is floored from gross so the inverse ceil can never
          ;; select more gross input than remains in this exact-input step.
          (all-net (/ (unwrap! (safe-mul (get remaining state)
            (- FEE-DENOMINATOR (get fee-pips state))) ERR-ARITHMETIC) FEE-DENOMINATOR))
          (reaches (or
            (and (get found search) (is-eq net-needed u0))
            (and (> net-needed u0) (>= all-net net-needed))))
          (gross-needed (if reaches
            (unwrap! (ceil-div
              (unwrap! (safe-mul net-needed FEE-DENOMINATOR) ERR-ARITHMETIC)
              (- FEE-DENOMINATOR (get fee-pips state))) ERR-ARITHMETIC)
            (get remaining state)))
          (net-used (if reaches net-needed all-net))
          (fee-used (unwrap! (safe-sub gross-needed net-used) ERR-ARITHMETIC))
          (protocol-fee (/ (unwrap! (safe-mul fee-used PROTOCOL-SHARE-BPS) ERR-ARITHMETIC) BPS-DENOMINATOR))
          (lp-fee (unwrap! (safe-sub fee-used protocol-fee) ERR-ARITHMETIC))
          (growth-delta (/ (unwrap! (safe-mul lp-fee Q) ERR-ARITHMETIC) (get active-liquidity state)))
          (distributed (/ (unwrap! (safe-mul growth-delta (get active-liquidity state)) ERR-ARITHMETIC) Q))
          (step-dust (unwrap! (safe-sub lp-fee distributed) ERR-ARITHMETIC))
          (next-price (if reaches
            target
            (if (is-eq net-used u0)
              (get sqrt-price state)
              (if (get zero-for-one state)
                (unwrap! (contract-call? .concentrated-math-v2 next-sqrt-from-token0
                  (get sqrt-price state) (get active-liquidity state) net-used) ERR-PRICE-LIMIT)
                (unwrap! (contract-call? .concentrated-math-v2 next-sqrt-from-token1
                  (get sqrt-price state) (get active-liquidity state) net-used) ERR-PRICE-LIMIT)))))
          (step-output (if (is-eq next-price (get sqrt-price state))
            u0
            (if (get zero-for-one state)
              (unwrap! (contract-call? .concentrated-math-v2 amount1-delta
                next-price (get sqrt-price state) (get active-liquidity state) false) ERR-ARITHMETIC)
              (unwrap! (contract-call? .concentrated-math-v2 amount0-delta
                (get sqrt-price state) next-price (get active-liquidity state) false) ERR-ARITHMETIC))))
          (new-growth0 (if (get zero-for-one state)
            (unwrap! (safe-add (get growth-0 state) growth-delta) ERR-ARITHMETIC)
            (get growth-0 state)))
          (new-growth1 (if (get zero-for-one state)
            (get growth-1 state)
            (unwrap! (safe-add (get growth-1 state) growth-delta) ERR-ARITHMETIC)))
          (will-cross (and reaches (get found search)))
          (cross-tick (get best-tick search))
          (cross-state (default-to (empty-tick) (map-get? ticks { pool-id: (get pool-id state), tick: cross-tick })))
          (new-liquidity (if will-cross
            (if (get zero-for-one state)
              (unwrap! (signed-sub-liquidity (get active-liquidity state) (get liquidity-net cross-state)) ERR-NO-LIQUIDITY)
              (unwrap! (signed-add-liquidity (get active-liquidity state) (get liquidity-net cross-state)) ERR-NO-LIQUIDITY))
            (get active-liquidity state)))
          (new-tick (if will-cross
            (if (get zero-for-one state) (- cross-tick 1) cross-tick)
            (unwrap! (contract-call? .concentrated-math-v2 sqrt-price-to-tick next-price) ERR-INVALID-TICK)))
        )
          (begin
            (asserts! (<= gross-needed (get remaining state)) ERR-ARITHMETIC)
            (asserts! (if (get zero-for-one state)
              (>= next-price (get limit state))
              (<= next-price (get limit state))) ERR-PRICE-LIMIT)
            (if will-cross
              (map-set ticks { pool-id: (get pool-id state), tick: cross-tick }
                (merge cross-state {
                  fee-growth-outside-0: (unwrap! (safe-sub new-growth0 (get fee-growth-outside-0 cross-state)) ERR-ARITHMETIC),
                  fee-growth-outside-1: (unwrap! (safe-sub new-growth1 (get fee-growth-outside-1 cross-state)) ERR-ARITHMETIC)
                }))
              true)
            (ok (merge state {
              remaining: (unwrap! (safe-sub (get remaining state) gross-needed) ERR-ARITHMETIC),
              amount-out: (unwrap! (safe-add (get amount-out state) step-output) ERR-ARITHMETIC),
              sqrt-price: next-price, current-tick: new-tick, active-liquidity: new-liquidity,
              crossings: (if will-cross (+ (get crossings state) u1) (get crossings state)),
              principal-0: (if (get zero-for-one state)
                (unwrap! (safe-add (get principal-0 state) net-used) ERR-ARITHMETIC)
                (unwrap! (safe-sub (get principal-0 state) step-output) ERR-INSUFFICIENT-CUSTODY)),
              principal-1: (if (get zero-for-one state)
                (unwrap! (safe-sub (get principal-1 state) step-output) ERR-INSUFFICIENT-CUSTODY)
                (unwrap! (safe-add (get principal-1 state) net-used) ERR-ARITHMETIC)),
              liability-0: (if (get zero-for-one state)
                (unwrap! (safe-add (get liability-0 state) distributed) ERR-ARITHMETIC)
                (get liability-0 state)),
              liability-1: (if (get zero-for-one state)
                (get liability-1 state)
                (unwrap! (safe-add (get liability-1 state) distributed) ERR-ARITHMETIC)),
              growth-0: new-growth0, growth-1: new-growth1,
              protocol-0: (if (get zero-for-one state)
                (unwrap! (safe-add (get protocol-0 state) protocol-fee) ERR-ARITHMETIC)
                (get protocol-0 state)),
              protocol-1: (if (get zero-for-one state)
                (get protocol-1 state)
                (unwrap! (safe-add (get protocol-1 state) protocol-fee) ERR-ARITHMETIC)),
              dust-0: (if (get zero-for-one state)
                (unwrap! (safe-add (get dust-0 state) step-dust) ERR-ARITHMETIC)
                (get dust-0 state)),
              dust-1: (if (get zero-for-one state)
                (get dust-1 state)
                (unwrap! (safe-add (get dust-1 state) step-dust) ERR-ARITHMETIC))
            }))))))
    error-code (err error-code)))

;; ---- public configuration and reads ------------------------------------

(define-public (set-admin (new-admin principal))
  (begin (asserts! (is-eq contract-caller (var-get admin)) ERR-UNAUTHORIZED)
    (var-set admin new-admin) (ok true)))

(define-public (set-pool-active (pool-id uint) (active bool))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR-UNAUTHORIZED)
    (let ((pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND)))
      (map-set pools pool-id (merge pool { active: active, audit-height: block-height }))
      (ok active))))

(define-read-only (get-pool (pool-id uint)) (map-get? pools pool-id))
(define-read-only (get-tick (pool-id uint) (tick int)) (map-get? ticks { pool-id: pool-id, tick: tick }))
(define-read-only (get-position (position-id uint)) (map-get? positions position-id))

(define-public (create-pool (token-0 principal) (token-1 principal) (fee-pips uint) (initial-tick int))
  (begin
    (asserts! (not (is-eq token-0 token-1)) ERR-INVALID-PAIR)
    (let (
      (spacing (unwrap! (fee-spacing fee-pips) ERR-INVALID-FEE))
      (sqrt-price (unwrap! (contract-call? .concentrated-math-v2 tick-to-sqrt-price initial-tick) ERR-INVALID-TICK))
      (id (+ (var-get pool-nonce) u1))
    )
      (asserts! (is-aligned initial-tick spacing) ERR-INVALID-TICK)
      (map-set pools id {
        token-0: token-0, token-1: token-1, fee-pips: fee-pips, tick-spacing: spacing,
        active: true, sqrt-price: sqrt-price, current-tick: initial-tick,
        active-liquidity: u0, total-position-liquidity: u0,
        principal-0: u0, principal-1: u0,
        lp-fee-liability-0: u0, lp-fee-liability-1: u0,
        fee-growth-global-0: u0, fee-growth-global-1: u0,
        protocol-fees-0: u0, protocol-fees-1: u0, fee-dust-0: u0, fee-dust-1: u0,
        initialized-ticks: (list), initialized-tick-count: u0, position-count: u0,
        audit-height: block-height
      })
      (var-set pool-nonce id)
      (ok id))))

;; Convenience API rejects an uncorrelated caller-provided price.
(define-public (create-pool-checked
    (token-0 principal) (token-1 principal) (fee-pips uint)
    (initial-sqrt-price uint) (initial-tick int))
  (begin
    (asserts! (is-eq initial-sqrt-price
      (unwrap! (contract-call? .concentrated-math-v2 tick-to-sqrt-price initial-tick) ERR-INVALID-TICK)) ERR-INVALID-TICK)
    (create-pool token-0 token-1 fee-pips initial-tick)))

;; ---- liquidity lifecycle ------------------------------------------------

(define-public (add-liquidity
    (pool-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>)
    (lower-tick int) (upper-tick int)
    (max-amount0 uint) (max-amount1 uint) (min-liquidity uint))
  (let (
    (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
    (quote (unwrap! (contract-call? .concentrated-math-v2 quote-position
      (get sqrt-price pool) lower-tick upper-tick max-amount0 max-amount1) ERR-ARITHMETIC))
    (liquidity (get liquidity quote))
    (amount0 (get amount0 quote))
    (amount1 (get amount1 quote))
    (contract-principal (as-contract tx-sender))
    (before0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
    (before1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
    (with-lower (unwrap! (upsert-tick pool-id lower-tick liquidity (to-int liquidity) pool) ERR-TICK-LIMIT))
    (with-ticks (unwrap! (upsert-tick pool-id upper-tick liquidity (* (to-int liquidity) (- 1)) with-lower) ERR-TICK-LIMIT))
    (inside (unwrap! (fee-growth-inside pool-id lower-tick upper-tick pool) ERR-ARITHMETIC))
    (position-id (+ (var-get position-nonce) u1))
  )
    (begin
      (asserts! (get active pool) ERR-POOL-INACTIVE)
      (asserts! (and
        (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR-INVALID-PAIR)
      (asserts! (and (is-aligned lower-tick (get tick-spacing pool))
        (is-aligned upper-tick (get tick-spacing pool)) (< lower-tick upper-tick)) ERR-INVALID-RANGE)
      (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)
        (>= liquidity min-liquidity)
        (<= (+ (get total-position-liquidity pool) liquidity) MAX-LIQUIDITY)) ERR-MINIMUM)
      (if (> amount0 u0)
        (try! (contract-call? token-0 transfer amount0 tx-sender contract-principal none))
        true)
      (if (> amount1 u0)
        (try! (contract-call? token-1 transfer amount1 tx-sender contract-principal none))
        true)
      (let (
        (after0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
        (after1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
      )
        (asserts! (and
          (is-eq after0 (unwrap! (safe-add before0 amount0) ERR-ARITHMETIC))
          (is-eq after1 (unwrap! (safe-add before1 amount1) ERR-ARITHMETIC))) ERR-CUSTODY-DELTA)
        (map-set pools pool-id (merge with-ticks {
          active-liquidity: (if (in-range (get current-tick pool) lower-tick upper-tick)
            (unwrap! (safe-add (get active-liquidity pool) liquidity) ERR-ARITHMETIC)
            (get active-liquidity pool)),
          total-position-liquidity: (+ (get total-position-liquidity pool) liquidity),
          principal-0: (+ (get principal-0 pool) amount0),
          principal-1: (+ (get principal-1 pool) amount1),
          position-count: (+ (get position-count pool) u1), audit-height: block-height
        }))
        (let (
          (asset0 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-0 pool))))
          (asset1 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-1 pool))))
        )
          (map-set asset-accounting (get token-0 pool)
            (merge asset0 { principal: (+ (get principal asset0) amount0) }))
          (map-set asset-accounting (get token-1 pool)
            (merge asset1 { principal: (+ (get principal asset1) amount1) })))
        (map-set positions position-id {
          owner: tx-sender, pool-id: pool-id, lower-tick: lower-tick, upper-tick: upper-tick,
          liquidity: liquidity, active: true, closed: false,
          fee-growth-inside-checkpoint-0: (get growth0 inside),
          fee-growth-inside-checkpoint-1: (get growth1 inside),
          tokens-owed-0: u0, tokens-owed-1: u0, fee-remainder-0: u0, fee-remainder-1: u0,
          deposited-0: amount0, deposited-1: amount1, entry-sqrt-price: (get sqrt-price pool),
          cumulative-settled-0: u0, cumulative-settled-1: u0,
          close-sqrt-price: u0, opened-height: block-height, closed-height: u0
        })
        (var-set position-nonce position-id)
        (ok { position-id: position-id, liquidity: liquidity, amount0: amount0, amount1: amount1 })))))

(define-public (collect-fees
    (position-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>)
    (recipient principal))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR-POSITION-NOT-FOUND))
    (pool (unwrap! (map-get? pools (get pool-id position)) ERR-POOL-NOT-FOUND))
    (inside (unwrap! (fee-growth-inside (get pool-id position)
      (get lower-tick position) (get upper-tick position) pool) ERR-ARITHMETIC))
    (fees (unwrap! (settled-fees position inside) ERR-ARITHMETIC))
    (owed0 (get owed0 fees)) (owed1 (get owed1 fees))
    (contract-principal (as-contract tx-sender))
    (before0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
    (before1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
  )
    (begin
      (asserts! (and (get active position) (not (get closed position))) ERR-POSITION-CLOSED)
      (asserts! (is-eq tx-sender (get owner position)) ERR-UNAUTHORIZED)
      (asserts! (and (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR-INVALID-PAIR)
      (asserts! (and (<= owed0 (get lp-fee-liability-0 pool))
        (<= owed1 (get lp-fee-liability-1 pool))) ERR-INSUFFICIENT-CUSTODY)
      (if (> owed0 u0)
        (try! (as-contract (contract-call? token-0 transfer owed0 contract-principal recipient none))) true)
      (if (> owed1 u0)
        (try! (as-contract (contract-call? token-1 transfer owed1 contract-principal recipient none))) true)
      (let (
        (after0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
        (after1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
      )
        (asserts! (and
          (is-eq after0 (unwrap! (safe-sub before0 owed0) ERR-CUSTODY-DELTA))
          (is-eq after1 (unwrap! (safe-sub before1 owed1) ERR-CUSTODY-DELTA))) ERR-CUSTODY-DELTA)
        (map-set pools (get pool-id position) (merge pool {
          lp-fee-liability-0: (- (get lp-fee-liability-0 pool) owed0),
          lp-fee-liability-1: (- (get lp-fee-liability-1 pool) owed1), audit-height: block-height
        }))
        (let (
          (asset0 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-0 pool))))
          (asset1 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-1 pool))))
        )
          (map-set asset-accounting (get token-0 pool)
            (merge asset0 { lp-fee-liability: (- (get lp-fee-liability asset0) owed0) }))
          (map-set asset-accounting (get token-1 pool)
            (merge asset1 { lp-fee-liability: (- (get lp-fee-liability asset1) owed1) })))
        (map-set positions position-id (merge position {
          fee-growth-inside-checkpoint-0: (get checkpoint0 fees),
          fee-growth-inside-checkpoint-1: (get checkpoint1 fees),
          tokens-owed-0: u0, tokens-owed-1: u0,
          fee-remainder-0: (get remainder0 fees), fee-remainder-1: (get remainder1 fees),
          cumulative-settled-0: (+ (get cumulative-settled-0 position) owed0),
          cumulative-settled-1: (+ (get cumulative-settled-1 position) owed1)
        }))
        (ok { amount0: owed0, amount1: owed1 })))))

(define-public (remove-liquidity
    (position-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>)
    (min-amount0 uint) (min-amount1 uint) (recipient principal))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR-POSITION-NOT-FOUND))
    (position-open (asserts! (and (get active position) (not (get closed position))) ERR-POSITION-CLOSED))
    (position-owned (asserts! (is-eq tx-sender (get owner position)) ERR-UNAUTHORIZED))
    (pool (unwrap! (map-get? pools (get pool-id position)) ERR-POOL-NOT-FOUND))
    (principal (unwrap! (contract-call? .concentrated-math-v2 principal-at-price
      (get sqrt-price pool) (get lower-tick position) (get upper-tick position)
      (get liquidity position)) ERR-ARITHMETIC))
    (inside (unwrap! (fee-growth-inside (get pool-id position)
      (get lower-tick position) (get upper-tick position) pool) ERR-ARITHMETIC))
    (fees (unwrap! (settled-fees position inside) ERR-ARITHMETIC))
    (principal0 (get amount0 principal)) (principal1 (get amount1 principal))
    (fee0 (get owed0 fees)) (fee1 (get owed1 fees))
    (amount0 (+ principal0 fee0)) (amount1 (+ principal1 fee1))
    (contract-principal (as-contract tx-sender))
    (before0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
    (before1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
    (lower-deinit (unwrap! (remove-from-tick (get pool-id position) (get lower-tick position)
      (get liquidity position) (to-int (get liquidity position))) ERR-ARITHMETIC))
    (upper-deinit (unwrap! (remove-from-tick (get pool-id position) (get upper-tick position)
      (get liquidity position) (* (to-int (get liquidity position)) (- 1))) ERR-ARITHMETIC))
  )
    (begin
      (asserts! (and (get active position) (not (get closed position))) ERR-POSITION-CLOSED)
      (asserts! (is-eq tx-sender (get owner position)) ERR-UNAUTHORIZED)
      (asserts! (and (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR-INVALID-PAIR)
      (asserts! (and (>= amount0 min-amount0) (>= amount1 min-amount1)) ERR-MINIMUM)
      (asserts! (and (<= principal0 (get principal-0 pool)) (<= principal1 (get principal-1 pool))
        (<= fee0 (get lp-fee-liability-0 pool)) (<= fee1 (get lp-fee-liability-1 pool))) ERR-INSUFFICIENT-CUSTODY)
      (if (> amount0 u0)
        (try! (as-contract (contract-call? token-0 transfer amount0 contract-principal recipient none))) true)
      (if (> amount1 u0)
        (try! (as-contract (contract-call? token-1 transfer amount1 contract-principal recipient none))) true)
      (let (
        (after0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
        (after1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
      )
        (asserts! (and
          (is-eq after0 (unwrap! (safe-sub before0 amount0) ERR-CUSTODY-DELTA))
          (is-eq after1 (unwrap! (safe-sub before1 amount1) ERR-CUSTODY-DELTA))) ERR-CUSTODY-DELTA)
        (map-set pools (get pool-id position) (merge pool {
          active-liquidity: (if (in-range (get current-tick pool) (get lower-tick position) (get upper-tick position))
            (- (get active-liquidity pool) (get liquidity position)) (get active-liquidity pool)),
          total-position-liquidity: (- (get total-position-liquidity pool) (get liquidity position)),
          principal-0: (- (get principal-0 pool) principal0), principal-1: (- (get principal-1 pool) principal1),
          lp-fee-liability-0: (- (get lp-fee-liability-0 pool) fee0),
          lp-fee-liability-1: (- (get lp-fee-liability-1 pool) fee1),
          initialized-ticks: (if upper-deinit
            (tick-list-remove
              (if lower-deinit
                (tick-list-remove (get initialized-ticks pool) (get lower-tick position))
                (get initialized-ticks pool))
              (get upper-tick position))
            (if lower-deinit
              (tick-list-remove (get initialized-ticks pool) (get lower-tick position))
              (get initialized-ticks pool))),
          initialized-tick-count: (- (get initialized-tick-count pool)
            (+ (if lower-deinit u1 u0) (if upper-deinit u1 u0))),
          position-count: (- (get position-count pool) u1), audit-height: block-height
        }))
        (let (
          (asset0 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-0 pool))))
          (asset1 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-1 pool))))
        )
          (map-set asset-accounting (get token-0 pool) (merge asset0 {
            principal: (- (get principal asset0) principal0),
            lp-fee-liability: (- (get lp-fee-liability asset0) fee0)
          }))
          (map-set asset-accounting (get token-1 pool) (merge asset1 {
            principal: (- (get principal asset1) principal1),
            lp-fee-liability: (- (get lp-fee-liability asset1) fee1)
          })))
        (map-set positions position-id (merge position {
          active: false, closed: true,
          fee-growth-inside-checkpoint-0: (get checkpoint0 fees),
          fee-growth-inside-checkpoint-1: (get checkpoint1 fees),
          tokens-owed-0: u0, tokens-owed-1: u0,
          fee-remainder-0: (get remainder0 fees), fee-remainder-1: (get remainder1 fees),
          cumulative-settled-0: (+ (get cumulative-settled-0 position) amount0),
          cumulative-settled-1: (+ (get cumulative-settled-1 position) amount1),
          close-sqrt-price: (get sqrt-price pool), closed-height: block-height
        }))
        (ok { amount0: amount0, amount1: amount1, principal0: principal0, principal1: principal1,
          fees0: fee0, fees1: fee1 })))))

;; ---- exact-input single-hop swap ---------------------------------------

(define-public (swap-exact-input
    (pool-id uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>)
    (zero-for-one bool) (amount-in uint) (sqrt-price-limit uint)
    (min-amount-out uint) (recipient principal))
  (let (
    (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
    (contract-principal (as-contract tx-sender))
  )
    (begin
      (asserts! (get active pool) ERR-POOL-INACTIVE)
      (asserts! (and (> amount-in u0) (<= amount-in MAX-AMOUNT)) ERR-INVALID-AMOUNT)
      (asserts! (> (get active-liquidity pool) u0) ERR-NO-LIQUIDITY)
      (asserts! (contract-call? .concentrated-math-v2 is-valid-sqrt-price sqrt-price-limit) ERR-PRICE-LIMIT)
      (asserts! (if zero-for-one
        (and (is-eq (contract-of token-in) (get token-0 pool))
          (is-eq (contract-of token-out) (get token-1 pool))
          (< sqrt-price-limit (get sqrt-price pool)))
        (and (is-eq (contract-of token-in) (get token-1 pool))
          (is-eq (contract-of token-out) (get token-0 pool))
          (> sqrt-price-limit (get sqrt-price pool)))) ERR-INVALID-PAIR)
      (let (
        (steps (fold swap-step (list u0 u1 u2 u3 u4 u5 u6 u7) (ok {
          pool-id: pool-id, zero-for-one: zero-for-one, fee-pips: (get fee-pips pool), limit: sqrt-price-limit,
          remaining: amount-in, amount-out: u0, sqrt-price: (get sqrt-price pool), current-tick: (get current-tick pool),
          active-liquidity: (get active-liquidity pool), crossings: u0,
          principal-0: (get principal-0 pool), principal-1: (get principal-1 pool),
          liability-0: (get lp-fee-liability-0 pool), liability-1: (get lp-fee-liability-1 pool),
          growth-0: (get fee-growth-global-0 pool), growth-1: (get fee-growth-global-1 pool),
          protocol-0: (get protocol-fees-0 pool), protocol-1: (get protocol-fees-1 pool),
          dust-0: (get fee-dust-0 pool), dust-1: (get fee-dust-1 pool)
        })))
        (final (unwrap! steps ERR-ARITHMETIC))
        (amount-out (get amount-out final))
        (before-in (unwrap! (contract-call? token-in get-balance contract-principal) ERR-TRANSFER))
        (before-out (unwrap! (contract-call? token-out get-balance contract-principal) ERR-TRANSFER))
      )
        (begin
          (asserts! (is-eq (get remaining final) u0) ERR-EXACT-INPUT-NOT-CONSUMED)
          (asserts! (<= (get crossings final) MAX-CROSSINGS) ERR-TOO-MANY-CROSSINGS)
          (asserts! (> amount-out u0) ERR-ZERO-OUTPUT)
          (asserts! (>= amount-out min-amount-out) ERR-MINIMUM)
          (try! (contract-call? token-in transfer amount-in tx-sender contract-principal none))
          (try! (as-contract (contract-call? token-out transfer amount-out contract-principal recipient none)))
          (let (
            (after-in (unwrap! (contract-call? token-in get-balance contract-principal) ERR-TRANSFER))
            (after-out (unwrap! (contract-call? token-out get-balance contract-principal) ERR-TRANSFER))
          )
            (asserts! (and
              (is-eq after-in (+ before-in amount-in))
              (is-eq after-out (- before-out amount-out))) ERR-CUSTODY-DELTA)
            (map-set pools pool-id (merge pool {
              sqrt-price: (get sqrt-price final), current-tick: (get current-tick final),
              active-liquidity: (get active-liquidity final),
              principal-0: (get principal-0 final), principal-1: (get principal-1 final),
              lp-fee-liability-0: (get liability-0 final), lp-fee-liability-1: (get liability-1 final),
              fee-growth-global-0: (get growth-0 final), fee-growth-global-1: (get growth-1 final),
              protocol-fees-0: (get protocol-0 final), protocol-fees-1: (get protocol-1 final),
              fee-dust-0: (get dust-0 final), fee-dust-1: (get dust-1 final), audit-height: block-height
            }))
            (let (
              (asset0 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-0 pool))))
              (asset1 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-1 pool))))
            )
              (map-set asset-accounting (get token-0 pool) (merge asset0 {
                principal: (if zero-for-one
                  (+ (get principal asset0) (- (get principal-0 final) (get principal-0 pool)))
                  (- (get principal asset0) (- (get principal-0 pool) (get principal-0 final)))),
                lp-fee-liability: (+ (get lp-fee-liability asset0)
                  (- (get liability-0 final) (get lp-fee-liability-0 pool))),
                protocol-fees: (+ (get protocol-fees asset0)
                  (- (get protocol-0 final) (get protocol-fees-0 pool))),
                fee-dust: (+ (get fee-dust asset0) (- (get dust-0 final) (get fee-dust-0 pool)))
              }))
              (map-set asset-accounting (get token-1 pool) (merge asset1 {
                principal: (if zero-for-one
                  (- (get principal asset1) (- (get principal-1 pool) (get principal-1 final)))
                  (+ (get principal asset1) (- (get principal-1 final) (get principal-1 pool)))),
                lp-fee-liability: (+ (get lp-fee-liability asset1)
                  (- (get liability-1 final) (get lp-fee-liability-1 pool))),
                protocol-fees: (+ (get protocol-fees asset1)
                  (- (get protocol-1 final) (get protocol-fees-1 pool))),
                fee-dust: (+ (get fee-dust asset1) (- (get dust-1 final) (get fee-dust-1 pool)))
              })))
            (ok { amount-in: amount-in, amount-out: amount-out,
              sqrt-price: (get sqrt-price final), current-tick: (get current-tick final),
              crossings: (get crossings final) })))))))

;; ---- reconciliation and exact PnL/IL views -----------------------------

(define-public (get-reconciliation
    (pool-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>))
  (let (
    (pool (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
    (contract-principal SELF)
    (custody0 (unwrap! (contract-call? token-0 get-balance contract-principal) ERR-TRANSFER))
    (custody1 (unwrap! (contract-call? token-1 get-balance contract-principal) ERR-TRANSFER))
    (asset0 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-0 pool))))
    (asset1 (default-to (empty-asset-accounting) (map-get? asset-accounting (get token-1 pool))))
    (tracked0 (+ (get principal asset0) (get lp-fee-liability asset0)
      (get protocol-fees asset0) (get fee-dust asset0)))
    (tracked1 (+ (get principal asset1) (get lp-fee-liability asset1)
      (get protocol-fees asset1) (get fee-dust asset1)))
  )
    (begin
      (asserts! (and (is-eq (contract-of token-0) (get token-0 pool))
        (is-eq (contract-of token-1) (get token-1 pool))) ERR-INVALID-PAIR)
      (ok {
        principal-0: (get principal-0 pool), principal-1: (get principal-1 pool),
        unpaid-lp-fees-0: (get lp-fee-liability-0 pool), unpaid-lp-fees-1: (get lp-fee-liability-1 pool),
        protocol-fees-0: (get protocol-fees-0 pool), protocol-fees-1: (get protocol-fees-1 pool),
        dust-0: (get fee-dust-0 pool), dust-1: (get fee-dust-1 pool),
        asset-wide-principal-0: (get principal asset0), asset-wide-principal-1: (get principal asset1),
        asset-wide-unpaid-lp-fees-0: (get lp-fee-liability asset0),
        asset-wide-unpaid-lp-fees-1: (get lp-fee-liability asset1),
        asset-wide-protocol-fees-0: (get protocol-fees asset0),
        asset-wide-protocol-fees-1: (get protocol-fees asset1),
        asset-wide-dust-0: (get fee-dust asset0), asset-wide-dust-1: (get fee-dust asset1),
        custody-0: custody0, custody-1: custody1,
        donation-surplus-0: (if (> custody0 tracked0) (- custody0 tracked0) u0),
        donation-surplus-1: (if (> custody1 tracked1) (- custody1 tracked1) u0),
        custody-shortfall-0: (if (< custody0 tracked0) (- tracked0 custody0) u0),
        custody-shortfall-1: (if (< custody1 tracked1) (- tracked1 custody1) u0)
      }))))

(define-read-only (get-position-pnl (position-id uint))
  (let (
    (position (unwrap! (map-get? positions position-id) ERR-POSITION-NOT-FOUND))
    (pool (unwrap! (map-get? pools (get pool-id position)) ERR-POOL-NOT-FOUND))
    (valuation-sqrt (if (get closed position) (get close-sqrt-price position) (get sqrt-price pool)))
    (price (unwrap! (contract-call? .concentrated-math-v2 price-token1-per-token0 valuation-sqrt) ERR-ARITHMETIC))
    (principal (if (get closed position)
      { amount0: (get cumulative-settled-0 position), amount1: (get cumulative-settled-1 position) }
      (unwrap! (contract-call? .concentrated-math-v2 principal-at-price valuation-sqrt
        (get lower-tick position) (get upper-tick position) (get liquidity position)) ERR-ARITHMETIC)))
    (inside (if (get closed position)
      { growth0: (get fee-growth-inside-checkpoint-0 position), growth1: (get fee-growth-inside-checkpoint-1 position) }
      (unwrap! (fee-growth-inside (get pool-id position) (get lower-tick position) (get upper-tick position) pool) ERR-ARITHMETIC)))
    (fees (if (get closed position)
      { owed0: u0, owed1: u0, remainder0: (get fee-remainder-0 position), remainder1: (get fee-remainder-1 position),
        checkpoint0: (get fee-growth-inside-checkpoint-0 position), checkpoint1: (get fee-growth-inside-checkpoint-1 position) }
      (unwrap! (settled-fees position inside) ERR-ARITHMETIC)))
    (hodl-value (+ (get deposited-1 position) (/ (* (get deposited-0 position) price) Q)))
    (principal-value (+ (get amount1 principal) (/ (* (get amount0 principal) price) Q)))
    (fee-value (+ (get owed1 fees) (/ (* (get owed0 fees) price) Q)))
    (net-value (+ principal-value fee-value))
    (underperforms (< net-value hodl-value))
    (difference (if underperforms (- hodl-value net-value) (- net-value hodl-value)))
    (entry-price (unwrap! (contract-call? .concentrated-math-v2 price-token1-per-token0
      (get entry-sqrt-price position)) ERR-ARITHMETIC))
  )
    (ok {
      hodl-value-token1: hodl-value, lp-principal-value-token1: principal-value,
      claimable-fee-value-token1: fee-value, net-lp-value-token1: net-value,
      pnl-negative: underperforms, pnl-magnitude-token1: difference,
      loss-only-il-token1: (if underperforms difference u0),
      outperformance-token1: (if underperforms u0 difference),
      entry-price-token1-per-token0: entry-price,
      current-or-close-price-token1-per-token0: price,
      entry-sqrt-price: (get entry-sqrt-price position), valuation-sqrt-price: valuation-sqrt,
      price-scale: Q, sqrt-price-scale: Q,
      price-source: "pool-executable-state", calculation-version: "clp-v2-linear-v1",
      closed: (get closed position)
    })))

(define-read-only (get-exact-il (position-id uint)) (get-position-pnl position-id))

;; Protocol fees are intentionally locked until the collector's source-custody
;; callback can be wired with a private same-transaction pending debit and
;; exact custody-delta proof. There is no admin sweep and no no-op success.
(define-read-only (get-protocol-fee-release-status)
  { enabled: false, collector: none, reason: "collector-callback-not-wired" })
(define-public (release-protocol-fees-disabled)
  ERR-PROTOCOL-RELEASE-DISABLED)

;; Stable fail-closed compatibility surface. V2 never fabricates health,
;; markers, yield, flash liquidity, arbitrage, or an implicit pool u1 route.
(define-public (register-liquidity-marker (marker (string-ascii 256))) ERR-COMPATIBILITY-UNAVAILABLE)
(define-public (execute-csf-swap
    (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>)
    (amount-in uint) (recipient principal)) ERR-COMPATIBILITY-UNAVAILABLE)
(define-public (request-flash-liquidity
    (token <sip-010-ft-trait>) (amount uint) (payload (buff 32))) ERR-COMPATIBILITY-UNAVAILABLE)
(define-public (settle-arbitrage
    (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>)
    (amount uint) (route (list 10 principal))) ERR-COMPATIBILITY-UNAVAILABLE)
(define-public (claim-conxian-yield
    (reward-token <sip-010-ft-trait>) (amount uint) (recipient principal)) ERR-COMPATIBILITY-UNAVAILABLE)
(define-public (get-csf-health) ERR-COMPATIBILITY-UNAVAILABLE)
