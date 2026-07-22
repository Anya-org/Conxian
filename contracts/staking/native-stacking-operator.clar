;; native-stacking-operator.clar
;;
;; Authoritative accounting boundary for delegated native/STX commitments.
;; This contract does not custody STX. It records the user-owned commitment,
;; asks a configured PoX adapter to perform the external lifecycle, and exposes
;; only verified metadata to the configured dual-stacking orchestrator.

(impl-trait .stacking-traits.native-stacking-operator-trait)
(use-trait pox-adapter-trait .stacking-traits.pox-adapter-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_INITIALIZED (err u1001))
(define-constant ERR_ALREADY_INITIALIZED (err u1002))
(define-constant ERR_ADAPTER_NOT_CONFIGURED (err u1003))
(define-constant ERR_ADAPTER_MISMATCH (err u1004))
(define-constant ERR_INVALID_AMOUNT (err u1005))
(define-constant ERR_DELEGATION_EXISTS (err u1006))
(define-constant ERR_DELEGATION_NOT_FOUND (err u1007))
(define-constant ERR_DELEGATION_INACTIVE (err u1008))
(define-constant ERR_ACTIVE_COMMIT (err u1009))
(define-constant ERR_COMMIT_NOT_FOUND (err u1010))
(define-constant ERR_COMMIT_REPLAYED (err u1011))
(define-constant ERR_INVALID_CYCLE (err u1012))
(define-constant ERR_COMMIT_NOT_MATURED (err u1013))
(define-constant ERR_COMMIT_FINALIZED (err u1014))
(define-constant ERR_PAUSED (err u1015))
(define-constant ERR_PROOF_REPLAYED (err u1016))
(define-constant ERR_INVALID_PROOF_AMOUNT (err u1017))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1018))
(define-constant ERR_OPERATOR_NOT_CONFIGURED (err u1019))
(define-constant ERR_ORCHESTRATOR_NOT_CONFIGURED (err u1020))
(define-constant ERR_BINDING_UNAUTHORIZED (err u1021))
(define-constant ERR_COMMIT_BOUND (err u1022))
(define-constant ERR_COMMIT_OWNER (err u1023))
(define-constant ERR_EXTERNAL_FINALIZE (err u1024))
(define-constant ERR_SETTLEMENT_NOT_FOUND (err u1025))
(define-constant ERR_SETTLEMENT_MISMATCH (err u1026))
(define-constant ERR_SETTLEMENT_CONSUMED (err u1027))
(define-constant ERR_INVALID_STATE (err u1028))

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant COMMIT_ACTIVE u0)
(define-constant COMMIT_MATURED u1)

;; --- Configuration ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)
(define-data-var paused bool false)
(define-data-var pox-adapter principal tx-sender)
(define-data-var adapter-configured bool false)
(define-data-var operator principal tx-sender)
(define-data-var operator-configured bool false)
(define-data-var orchestrator principal tx-sender)
(define-data-var orchestrator-configured bool false)
(define-data-var next-commit-id uint u1)
(define-data-var last-cycle-id uint u0)

(define-map keepers principal bool)

;; --- Delegation and commit ledgers ---
(define-map delegations principal {
  amount: uint,
  active: bool,
  registered-at: uint,
  revoked-at: (optional uint)
})

(define-map active-commits principal uint)
(define-map commits uint {
  user: principal,
  amount: uint,
  cycle-id: uint,
  cycle-start: uint,
  cycle-length: uint,
  lock-period: uint,
  unlock-height: uint,
  auth-id: (buff 32),
  external-commit-id: uint,
  state: uint,
  created-at: uint,
  finalized-at: (optional uint),
  bound: bool
})

(define-map auth-ids (buff 32) uint)

(define-map cycle-ledger uint {
  committed: uint,
  matured: uint,
  last-commit-id: uint
})

;; BTC is native to Bitcoin and cannot be transferred by Clarity. These are
;; exact, cycle/recipient/amount-bound settlement attestations only.
(define-map btc-settlements (buff 32) {
  cycle-id: uint,
  recipient: principal,
  amount: uint,
  commit-id: uint,
  recorded-at: uint,
  consumed: bool
})

;; --- Helpers ---
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-authorized-operator)
  (or
    (is-admin)
    (default-to false (map-get? keepers tx-sender))
    (and (var-get operator-configured) (is-eq tx-sender (var-get operator)))
  )
)

(define-private (is-configured-adapter (adapter <pox-adapter-trait>))
  (and
    (var-get adapter-configured)
    (is-eq (contract-of adapter) (var-get pox-adapter))
  )
)

(define-private (is-orchestrator-caller)
  (and
    (var-get orchestrator-configured)
    (is-eq contract-caller (var-get orchestrator))
  )
)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right))
  )
)

(define-private (cycle-ledger-or-empty (cycle-id uint))
  (default-to {
    committed: u0,
    matured: u0,
    last-commit-id: u0
  } (map-get? cycle-ledger cycle-id))
)

(define-private (commit-metadata (commit-id uint) (commit {
    user: principal,
    amount: uint,
    cycle-id: uint,
    cycle-start: uint,
    cycle-length: uint,
    lock-period: uint,
    unlock-height: uint,
    auth-id: (buff 32),
    external-commit-id: uint,
    state: uint,
    created-at: uint,
    finalized-at: (optional uint),
    bound: bool
  }))
  {
    commit-id: commit-id,
    user: (get user commit),
    amount: (get amount commit),
    cycle-id: (get cycle-id commit),
    unlock-height: (get unlock-height commit),
    external-commit-id: (get external-commit-id commit),
    state: (get state commit)
  }
)

;; --- Initialization and controls ---
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (print { event: "native-stacking-operator-initialized", admin: new-admin })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (print { event: "native-stacking-operator-admin-updated", admin: new-admin })
    (ok true)
  )
)

(define-public (set-pox-adapter (adapter <pox-adapter-trait>))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set pox-adapter (contract-of adapter))
    (var-set adapter-configured true)
    (print { event: "native-stacking-operator-adapter-configured", adapter: (contract-of adapter) })
    (ok true)
  )
)

(define-public (set-keeper (keeper principal) (enabled bool))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (map-set keepers keeper enabled)
    (print { event: "native-stacking-operator-keeper-updated", keeper: keeper, enabled: enabled })
    (ok true)
  )
)

(define-public (set-operator (new-operator principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set operator new-operator)
    (var-set operator-configured true)
    (print { event: "native-stacking-operator-authorized-operator", operator: new-operator })
    (ok true)
  )
)

(define-public (set-orchestrator (new-orchestrator principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set orchestrator new-orchestrator)
    (var-set orchestrator-configured true)
    (print { event: "native-stacking-operator-orchestrator-configured", orchestrator: new-orchestrator })
    (ok true)
  )
)

(define-public (set-paused (should-pause bool))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set paused should-pause)
    (print { event: "native-stacking-operator-pause-updated", paused: should-pause })
    (ok true)
  )
)

;; --- Delegated PoX lifecycle ---
(define-public (register-delegation (amount uint) (adapter <pox-adapter-trait>))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-configured-adapter adapter) ERR_ADAPTER_MISMATCH)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts!
      (match (map-get? delegations tx-sender)
        existing (not (get active existing))
        true)
      ERR_DELEGATION_EXISTS)
    (try! (contract-call? adapter delegate-stx tx-sender amount))
    (map-set delegations tx-sender {
      amount: amount,
      active: true,
      registered-at: burn-block-height,
      revoked-at: none
    })
    (print {
      event: "native-stacking-delegation-registered",
      user: tx-sender,
      amount: amount,
      registered-at: burn-block-height,
      adapter: (contract-of adapter)
    })
    (ok true)
  )
)

;; Delegation revocation is separate from the committed lock lifecycle. An
;; active commit cannot be locally canceled; it must mature/finalize externally.
(define-public (revoke-delegation (adapter <pox-adapter-trait>))
  (let ((delegation (unwrap! (map-get? delegations tx-sender) ERR_DELEGATION_NOT_FOUND)))
    (begin
      (asserts! (is-configured-adapter adapter) ERR_ADAPTER_MISMATCH)
      (asserts! (get active delegation) ERR_DELEGATION_INACTIVE)
      (let ((active-commit-id (default-to u0 (map-get? active-commits tx-sender))))
        (begin
          (asserts! (is-eq active-commit-id u0) ERR_ACTIVE_COMMIT)
          (try! (contract-call? adapter revoke-delegation tx-sender))
          (map-set delegations tx-sender (merge delegation {
            active: false,
            revoked-at: (some burn-block-height)
          }))
          (print {
            event: "native-stacking-delegation-revoked",
            user: tx-sender,
            revoked-at: burn-block-height,
            adapter: (contract-of adapter)
          })
          (ok true)
        )
      )
    )
  )
)

(define-public (commit-delegation
    (user principal)
    (amount uint)
    (lock-period uint)
    (auth-id (buff 32))
    (adapter <pox-adapter-trait>)
  )
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (is-configured-adapter adapter) ERR_ADAPTER_MISMATCH)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? auth-ids auth-id)) ERR_COMMIT_REPLAYED)
    (let (
        (delegation (unwrap! (map-get? delegations user) ERR_DELEGATION_NOT_FOUND))
        (active-commit-id (default-to u0 (map-get? active-commits user)))
        (cycle-info (try! (contract-call? adapter get-cycle-info)))
        (cycle-id (get cycle-id cycle-info))
        (cycle-start (get cycle-start cycle-info))
        (cycle-length (get cycle-length cycle-info))
        (commit-id (var-get next-commit-id))
        (unlock-height (try! (contract-call? adapter get-unlock-height cycle-id lock-period)))
        (external-commit-id (try! (contract-call? adapter commit-stx user amount cycle-id lock-period auth-id)))
      )
      (begin
        (asserts! (get active delegation) ERR_DELEGATION_INACTIVE)
        (asserts! (is-eq active-commit-id u0) ERR_ACTIVE_COMMIT)
        (asserts! (<= amount (get amount delegation)) ERR_INVALID_AMOUNT)
        (asserts! (>= burn-block-height cycle-start) ERR_INVALID_CYCLE)
        (asserts! (> unlock-height burn-block-height) ERR_INVALID_CYCLE)
        (asserts! (< commit-id MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
        (let ((ledger (cycle-ledger-or-empty cycle-id)))
          (begin
            (map-set commits commit-id {
              user: user,
              amount: amount,
              cycle-id: cycle-id,
              cycle-start: cycle-start,
              cycle-length: cycle-length,
              lock-period: lock-period,
              unlock-height: unlock-height,
              auth-id: auth-id,
              external-commit-id: external-commit-id,
              state: COMMIT_ACTIVE,
              created-at: burn-block-height,
              finalized-at: none,
              bound: false
            })
            (map-set auth-ids auth-id commit-id)
            (map-set active-commits user commit-id)
            (map-set cycle-ledger cycle-id (merge ledger {
              committed: (unwrap! (safe-add (get committed ledger) amount) ERR_ARITHMETIC_OVERFLOW),
              last-commit-id: commit-id
            }))
            (var-set next-commit-id (+ commit-id u1))
            (var-set last-cycle-id cycle-id)
            (print {
              event: "native-stacking-commit-recorded",
              commit-id: commit-id,
              user: user,
              amount: amount,
              cycle-id: cycle-id,
              cycle-start: cycle-start,
              unlock-height: unlock-height,
              auth-id: auth-id,
              adapter: (contract-of adapter)
            })
            (ok commit-id)
          )
        )
      )
    )
  )
)

;; Bind exactly once to the configured orchestrator. The original transaction
;; sender remains the commitment owner; contract-caller is the orchestrator.
(define-public (bind-commit (commit-id uint))
  (let ((commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND)))
    (begin
      (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (var-get orchestrator-configured) ERR_ORCHESTRATOR_NOT_CONFIGURED)
      (asserts! (is-orchestrator-caller) ERR_BINDING_UNAUTHORIZED)
      (asserts! (is-eq tx-sender (get user commit)) ERR_COMMIT_OWNER)
      (asserts! (is-eq (get state commit) COMMIT_ACTIVE) ERR_INVALID_STATE)
      (asserts! (not (get bound commit)) ERR_COMMIT_BOUND)
      (asserts! (var-get adapter-configured) ERR_ADAPTER_NOT_CONFIGURED)
      (asserts! (> (get amount commit) u0) ERR_INVALID_AMOUNT)
      (asserts! (> (get cycle-id commit) u0) ERR_INVALID_CYCLE)
      (map-set commits commit-id (merge commit { bound: true }))
      (print {
        event: "native-stacking-commit-bound",
        commit-id: commit-id,
        user: (get user commit),
        amount: (get amount commit),
        cycle-id: (get cycle-id commit),
        unlock-height: (get unlock-height commit),
        orchestrator: contract-caller
      })
      (ok (commit-metadata commit-id (merge commit { bound: true })))
    )
  )
)

;; Finalize the external lock before mutating local state. A matured local
;; record is returned idempotently for orchestrator reconciliation.
(define-public (finalize-commit (commit-id uint) (adapter <pox-adapter-trait>))
  (let ((commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND)))
    (begin
      (asserts!
        (or
          (is-authorized-operator)
          (and (is-orchestrator-caller) (is-eq tx-sender (get user commit))))
        ERR_UNAUTHORIZED)
      (asserts! (is-configured-adapter adapter) ERR_ADAPTER_MISMATCH)
      (if (is-eq (get state commit) COMMIT_MATURED)
        (ok (commit-metadata commit-id commit))
        (begin
          (asserts! (is-eq (get state commit) COMMIT_ACTIVE) ERR_COMMIT_FINALIZED)
          (asserts! (>= burn-block-height (get unlock-height commit)) ERR_COMMIT_NOT_MATURED)
          (asserts! (try! (contract-call? adapter finalize-commit (get external-commit-id commit))) ERR_EXTERNAL_FINALIZE)
          (let ((ledger (cycle-ledger-or-empty (get cycle-id commit))))
            (begin
              (map-set commits commit-id (merge commit {
                state: COMMIT_MATURED,
                finalized-at: (some burn-block-height)
              }))
              (map-delete active-commits (get user commit))
              (map-set cycle-ledger (get cycle-id commit) (merge ledger {
                matured: (unwrap! (safe-add (get matured ledger) (get amount commit)) ERR_ARITHMETIC_OVERFLOW)
              }))
              (print {
                event: "native-stacking-commit-matured",
                commit-id: commit-id,
                user: (get user commit),
                amount: (get amount commit),
                cycle-id: (get cycle-id commit),
                matured-at: burn-block-height
              })
              (ok (commit-metadata commit-id (merge commit {
                state: COMMIT_MATURED,
                finalized-at: (some burn-block-height)
              })))
            )
          )
        )
      )
    )
  )
)

;; Record an exact settlement against an already matured commit. BTC remains
;; external; this is an operator-authenticated accounting attestation.
(define-public (record-btc-settlement
    (commit-id uint)
    (amount uint)
    (proof-hash (buff 32))
  )
  (let ((commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND)))
    (begin
      (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get state commit) COMMIT_MATURED) ERR_INVALID_STATE)
      (asserts! (> amount u0) ERR_INVALID_PROOF_AMOUNT)
      (asserts! (is-none (map-get? btc-settlements proof-hash)) ERR_PROOF_REPLAYED)
      (map-set btc-settlements proof-hash {
        cycle-id: (get cycle-id commit),
        recipient: (get user commit),
        amount: amount,
        commit-id: commit-id,
        recorded-at: burn-block-height,
        consumed: false
      })
      (print {
        event: "native-stacking-btc-settlement-attested",
        commit-id: commit-id,
        cycle-id: (get cycle-id commit),
        recipient: (get user commit),
        amount: amount,
        proof-hash: proof-hash,
        recorded-at: burn-block-height
      })
      (ok true)
    )
  )
)

;; Consume a settlement exactly once. The caller supplies only the expected
;; amount and proof; recipient and cycle are derived from the bound commit.
(define-public (bind-btc-settlement
    (commit-id uint)
    (proof-hash (buff 32))
    (expected-amount uint)
  )
  (let (
      (commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND))
      (settlement (unwrap! (map-get? btc-settlements proof-hash) ERR_SETTLEMENT_NOT_FOUND))
    )
    (begin
      (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
      (asserts! (is-orchestrator-caller) ERR_BINDING_UNAUTHORIZED)
      (asserts! (is-eq tx-sender (get user commit)) ERR_COMMIT_OWNER)
      (asserts! (is-eq (get state commit) COMMIT_MATURED) ERR_INVALID_STATE)
      (asserts! (not (get consumed settlement)) ERR_SETTLEMENT_CONSUMED)
      (asserts! (is-eq (get commit-id settlement) commit-id) ERR_SETTLEMENT_MISMATCH)
      (asserts! (is-eq (get cycle-id settlement) (get cycle-id commit)) ERR_SETTLEMENT_MISMATCH)
      (asserts! (is-eq (get recipient settlement) (get user commit)) ERR_SETTLEMENT_MISMATCH)
      (asserts! (is-eq (get amount settlement) expected-amount) ERR_SETTLEMENT_MISMATCH)
      (map-set btc-settlements proof-hash (merge settlement { consumed: true }))
      (print {
        event: "native-stacking-btc-settlement-bound",
        commit-id: commit-id,
        cycle-id: (get cycle-id settlement),
        recipient: (get recipient settlement),
        amount: (get amount settlement),
        proof-hash: proof-hash
      })
      (ok {
        commit-id: commit-id,
        cycle-id: (get cycle-id settlement),
        recipient: (get recipient settlement),
        amount: (get amount settlement),
        proof-hash: proof-hash
      })
    )
  )
)

;; --- Read-only views ---
(define-read-only (get-operator-config)
  (ok {
    initialized: (var-get initialized),
    orchestrator: (var-get orchestrator),
    orchestrator-configured: (var-get orchestrator-configured)
  })
)

(define-read-only (get-config)
  {
    admin: (var-get admin),
    initialized: (var-get initialized),
    paused: (var-get paused),
    pox-adapter: (var-get pox-adapter),
    adapter-configured: (var-get adapter-configured),
    operator: (var-get operator),
    operator-configured: (var-get operator-configured),
    orchestrator: (var-get orchestrator),
    orchestrator-configured: (var-get orchestrator-configured),
    next-commit-id: (var-get next-commit-id),
    last-cycle-id: (var-get last-cycle-id)
  }
)

(define-read-only (is-keeper (who principal))
  (default-to false (map-get? keepers who))
)

(define-read-only (get-delegation (user principal))
  (map-get? delegations user)
)

(define-read-only (get-commit (commit-id uint))
  (map-get? commits commit-id)
)

(define-read-only (get-active-commit (user principal))
  (default-to u0 (map-get? active-commits user))
)

(define-read-only (get-cycle-ledger (cycle-id uint))
  (map-get? cycle-ledger cycle-id)
)

(define-read-only (get-btc-settlement (proof-hash (buff 32)))
  (map-get? btc-settlements proof-hash)
)
