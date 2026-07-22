;; auto-compounder.clar
;; Trait-driven, permissionless yield compounding coordinator.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(use-trait compoundable-vault-trait .compoundable-vault-trait.compoundable-vault-trait)

;; --- Error codes ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_TRIGGER_MODE (err u1001))
(define-constant ERR_INVALID_INTERVAL (err u1002))
(define-constant ERR_INVALID_THRESHOLD (err u1003))
(define-constant ERR_INVALID_MIN_OUTPUT (err u1004))
(define-constant ERR_VAULT_NOT_REGISTERED (err u1005))
(define-constant ERR_VAULT_DISABLED (err u1006))
(define-constant ERR_VAULT_IDENTITY_MISMATCH (err u1007))
(define-constant ERR_TRIGGER_NOT_READY (err u1008))
(define-constant ERR_OUTPUT_TOO_LOW (err u1009))
(define-constant ERR_REENTRANT (err u1010))

;; --- Trigger modes ---
;; Frequency: interval must be met.
;; Threshold: pending rewards must meet the configured threshold.
;; Either: one of the two conditions must be met.
;; Both: both conditions must be met.
(define-constant TRIGGER_FREQUENCY u1)
(define-constant TRIGGER_THRESHOLD u2)
(define-constant TRIGGER_EITHER u3)
(define-constant TRIGGER_BOTH u4)

;; --- State ---
(define-data-var admin principal tx-sender)

(define-map vault-configs
  principal
  {
    source-vault: principal,
    destination-vault: principal,
    trigger-mode: uint,
    min-interval: uint,
    min-reward-threshold: uint,
    min-output: uint,
    enabled: bool,
    last-compound-block: uint
  }
)

;; A vault is locked before the first external trait call. Errors roll the
;; write back automatically; successful execution clears the lock explicitly.
(define-map compound-in-progress principal bool)

;; --- Internal validation and trigger helpers ---

(define-private (is-admin)
  (is-eq contract-caller (var-get admin))
)

(define-private (validate-config
    (trigger-mode uint)
    (min-interval uint)
    (min-reward-threshold uint)
    (min-output uint)
  )
  (begin
    (asserts!
      (or
        (is-eq trigger-mode TRIGGER_FREQUENCY)
        (is-eq trigger-mode TRIGGER_THRESHOLD)
        (is-eq trigger-mode TRIGGER_EITHER)
        (is-eq trigger-mode TRIGGER_BOTH)
      )
      ERR_INVALID_TRIGGER_MODE
    )
    ;; A frequency criterion is meaningful only with a positive interval.
    (asserts!
      (if
        (or
          (is-eq trigger-mode TRIGGER_FREQUENCY)
          (is-eq trigger-mode TRIGGER_EITHER)
          (is-eq trigger-mode TRIGGER_BOTH)
        )
        (> min-interval u0)
        true
      )
      ERR_INVALID_INTERVAL
    )
    ;; A threshold criterion is meaningful only with a positive threshold.
    (asserts!
      (if
        (or
          (is-eq trigger-mode TRIGGER_THRESHOLD)
          (is-eq trigger-mode TRIGGER_EITHER)
          (is-eq trigger-mode TRIGGER_BOTH)
        )
        (> min-reward-threshold u0)
        true
      )
      ERR_INVALID_THRESHOLD
    )
    ;; Every configured route needs a non-zero slippage floor.
    (asserts! (> min-output u0) ERR_INVALID_MIN_OUTPUT)
    (ok true)
  )
)

(define-private (last-successful-block (vault principal))
  (match (map-get? vault-configs vault)
    config (get last-compound-block config)
    ;; A first registration starts its interval clock at registration time.
    burn-block-height
  )
)

(define-private (frequency-ready (last-block uint) (min-interval uint))
  (if (>= burn-block-height last-block)
    (>= (- burn-block-height last-block) min-interval)
    false
  )
)

(define-private (trigger-ready
    (trigger-mode uint)
    (frequency-is-ready bool)
    (threshold-is-ready bool)
  )
  (if (is-eq trigger-mode TRIGGER_FREQUENCY)
    frequency-is-ready
    (if (is-eq trigger-mode TRIGGER_THRESHOLD)
      threshold-is-ready
      (if (is-eq trigger-mode TRIGGER_EITHER)
        (or frequency-is-ready threshold-is-ready)
        (and frequency-is-ready threshold-is-ready)
      )
    )
  )
)

;; --- Read-only API ---

;; @desc Return the current coordinator administrator.
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; @desc Return whether a source vault has a coordinator configuration.
(define-read-only (is-vault-registered (vault principal))
  (is-some (map-get? vault-configs vault))
)

;; @desc Return the stored configuration, if present.
(define-read-only (get-vault-config (vault principal))
  (map-get? vault-configs vault)
)

;; @desc Calculate trigger readiness from a caller-supplied reward snapshot.
;; The coordinator cannot dynamically call an arbitrary stored principal, so
;; off-chain keepers read the vault and pass the snapshot to this O(1) helper.
(define-read-only (get-trigger-status (vault principal) (pending-rewards uint))
  (match (map-get? vault-configs vault)
    config
      (let
        (
          (frequency-is-ready
            (frequency-ready
              (get last-compound-block config)
              (get min-interval config)
            )
          )
          (threshold-is-ready
            (>= pending-rewards (get min-reward-threshold config))
          )
          (trigger-is-ready
            (trigger-ready
              (get trigger-mode config)
              frequency-is-ready
              threshold-is-ready
            )
          )
        )
        (ok
          {
            source-vault: (get source-vault config),
            destination-vault: (get destination-vault config),
            trigger-mode: (get trigger-mode config),
            min-interval: (get min-interval config),
            min-reward-threshold: (get min-reward-threshold config),
            min-output: (get min-output config),
            enabled: (get enabled config),
            last-compound-block: (get last-compound-block config),
            pending-rewards: pending-rewards,
            frequency-ready: frequency-is-ready,
            threshold-ready: threshold-is-ready,
            trigger-ready: trigger-is-ready,
            should-compound: (and (get enabled config) trigger-is-ready),
            current-burn-block: burn-block-height
          }
        )
      )
    ERR_VAULT_NOT_REGISTERED
  )
)

;; --- Administrator API ---

;; @desc Transfer administrative control.
(define-public (set-admin (new-admin principal))
  (let ((previous-admin (var-get admin)))
    (begin
      (asserts! (is-admin) ERR_UNAUTHORIZED)
      (var-set admin new-admin)
      (print
        {
          event: "compounder-admin-updated",
          old-admin: previous-admin,
          new-admin: new-admin,
          block: burn-block-height
        }
      )
      (ok true)
    )
  )
)

;; @desc Register or replace a typed source-vault configuration.
(define-public (register-vault
    (vault <compoundable-vault-trait>)
    (destination-vault principal)
    (trigger-mode uint)
    (min-interval uint)
    (min-reward-threshold uint)
    (min-output uint)
    (enabled bool)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (try! (validate-config trigger-mode min-interval min-reward-threshold min-output))
    (let
      (
        (source-vault (contract-of vault))
        (last-block (last-successful-block (contract-of vault)))
      )
      (map-set vault-configs source-vault
        {
          source-vault: source-vault,
          destination-vault: destination-vault,
          trigger-mode: trigger-mode,
          min-interval: min-interval,
          min-reward-threshold: min-reward-threshold,
          min-output: min-output,
          enabled: enabled,
          last-compound-block: last-block
        }
      )
      (print
        {
          event: "compound-vault-registered",
          vault: source-vault,
          destination-vault: destination-vault,
          trigger-mode: trigger-mode,
          min-interval: min-interval,
          min-reward-threshold: min-reward-threshold,
          min-output: min-output,
          enabled: enabled,
          block: burn-block-height
        }
      )
      (ok true)
    )
  )
)

;; @desc Update an existing typed source-vault configuration.
(define-public (update-vault-config
    (vault <compoundable-vault-trait>)
    (destination-vault principal)
    (trigger-mode uint)
    (min-interval uint)
    (min-reward-threshold uint)
    (min-output uint)
    (enabled bool)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (try! (validate-config trigger-mode min-interval min-reward-threshold min-output))
    (let
      (
        (source-vault (contract-of vault))
        (current-config (unwrap! (map-get? vault-configs (contract-of vault)) ERR_VAULT_NOT_REGISTERED))
      )
      (map-set vault-configs source-vault
        (merge current-config
          {
            source-vault: source-vault,
            destination-vault: destination-vault,
            trigger-mode: trigger-mode,
            min-interval: min-interval,
            min-reward-threshold: min-reward-threshold,
            min-output: min-output,
            enabled: enabled
          }
        )
      )
      (print
        {
          event: "compound-vault-config-updated",
          vault: source-vault,
          destination-vault: destination-vault,
          trigger-mode: trigger-mode,
          min-interval: min-interval,
          min-reward-threshold: min-reward-threshold,
          min-output: min-output,
          enabled: enabled,
          block: burn-block-height
        }
      )
      (ok true)
    )
  )
)

;; @desc Enable or disable an existing typed source vault.
(define-public (set-vault-enabled (vault <compoundable-vault-trait>) (enabled bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (let
      (
        (source-vault (contract-of vault))
        (current-config (unwrap! (map-get? vault-configs (contract-of vault)) ERR_VAULT_NOT_REGISTERED))
      )
      (map-set vault-configs source-vault (merge current-config { enabled: enabled }))
      (print
        {
          event: "compound-vault-enabled-updated",
          vault: source-vault,
          enabled: enabled,
          block: burn-block-height
        }
      )
      (ok true)
    )
  )
)

;; --- Permissionless execution ---

(define-private (compound-internal
    (source-vault principal)
    (vault <compoundable-vault-trait>)
  )
  (begin
    ;; This explicit check protects callers of compound-for and documents why
    ;; the typed argument is required even though the registry is principal-keyed.
    (asserts! (is-eq source-vault (contract-of vault)) ERR_VAULT_IDENTITY_MISMATCH)
    (let
      (
        (config (unwrap! (map-get? vault-configs source-vault) ERR_VAULT_NOT_REGISTERED))
      )
      (begin
        (asserts! (get enabled config) ERR_VAULT_DISABLED)
        (asserts!
          (not (default-to false (map-get? compound-in-progress source-vault)))
          ERR_REENTRANT
        )
        ;; Set the guard before either external trait call. If a call or a
        ;; later assertion fails, Clarity rolls this write back atomically.
        (map-set compound-in-progress source-vault true)
        (let
          (
            (pending-rewards (try! (contract-call? vault get-pending-rewards)))
            (frequency-is-ready
              (frequency-ready
                (get last-compound-block config)
                (get min-interval config)
              )
            )
            (threshold-is-ready
              (>= pending-rewards (get min-reward-threshold config))
            )
          )
          (begin
            (asserts!
              (trigger-ready
                (get trigger-mode config)
                frequency-is-ready
                threshold-is-ready
              )
              ERR_TRIGGER_NOT_READY
            )
            (let
              (
                (actual-output
                  (try!
                    (contract-call?
                      vault
                      compound
                      (get min-output config)
                      (get destination-vault config)
                    )
                  )
                )
              )
              (begin
                (asserts! (>= actual-output (get min-output config)) ERR_OUTPUT_TOO_LOW)
                ;; This write is deliberately last. A failed vault call or
                ;; slippage check reverts the complete transaction atomically.
                (map-set vault-configs source-vault
                  (merge config { last-compound-block: burn-block-height })
                )
                (map-set compound-in-progress source-vault false)
                (print
                  {
                    event: "compound-executed",
                    vault: source-vault,
                    destination-vault: (get destination-vault config),
                    pending-rewards: pending-rewards,
                    actual-output: actual-output,
                    min-output: (get min-output config),
                    trigger-mode: (get trigger-mode config),
                    block: burn-block-height,
                    caller: contract-caller,
                    origin: tx-sender
                  }
                )
                (ok actual-output)
              )
            )
          )
        )
      )
    )
  )
)

;; @desc Trigger a configured vault using its typed trait reference.
(define-public (compound (vault <compoundable-vault-trait>))
  (compound-internal (contract-of vault) vault)
)

;; @desc Explicit identity-checking entry point useful for integrations that
;; carry a registry key separately from the typed vault reference.
(define-public (compound-for
    (source-vault principal)
    (vault <compoundable-vault-trait>)
  )
  (compound-internal source-vault vault)
)
