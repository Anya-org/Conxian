;; dual-stacking-orchestrator.clar
;; Accounting/policy coordinator for delegated PoX plus a configurable SIP-010
;; native token. The native token is injected at runtime; CXD is a valid
;; initial configuration but is not hardcoded here.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait stacking-adapter-trait .stacking-traits.stacking-adapter-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u1100))
(define-constant ERR_NOT_INITIALIZED (err u1101))
(define-constant ERR_ALREADY_INITIALIZED (err u1102))
(define-constant ERR_PAUSED (err u1103))
(define-constant ERR_INVALID_TOKEN (err u1104))
(define-constant ERR_INVALID_AMOUNT (err u1105))
(define-constant ERR_ADAPTER_NOT_FOUND (err u1106))
(define-constant ERR_ADAPTER_MISMATCH (err u1107))
(define-constant ERR_ADAPTER_INACTIVE (err u1108))
(define-constant ERR_INVALID_RISK (err u1109))
(define-constant ERR_EXPOSURE_CAP (err u1110))
(define-constant ERR_POSITION_NOT_FOUND (err u1111))
(define-constant ERR_POSITION_OWNER (err u1112))
(define-constant ERR_POSITION_STATE (err u1113))
(define-constant ERR_UNLOCK_NOT_MATURED (err u1114))
(define-constant ERR_ALREADY_CLAIMED (err u1115))
(define-constant ERR_LIQUIDITY_RESERVE (err u1116))
(define-constant ERR_REWARD_NOT_FOUND (err u1117))
(define-constant ERR_REWARD_REPLAYED (err u1118))
(define-constant ERR_BTC_PROOF_REPLAYED (err u1119))
(define-constant ERR_BTC_ENTITLEMENT_NOT_FOUND (err u1120))
(define-constant ERR_INVALID_CYCLE (err u1121))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1122))
(define-constant ERR_PAYOUT_NOT_CONFIGURED (err u1123))

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant BPS u10000)

(define-constant POSITION_ACTIVE u0)
(define-constant POSITION_NATIVE_UNLOCKING u1)
(define-constant POSITION_NATIVE_UNLOCKED u2)
(define-constant POSITION_CLOSED u3)

;; --- Configuration ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)
(define-data-var paused bool false)
(define-data-var native-token principal tx-sender)
(define-data-var native-token-configured bool false)
(define-data-var reward-token principal tx-sender)
(define-data-var reward-token-configured bool false)
(define-data-var native-operator principal tx-sender)
(define-data-var native-operator-configured bool false)
(define-data-var next-position-id uint u1)
(define-data-var reward-cycle uint u0)
(define-data-var max-total-exposure uint MAX_UINT)
(define-data-var total-exposure uint u0)
(define-data-var total-risk-exposure uint u0)
(define-data-var liquid-reserve uint u0)
(define-data-var stx-liquid-reserve uint u0)
(define-data-var native-cooldown uint u144)

;; --- Adapter and position state ---
(define-map adapters principal {
  risk-bps: uint,
  max-exposure: uint,
  exposure: uint,
  risk-exposure: uint,
  active: bool
})

(define-map positions uint {
  owner: principal,
  stx-amount: uint,
  native-amount: uint,
  weight: uint,
  adapter: principal,
  reward-cycle: uint,
  status: uint,
  opened-at: uint,
  native-unlock-height: uint,
  native-claimed: bool,
  pox-cycle-id: uint,
  pox-unlock-height: uint,
  pox-commit-id: uint,
  pox-unlocked: bool
})

(define-map cycle-weights uint uint)

;; --- Reward state ---
(define-map reward-pools { cycle-id: uint, token: principal } {
  total: uint,
  claimed: uint,
  claims-closed: bool
})
(define-map reward-claims { position-id: uint, cycle-id: uint, token: principal } bool)

(define-map stx-reward-pools uint {
  total: uint,
  claimed: uint,
  claims-closed: bool
})
(define-map stx-reward-claims { position-id: uint, cycle-id: uint } bool)

;; BTC entitlements are accounting-only records. A proof hash can back only
;; one position in this contract and can be claimed only once.
(define-map btc-entitlements uint {
  cycle-id: uint,
  amount: uint,
  proof-hash: (buff 32),
  recorded-at: uint,
  claimed: bool
})
(define-map btc-proofs (buff 32) uint)

;; --- Helpers ---
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-authorized-operator)
  (or
    (is-admin)
    (and (var-get native-operator-configured) (is-eq tx-sender (var-get native-operator)))
  )
)

(define-private (is-native-token (token <sip-010-ft-trait>))
  (and (var-get native-token-configured) (is-eq (contract-of token) (var-get native-token)))
)

(define-private (is-reward-token (token <sip-010-ft-trait>))
  (and (var-get reward-token-configured) (is-eq (contract-of token) (var-get reward-token)))
)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right))
  )
)

(define-private (safe-sub (left uint) (right uint))
  (if (< left right)
    none
    (some (- left right))
  )
)

;; Bounded multiplication/division that avoids multiplying the full numerator
;; before division. The optional result makes overflow explicit to callers.
(define-private (safe-mul-div (left uint) (right uint) (denominator uint))
  (if (or (is-eq left u0) (is-eq right u0) (is-eq denominator u0))
    (if (is-eq denominator u0) none (some u0))
    (let (
        (whole-left (/ left denominator))
        (remainder-left (mod left denominator))
      )
      (if (> whole-left (/ MAX_UINT right))
        none
        (let ((whole-product (* whole-left right)))
          (if (> remainder-left (/ MAX_UINT right))
            none
            (let ((fraction-product (* remainder-left right)))
              (if (> whole-product (- MAX_UINT (/ fraction-product denominator)))
                none
                (some (+ whole-product (/ fraction-product denominator)))
              )
            )
          )
        )
      )
    )
  )
)

(define-private (adapter-for (adapter <stacking-adapter-trait>))
  (map-get? adapters (contract-of adapter))
)

(define-private (position-or-error (position-id uint))
  (map-get? positions position-id)
)

(define-private (reward-pool-or-empty (cycle-id uint) (token principal))
  (default-to { total: u0, claimed: u0, claims-closed: false }
    (map-get? reward-pools { cycle-id: cycle-id, token: token }))
)

(define-private (stx-reward-pool-or-empty (cycle-id uint))
  (default-to { total: u0, claimed: u0, claims-closed: false }
    (map-get? stx-reward-pools cycle-id))
)

(define-private (required-token-balance (amount uint) (reserve uint))
  (safe-add amount reserve)
)

;; --- Initialization and policy controls ---

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (print { event: "dual-stacking-orchestrator-initialized", admin: new-admin })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (print { event: "dual-stacking-orchestrator-admin-updated", admin: new-admin })
    (ok true)
  )
)

(define-public (set-native-token (token principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set native-token token)
    (var-set native-token-configured true)
    (print { event: "dual-stacking-native-token-configured", token: token })
    (ok true)
  )
)

(define-public (set-reward-token (token principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set reward-token token)
    (var-set reward-token-configured true)
    (print { event: "dual-stacking-reward-token-configured", token: token })
    (ok true)
  )
)

(define-public (set-native-operator (operator-principal principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set native-operator operator-principal)
    (var-set native-operator-configured true)
    (print { event: "dual-stacking-native-operator-configured", operator: operator-principal })
    (ok true)
  )
)

(define-public (set-paused (should-pause bool))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set paused should-pause)
    (print { event: "dual-stacking-pause-updated", paused: should-pause })
    (ok true)
  )
)

(define-public (set-reward-cycle (cycle-id uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (< cycle-id MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
    (var-set reward-cycle cycle-id)
    (print { event: "dual-stacking-reward-cycle-updated", cycle-id: cycle-id })
    (ok true)
  )
)

(define-public (set-allocation-cap (cap uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (> cap u0) ERR_INVALID_AMOUNT)
    (asserts! (<= (var-get total-exposure) cap) ERR_EXPOSURE_CAP)
    (var-set max-total-exposure cap)
    (print { event: "dual-stacking-allocation-cap-updated", cap: cap })
    (ok true)
  )
)

(define-public (set-liquid-reserve (native-reserve uint) (stx-reserve uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set liquid-reserve native-reserve)
    (var-set stx-liquid-reserve stx-reserve)
    (print {
      event: "dual-stacking-liquid-reserve-updated",
      native-reserve: native-reserve,
      stx-reserve: stx-reserve
    })
    (ok true)
  )
)

(define-public (set-native-cooldown (cooldown uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (> cooldown u0) ERR_INVALID_AMOUNT)
    (var-set native-cooldown cooldown)
    (print { event: "dual-stacking-native-cooldown-updated", cooldown: cooldown })
    (ok true)
  )
)

;; --- Adapter registry and exposure policy ---

(define-public (register-adapter
    (adapter <stacking-adapter-trait>)
    (risk-bps uint)
    (max-exposure uint)
  )
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? adapters (contract-of adapter))) ERR_ADAPTER_MISMATCH)
    (asserts! (<= risk-bps BPS) ERR_INVALID_RISK)
    (asserts! (> max-exposure u0) ERR_INVALID_AMOUNT)
    (asserts! (try! (contract-call? adapter is-active)) ERR_ADAPTER_INACTIVE)
    (asserts! (<= risk-bps (try! (contract-call? adapter get-risk-bps))) ERR_INVALID_RISK)
    (asserts! (<= max-exposure (try! (contract-call? adapter get-max-exposure))) ERR_EXPOSURE_CAP)
    (map-set adapters (contract-of adapter) {
      risk-bps: risk-bps,
      max-exposure: max-exposure,
      exposure: u0,
      risk-exposure: u0,
      active: true
    })
    (print {
      event: "dual-stacking-adapter-registered",
      adapter: (contract-of adapter),
      risk-bps: risk-bps,
      max-exposure: max-exposure
    })
    (ok true)
  )
)

(define-public (set-adapter-active (adapter <stacking-adapter-trait>) (active bool))
  (let ((config (unwrap! (adapter-for adapter) ERR_ADAPTER_NOT_FOUND)))
    (begin
      (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
      (asserts! (is-admin) ERR_UNAUTHORIZED)
      (map-set adapters (contract-of adapter) (merge config { active: active }))
      (print { event: "dual-stacking-adapter-status-updated", adapter: (contract-of adapter), active: active })
      (ok true)
    )
  )
)

;; --- Position lifecycle ---

;; @desc Open one dual position. STX is delegated/accounted by the operator;
;; only the configured SIP-010 native token is transferred into custody.
(define-public (open-position
    (adapter <stacking-adapter-trait>)
    (stx-amount uint)
    (native-amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-native-token token) ERR_INVALID_TOKEN)
    (asserts! (> stx-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> native-amount u0) ERR_INVALID_AMOUNT)
    (let (
        (config (unwrap! (adapter-for adapter) ERR_ADAPTER_NOT_FOUND))
        (position-id (var-get next-position-id))
        (weight (unwrap! (safe-add stx-amount native-amount) ERR_ARITHMETIC_OVERFLOW))
        (new-total-exposure (unwrap! (safe-add (var-get total-exposure) native-amount) ERR_ARITHMETIC_OVERFLOW))
        (new-adapter-exposure (unwrap! (safe-add (get exposure config) native-amount) ERR_ARITHMETIC_OVERFLOW))
        (risk-add (unwrap! (safe-mul-div native-amount (get risk-bps config) BPS) ERR_ARITHMETIC_OVERFLOW))
        (new-risk-exposure (unwrap! (safe-add (var-get total-risk-exposure) risk-add) ERR_ARITHMETIC_OVERFLOW))
        (new-adapter-risk (unwrap! (safe-add (get risk-exposure config) risk-add) ERR_ARITHMETIC_OVERFLOW))
        (new-cycle-weight (unwrap! (safe-add
          (default-to u0 (map-get? cycle-weights (var-get reward-cycle)))
          weight
        ) ERR_ARITHMETIC_OVERFLOW))
      )
      (begin
        (asserts! (get active config) ERR_ADAPTER_INACTIVE)
        (asserts! (<= new-total-exposure (var-get max-total-exposure)) ERR_EXPOSURE_CAP)
        (asserts! (<= new-adapter-exposure (get max-exposure config)) ERR_EXPOSURE_CAP)
        (asserts! (< position-id MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
        ;; External failure reverts this token transfer and every subsequent
        ;; state write in the transaction.
        (try! (contract-call? token transfer native-amount tx-sender (as-contract tx-sender) none))
        (try! (contract-call? adapter prepare-stake position-id native-amount tx-sender))
        (map-set positions position-id {
          owner: tx-sender,
          stx-amount: stx-amount,
          native-amount: native-amount,
          weight: weight,
          adapter: (contract-of adapter),
          reward-cycle: (var-get reward-cycle),
          status: POSITION_ACTIVE,
          opened-at: burn-block-height,
          native-unlock-height: u0,
          native-claimed: false,
          pox-cycle-id: u0,
          pox-unlock-height: u0,
          pox-commit-id: u0,
          pox-unlocked: false
        })
        (map-set adapters (contract-of adapter) (merge config {
          exposure: new-adapter-exposure,
          risk-exposure: new-adapter-risk
        }))
        (map-set cycle-weights (var-get reward-cycle) new-cycle-weight)
        (var-set total-exposure new-total-exposure)
        (var-set total-risk-exposure new-risk-exposure)
        (var-set next-position-id (+ position-id u1))
        (print {
          event: "dual-stacking-position-opened",
          position-id: position-id,
          owner: tx-sender,
          stx-amount: stx-amount,
          native-amount: native-amount,
          adapter: (contract-of adapter),
          reward-cycle: (var-get reward-cycle)
        })
        (ok position-id)
      )
    )
  )
)

;; Compatibility name for callers that prefer the issue's original wording.
(define-public (stake-dual
    (adapter <stacking-adapter-trait>)
    (stx-amount uint)
    (native-amount uint)
    (token <sip-010-ft-trait>)
  )
  (open-position adapter stx-amount native-amount token)
)

(define-public (request-native-unstake (position-id uint) (adapter <stacking-adapter-trait>))
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER)
      (asserts! (is-eq (get adapter position) (contract-of adapter)) ERR_ADAPTER_MISMATCH)
      (asserts! (is-eq (get status position) POSITION_ACTIVE) ERR_POSITION_STATE)
      (try! (contract-call? adapter request-unstake position-id (get native-amount position) (get owner position)))
      (let ((unlock-height
          (unwrap! (safe-add burn-block-height (var-get native-cooldown)) ERR_ARITHMETIC_OVERFLOW)))
        (begin
          (map-set positions position-id (merge position {
            status: POSITION_NATIVE_UNLOCKING,
            native-unlock-height: unlock-height
          }))
          (print {
            event: "dual-stacking-native-unstake-requested",
            position-id: position-id,
            owner: (get owner position),
            unlock-height: unlock-height
          })
          (ok unlock-height)
        )
      )
    )
  )
)

;; @desc Finalize native unstake after the injected adapter and local cooldown
;; both agree. This is allowed while paused and preserves the reserve floor.
(define-public (finalize-native-unstake
    (position-id uint)
    (adapter <stacking-adapter-trait>)
    (token <sip-010-ft-trait>)
  )
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER)
      (asserts! (is-eq (get adapter position) (contract-of adapter)) ERR_ADAPTER_MISMATCH)
      (asserts! (is-native-token token) ERR_INVALID_TOKEN)
      (asserts! (is-eq (get status position) POSITION_NATIVE_UNLOCKING) ERR_POSITION_STATE)
      (asserts! (>= burn-block-height (get native-unlock-height position)) ERR_UNLOCK_NOT_MATURED)
      (let (
          (amount (get native-amount position))
          (balance (try! (contract-call? token get-balance (as-contract tx-sender))))
          (required (unwrap! (required-token-balance amount (var-get liquid-reserve)) ERR_ARITHMETIC_OVERFLOW))
          (config (unwrap! (adapter-for adapter) ERR_ADAPTER_NOT_FOUND))
          (risk-sub (unwrap! (safe-mul-div amount (get risk-bps config) BPS) ERR_ARITHMETIC_OVERFLOW))
        )
        (begin
          (asserts! (>= balance required) ERR_LIQUIDITY_RESERVE)
          (try! (contract-call? adapter finalize-unstake position-id amount (get owner position)))
          (try! (as-contract (contract-call? token transfer amount (as-contract tx-sender) (get owner position) none)))
          (map-set positions position-id (merge position {
            status: (if (get pox-unlocked position) POSITION_CLOSED POSITION_NATIVE_UNLOCKED),
            native-claimed: true
          }))
          (map-set adapters (contract-of adapter) (merge config {
            exposure: (unwrap! (safe-sub (get exposure config) amount) ERR_ARITHMETIC_OVERFLOW),
            risk-exposure: (unwrap! (safe-sub (get risk-exposure config) risk-sub) ERR_ARITHMETIC_OVERFLOW)
          }))
          (var-set total-exposure (unwrap! (safe-sub (var-get total-exposure) amount) ERR_ARITHMETIC_OVERFLOW))
          (var-set total-risk-exposure (unwrap! (safe-sub (var-get total-risk-exposure) risk-sub) ERR_ARITHMETIC_OVERFLOW))
          (print {
            event: "dual-stacking-native-unstake-finalized",
            position-id: position-id,
            owner: (get owner position),
            amount: amount,
            finalized-at: burn-block-height
          })
          (ok amount)
        )
      )
    )
  )
)

;; --- PoX leg synchronization ---

(define-public (record-pox-commit
    (position-id uint)
    (cycle-id uint)
    (unlock-height uint)
    (commit-id uint)
  )
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
      (asserts! (> cycle-id u0) ERR_INVALID_CYCLE)
      (asserts! (> unlock-height burn-block-height) ERR_INVALID_CYCLE)
      (asserts! (> commit-id u0) ERR_INVALID_CYCLE)
      (asserts! (is-eq (get pox-commit-id position) u0) ERR_POSITION_STATE)
      (map-set positions position-id (merge position {
        pox-cycle-id: cycle-id,
        pox-unlock-height: unlock-height,
        pox-commit-id: commit-id
      }))
      (print {
        event: "dual-stacking-pox-commit-synchronized",
        position-id: position-id,
        cycle-id: cycle-id,
        unlock-height: unlock-height,
        commit-id: commit-id
      })
      (ok true)
    )
  )
)

(define-public (finalize-pox-exit (position-id uint))
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER)
      (asserts! (> (get pox-commit-id position) u0) ERR_POSITION_STATE)
      (asserts! (not (get pox-unlocked position)) ERR_ALREADY_CLAIMED)
      (asserts! (>= burn-block-height (get pox-unlock-height position)) ERR_UNLOCK_NOT_MATURED)
      (map-set positions position-id (merge position {
        pox-unlocked: true,
        status: (if (get native-claimed position) POSITION_CLOSED (get status position))
      }))
      (print {
        event: "dual-stacking-pox-exit-finalized",
        position-id: position-id,
        owner: (get owner position),
        cycle-id: (get pox-cycle-id position),
        finalized-at: burn-block-height
      })
      (ok true)
    )
  )
)

;; --- SIP-010 and STX rewards ---

(define-public (fund-reward
    (cycle-id uint)
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (is-reward-token token) ERR_INVALID_TOKEN)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let (
        (key { cycle-id: cycle-id, token: (contract-of token) })
        (pool (reward-pool-or-empty cycle-id (contract-of token)))
        (new-total (unwrap! (safe-add (get total pool) amount) ERR_ARITHMETIC_OVERFLOW))
      )
      (begin
        (asserts! (not (get claims-closed pool)) ERR_REWARD_REPLAYED)
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (map-set reward-pools key (merge pool { total: new-total }))
        (print {
          event: "dual-stacking-reward-funded",
          cycle-id: cycle-id,
          token: (contract-of token),
          amount: amount,
          total: new-total
        })
        (ok new-total)
      )
    )
  )
)

(define-public (claim-reward
    (position-id uint)
    (cycle-id uint)
    (token <sip-010-ft-trait>)
  )
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER)
      (asserts! (is-reward-token token) ERR_INVALID_TOKEN)
      (asserts! (is-eq cycle-id (get reward-cycle position)) ERR_INVALID_CYCLE)
      (let (
          (key { cycle-id: cycle-id, token: (contract-of token) })
          (pool (unwrap! (map-get? reward-pools key) ERR_REWARD_NOT_FOUND))
          (claim-key { position-id: position-id, cycle-id: cycle-id, token: (contract-of token) })
          (total-weight (default-to u0 (map-get? cycle-weights cycle-id)))
          (amount (unwrap! (safe-mul-div (get total pool) (get weight position) total-weight) ERR_ARITHMETIC_OVERFLOW))
          (balance (try! (contract-call? token get-balance (as-contract tx-sender))))
        )
        (begin
          (asserts! (is-none (map-get? reward-claims claim-key)) ERR_ALREADY_CLAIMED)
          (asserts! (> amount u0) ERR_INVALID_AMOUNT)
          (asserts! (>= balance (unwrap! (required-token-balance amount (var-get liquid-reserve)) ERR_ARITHMETIC_OVERFLOW)) ERR_LIQUIDITY_RESERVE)
          (try! (as-contract (contract-call? token transfer amount tx-sender (get owner position) none)))
          (map-set reward-claims claim-key true)
          (map-set reward-pools key (merge pool {
            claimed: (unwrap! (safe-add (get claimed pool) amount) ERR_ARITHMETIC_OVERFLOW),
            claims-closed: true
          }))
          (print {
            event: "dual-stacking-reward-claimed",
            position-id: position-id,
            cycle-id: cycle-id,
            token: (contract-of token),
            amount: amount
          })
          (ok amount)
        )
      )
    )
  )
)

(define-public (fund-stx-reward (cycle-id uint) (amount uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let (
        (pool (stx-reward-pool-or-empty cycle-id))
        (new-total (unwrap! (safe-add (get total pool) amount) ERR_ARITHMETIC_OVERFLOW))
      )
      (begin
        (asserts! (not (get claims-closed pool)) ERR_REWARD_REPLAYED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set stx-reward-pools cycle-id (merge pool { total: new-total }))
        (print { event: "dual-stacking-stx-reward-funded", cycle-id: cycle-id, amount: amount, total: new-total })
        (ok new-total)
      )
    )
  )
)

(define-public (claim-stx-reward (position-id uint) (cycle-id uint))
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER)
      (asserts! (is-eq cycle-id (get reward-cycle position)) ERR_INVALID_CYCLE)
      (let (
          (pool (unwrap! (map-get? stx-reward-pools cycle-id) ERR_REWARD_NOT_FOUND))
          (claim-key { position-id: position-id, cycle-id: cycle-id })
          (total-weight (default-to u0 (map-get? cycle-weights cycle-id)))
          (amount (unwrap! (safe-mul-div (get total pool) (get weight position) total-weight) ERR_ARITHMETIC_OVERFLOW))
          (balance (stx-get-balance (as-contract tx-sender)))
        )
        (begin
          (asserts! (is-none (map-get? stx-reward-claims claim-key)) ERR_ALREADY_CLAIMED)
          (asserts! (> amount u0) ERR_INVALID_AMOUNT)
          (asserts! (>= balance (unwrap! (required-token-balance amount (var-get stx-liquid-reserve)) ERR_ARITHMETIC_OVERFLOW)) ERR_LIQUIDITY_RESERVE)
          (try! (as-contract (stx-transfer? amount tx-sender (get owner position))))
          (map-set stx-reward-claims claim-key true)
          (map-set stx-reward-pools cycle-id (merge pool {
            claimed: (unwrap! (safe-add (get claimed pool) amount) ERR_ARITHMETIC_OVERFLOW),
            claims-closed: true
          }))
          (print { event: "dual-stacking-stx-reward-claimed", position-id: position-id, cycle-id: cycle-id, amount: amount })
          (ok amount)
        )
      )
    )
  )
)

;; --- Attested BTC accounting ---

(define-public (record-btc-entitlement
    (position-id uint)
    (cycle-id uint)
    (amount uint)
    (proof-hash (buff 32))
  )
  (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
    (begin
      (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (> (get pox-commit-id position) u0) ERR_INVALID_CYCLE)
      (asserts! (is-eq cycle-id (get pox-cycle-id position)) ERR_INVALID_CYCLE)
      (asserts! (is-none (map-get? btc-entitlements position-id)) ERR_REWARD_REPLAYED)
      (asserts! (is-none (map-get? btc-proofs proof-hash)) ERR_BTC_PROOF_REPLAYED)
      (map-set btc-entitlements position-id {
        cycle-id: cycle-id,
        amount: amount,
        proof-hash: proof-hash,
        recorded-at: burn-block-height,
        claimed: false
      })
      (map-set btc-proofs proof-hash position-id)
      (print {
        event: "dual-stacking-btc-entitlement-recorded",
        position-id: position-id,
        cycle-id: cycle-id,
        amount: amount,
        proof-hash: proof-hash,
        recorded-at: burn-block-height
      })
      (ok true)
    )
  )
)

;; @desc Claim an attested BTC entitlement. This returns accounting data only;
;; no native BTC or sBTC is transferred by this function.
(define-public (claim-btc-entitlement (position-id uint))
  (let ((entitlement (unwrap! (map-get? btc-entitlements position-id) ERR_BTC_ENTITLEMENT_NOT_FOUND)))
    (begin
      (let ((position (unwrap! (position-or-error position-id) ERR_POSITION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get owner position)) ERR_POSITION_OWNER))
      (asserts! (not (get claimed entitlement)) ERR_ALREADY_CLAIMED)
      (map-set btc-entitlements position-id (merge entitlement { claimed: true }))
      (print {
        event: "dual-stacking-btc-entitlement-claimed",
        position-id: position-id,
        cycle-id: (get cycle-id entitlement),
        amount: (get amount entitlement),
        accounting-only: true
      })
      (ok (get amount entitlement))
    )
  )
)

;; --- Read-only views ---

(define-read-only (get-config)
  {
    admin: (var-get admin),
    initialized: (var-get initialized),
    paused: (var-get paused),
    native-token: (var-get native-token),
    native-token-configured: (var-get native-token-configured),
    reward-token: (var-get reward-token),
    reward-token-configured: (var-get reward-token-configured),
    native-operator: (var-get native-operator),
    native-operator-configured: (var-get native-operator-configured),
    next-position-id: (var-get next-position-id),
    reward-cycle: (var-get reward-cycle),
    max-total-exposure: (var-get max-total-exposure),
    total-exposure: (var-get total-exposure),
    total-risk-exposure: (var-get total-risk-exposure),
    liquid-reserve: (var-get liquid-reserve),
    stx-liquid-reserve: (var-get stx-liquid-reserve),
    native-cooldown: (var-get native-cooldown)
  }
)

(define-read-only (get-adapter (adapter-principal principal))
  (map-get? adapters adapter-principal)
)

(define-read-only (get-position (position-id uint))
  (map-get? positions position-id)
)

(define-read-only (get-cycle-weight (cycle-id uint))
  (default-to u0 (map-get? cycle-weights cycle-id))
)

(define-read-only (get-reward-pool (cycle-id uint) (token-principal principal))
  (map-get? reward-pools { cycle-id: cycle-id, token: token-principal })
)

(define-read-only (get-stx-reward-pool (cycle-id uint))
  (map-get? stx-reward-pools cycle-id)
)

(define-read-only (get-btc-entitlement (position-id uint))
  (map-get? btc-entitlements position-id)
)

(define-read-only (get-btc-proof-owner (proof-hash (buff 32)))
  (map-get? btc-proofs proof-hash)
)
