;; native-stacking-operator.clar
;; Delegated PoX/operator accounting boundary for the staking module.
;;
;; This contract does not custody user STX. It records user delegation intent,
;; asks a configured PoX-compatible adapter to perform delegated operations,
;; and snapshots the adapter-returned cycle/unlock values. A production
;; deployment supplies the adapter principal during initialization/wiring.

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

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant COMMIT_ACTIVE u0)
(define-constant COMMIT_MATURED u1)
(define-constant COMMIT_REVOKED u2)

;; --- Configuration ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)
(define-data-var paused bool false)
(define-data-var pox-adapter principal tx-sender)
(define-data-var adapter-configured bool false)
(define-data-var operator principal tx-sender)
(define-data-var operator-configured bool false)
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
  finalized-at: (optional uint)
})

(define-map auth-ids (buff 32) uint)

(define-map cycle-ledger uint {
  committed: uint,
  matured: uint,
  revoked: uint,
  last-commit-id: uint
})

;; BTC is native to Bitcoin and cannot be transferred by Clarity. These
;; records are authorized, cycle-bound settlement attestations only.
(define-map btc-settlements (buff 32) {
  cycle-id: uint,
  recipient: principal,
  amount: uint,
  recorded-at: uint,
  claimed: bool
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
    revoked: u0,
    last-commit-id: u0
  } (map-get? cycle-ledger cycle-id))
)

;; --- Initialization and controls ---

;; @desc One-time initialization. The deployer principal is the bootstrap
;; authority; subsequent administration uses the configured admin.
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

;; @desc Register a user's delegated STX amount through the injected adapter.
;; No STX is transferred into this contract.
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

;; @desc Revoke a delegation before a new commit is created. Revocation is
;; deliberately allowed while paused so exits remain available.
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

;; @desc Commit a delegated amount for the adapter's current burn cycle.
;; `auth-id` is a caller-supplied replay-resistant identifier; the contract
;; also issues a monotonic local commit ID.
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
              finalized-at: none
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

;; @desc Mark a delegated commit matured at its adapter-returned unlock height.
;; This is an accounting transition; native STX remains with the PoX system.
(define-public (finalize-commit (commit-id uint))
  (let ((commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND)))
    (begin
      (asserts! (is-eq (get state commit) COMMIT_ACTIVE) ERR_COMMIT_FINALIZED)
      (asserts! (>= burn-block-height (get unlock-height commit)) ERR_COMMIT_NOT_MATURED)
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
          (ok true)
        )
      )
    )
  )
)

;; @desc Revoke an active accounting commit without claiming native STX.
;; Adapter-specific cancellation remains an explicit integration concern.
(define-public (revoke-commit (commit-id uint))
  (let ((commit (unwrap! (map-get? commits commit-id) ERR_COMMIT_NOT_FOUND)))
    (begin
      (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get state commit) COMMIT_ACTIVE) ERR_COMMIT_FINALIZED)
      (let ((ledger (cycle-ledger-or-empty (get cycle-id commit))))
        (begin
          (map-set commits commit-id (merge commit { state: COMMIT_REVOKED }))
          (map-delete active-commits (get user commit))
          (map-set cycle-ledger (get cycle-id commit) (merge ledger {
            revoked: (unwrap! (safe-add (get revoked ledger) (get amount commit)) ERR_ARITHMETIC_OVERFLOW)
          }))
          (print {
            event: "native-stacking-commit-revoked",
            commit-id: commit-id,
            user: (get user commit),
            amount: (get amount commit),
            cycle-id: (get cycle-id commit),
            revoked-at: burn-block-height
          })
          (ok true)
        )
      )
    )
  )
)

;; @desc Record an authorized BTC settlement attestation. No native BTC is
;; transferred or implied by this call.
(define-public (record-btc-settlement
    (cycle-id uint)
    (recipient principal)
    (amount uint)
    (proof-hash (buff 32))
  )
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PROOF_AMOUNT)
    (asserts! (<= cycle-id (var-get last-cycle-id)) ERR_INVALID_CYCLE)
    (asserts! (is-none (map-get? btc-settlements proof-hash)) ERR_PROOF_REPLAYED)
    (map-set btc-settlements proof-hash {
      cycle-id: cycle-id,
      recipient: recipient,
      amount: amount,
      recorded-at: burn-block-height,
      claimed: false
    })
    (print {
      event: "native-stacking-btc-settlement-attested",
      cycle-id: cycle-id,
      recipient: recipient,
      amount: amount,
      proof-hash: proof-hash,
      recorded-at: burn-block-height
    })
    (ok true)
  )
)

;; --- Read-only views ---
(define-read-only (get-config)
  {
    admin: (var-get admin),
    initialized: (var-get initialized),
    paused: (var-get paused),
    pox-adapter: (var-get pox-adapter),
    adapter-configured: (var-get adapter-configured),
    operator: (var-get operator),
    operator-configured: (var-get operator-configured),
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
