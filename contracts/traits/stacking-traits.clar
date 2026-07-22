;; stacking-traits.clar
;; Narrow interfaces used by the staking module.
;;
;; The production PoX boot contract is intentionally not bound to this local
;; trait. `native-stacking-operator` accepts an injected adapter and verifies
;; its configured principal before making any call. This keeps the trust
;; boundary explicit and makes the lifecycle deterministic in Simnet.

(define-trait pox-adapter-trait
  (
    ;; Return the adapter's current burn-cycle snapshot.
    (get-cycle-info () (response { cycle-id: uint, cycle-start: uint, cycle-length: uint } uint))

    ;; Return the unlock height for a cycle/lock-period pair.
    (get-unlock-height (uint uint) (response uint uint))

    ;; Register or revoke delegated STX accounting for a user.
    (delegate-stx (principal uint) (response bool uint))
    (revoke-delegation (principal) (response bool uint))

    ;; Commit a delegated amount with an operator-supplied auth identifier.
    (commit-stx (principal uint uint uint (buff 32)) (response uint uint))
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
