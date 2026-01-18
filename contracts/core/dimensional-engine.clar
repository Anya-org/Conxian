;; dimensional-engine.clar
;; Facade contract for the Core Module
;; Central entry point for position management, collateral, and risk.
;; Adheres to Decentralized Modularity and Bitcoin Ethos

;; Traits
(use-trait position-manager-trait .core-traits.position-manager-trait)
(use-trait collateral-manager-trait .core-traits.collateral-manager-trait)
(use-trait risk-manager-trait .core-traits.risk-manager-trait)
(use-trait funding-rate-trait .core-traits.funding-rate-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_CONTRACT_PAUSED (err u5000))
(define-constant ERR_NON_COMPLIANT (err u5001))

;; Data Vars
(define-data-var protocol-coordinator principal tx-sender)
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var block-utils-contract principal .block-utils)
(define-data-var conxian-protocol-contract principal .conxian-protocol)

;; --- Authorization ---

;; @desc Checks if the transaction sender is the authorized protocol coordinator.
;; @returns bool
(define-private (is-authorized)
  (is-eq tx-sender (var-get protocol-coordinator))
)

;; @desc Checks if a user is compliant by calling the regulatory adapter.
;; @param user: The principal of the user to check.
;; @returns bool
(define-private (check-compliance (user principal))
  (is-ok (contract-call? .regulatory-adapter check-clean-hands-compliance user))
)

;; --- Internal Guards ---

;; @desc Centralized entry guard for standard pre-flight checks.
;; @param is-paused: A boolean indicating if the protocol is paused.
;; @returns (response bool)
(define-private (guard-entry (is-paused bool))
  (begin
    (asserts! (not is-paused) ERR_CONTRACT_PAUSED)
    (asserts! (check-compliance tx-sender) ERR_NON_COMPLIANT)
    (ok true)
  )
)

;; --- Configuration ---

;; @desc Sets the protocol coordinator address, which controls administrative functions.
;; @param new-coordinator: The principal of the new protocol coordinator contract.
;; @returns (response bool)
(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)

;; --- Facade Functions: Position Management ---

;; @desc Opens a new trading position by delegating to the position manager.
;; @param token: The principal of the token being traded.
;; @param amount: The amount of the token to use for the position.
;; @param leverage: The leverage to apply to the position.
;; @param long: A boolean indicating if the position is long (true) or short (false).
;; @param slippage-limit: An optional slippage limit for the trade.
;; @param metadata: Optional metadata for the position.
;; @returns (response uint) The ID of the new position.
(define-public (open-position
    (token principal)
    (amount uint)
    (leverage uint)
    (long bool)
    (slippage-limit (optional uint))
    (metadata (optional (string-utf8 1024)))
  )
  (begin
    (let ((protocol-status (try! (contract-call? .conxian-protocol get-protocol-status)))
          (is-paused (get paused protocol-status)))
      (try! (guard-entry is-paused)))
    (let ((position-manager .position-manager)
          (result (contract-call? .position-manager open-position tx-sender token amount
              leverage long
            )))
      (print {
        event: "facade-open-position",
        sender: tx-sender,
        tenure-id: (get tenure-id protocol-status),
      })
      result
    )
  )
)

;; @desc Closes an existing trading position by delegating to the position manager.
;; @param position-id: The ID of the position to close.
;; @param token: The principal of the token being traded.
;; @param slippage-limit: An optional slippage limit for the trade.
;; @returns (response bool)
(define-public (close-position
    (position-id uint)
    (token principal)
    (slippage-limit (optional uint))
  )
  (begin
    (let ((is-paused (unwrap-panic (contract-call? .conxian-protocol is-paused))))
      (try! (guard-entry is-paused)))
    (contract-call? .position-manager close-position tx-sender position-id)
  )
)

;; --- Facade Functions: Collateral Management ---

;; @desc Deposits funds into the collateral manager.
;; @param amount: The amount of tokens to deposit.
;; @param token: The SIP-010 token contract to deposit.
;; @returns (response bool)
(define-public (deposit-funds
    (amount uint)
    (token .sip-standards.sip-010-ft-trait)
  )
  (begin
    (let ((is-paused (unwrap-panic (contract-call? .conxian-protocol is-paused))))
      (try! (guard-entry is-paused)))
    (contract-call? .collateral-manager deposit-funds amount token)
  )
)

;; @desc Withdraws funds from the collateral manager.
;; @param amount: The amount of tokens to withdraw.
;; @param token: The SIP-010 token contract to withdraw.
;; @returns (response bool)
(define-public (withdraw-funds
    (amount uint)
    (token .sip-standards.sip-010-ft-trait)
  )
  (begin
    (let ((is-paused (unwrap-panic (contract-call? .conxian-protocol is-paused))))
      (try! (guard-entry is-paused)))
    (contract-call? .collateral-manager withdraw-funds amount token)
  )
)

;; --- Facade Functions: Risk Management ---

;; @desc Checks the health factor of a position by delegating to the risk manager.
;; @param position-id: The ID of the position to check.
;; @returns (response uint) The health factor of the position.
(define-public (check-position-health (position-id uint))
    (contract-call? .risk-manager get-health-factor position-id)
)

;; @desc Liquidates an unhealthy position by delegating to the risk manager.
;; @param position-id: The ID of the position to liquidate.
;; @returns (response bool)
(define-public (liquidate-position (position-id uint))
  (begin
    ;; Removed call to non-existent `check-finality` function.
    (contract-call? .risk-manager liquidate position-id)
  )
)

(define-private (get-module-contract (name (string-ascii 32)))
  (let ((module-data (unwrap-panic (contract-call? .conxian-protocol get-module name))))
    (asserts! (get active module-data) (err u5002))
    (get contract module-data)
  )
)
