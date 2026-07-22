;; stacking-traits.clar
;; Narrow, dependency-injected interfaces used by the dual-stacking module.
;; The production PoX and generic stacking protocols remain deployment trust
;; boundaries; these traits make the boundary explicit and testable.

(define-trait pox-adapter-trait
  (
    ;; Return the adapter's authoritative burn-cycle snapshot.
    (get-cycle-info () (response { cycle-id: uint, cycle-start: uint, cycle-length: uint } uint))

    ;; Return the unlock height for a cycle/lock-period pair.
    (get-unlock-height (uint uint) (response uint uint))

    ;; Register or revoke delegated STX accounting for a user.
    (delegate-stx (principal uint) (response bool uint))
    (revoke-delegation (principal) (response bool uint))

    ;; Commit a delegated amount with an operator-supplied auth identifier.
    (commit-stx (principal uint uint uint (buff 32)) (response uint uint))

    ;; Finalize the external commit only at or after its authoritative unlock.
    (finalize-commit (uint) (response bool uint))
  )
)

(define-trait native-stacking-operator-trait
  (
    ;; Prove that the configured principal is an initialized native operator
    ;; wired to this orchestrator before accepting it as configuration.
    (get-operator-config ()
      (response {
        initialized: bool,
        orchestrator: principal,
        orchestrator-configured: bool
      } uint))

    ;; Bind an active, unique operator commit to the calling orchestrator.
    (bind-commit (uint)
      (response {
        commit-id: uint,
        user: principal,
        amount: uint,
        cycle-id: uint,
        unlock-height: uint,
        external-commit-id: uint,
        state: uint,
        pox-adapter: principal,
        bound-orchestrator: (optional principal)
      } uint))

    ;; Reconcile/finalize the authoritative external lifecycle. This is
    ;; idempotent after maturity so an orchestrator can reconcile a keeper-led
    ;; finalization without trusting caller-supplied metadata.
    (finalize-commit (uint <pox-adapter-trait>)
      (response {
        commit-id: uint,
        user: principal,
        amount: uint,
        cycle-id: uint,
        unlock-height: uint,
        external-commit-id: uint,
        state: uint,
        pox-adapter: principal,
        bound-orchestrator: (optional principal)
      } uint))

    ;; Consume one exact, cycle/recipient/amount-bound settlement attestation.
    (bind-btc-settlement (uint (buff 32) uint)
      (response {
        commit-id: uint,
        cycle-id: uint,
        recipient: principal,
        amount: uint,
        proof-hash: (buff 32)
      } uint))
  )
)

(define-trait stacking-adapter-trait
  (
    ;; Adapter health and risk configuration.
    (is-active () (response bool uint))
    (get-risk-bps () (response uint uint))
    (get-max-exposure () (response uint uint))

    ;; One adapter action is executed per orchestrator transaction.
    (prepare-stake (uint uint principal) (response bool uint))
    (request-unstake (uint uint principal) (response bool uint))
    (finalize-unstake (uint uint principal) (response uint uint))
  )
)
