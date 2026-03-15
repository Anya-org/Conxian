;; dimensional-engine.clar
;; Conxian Protocol Standard Contract

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
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_CONTRACT_PAUSED u5000)
(define-constant ERR_NON_COMPLIANT u5001)
(define-constant ERR_MODULE_NOT_ACTIVE u5002)
(define-constant ERR_MODULE_NOT_FOUND u5003)

;; Data Vars
(define-data-var protocol-coordinator principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var regulatory-adapter-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var conxian-protocol-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; --- Authorization ---

(define-private (is-authorized)
  (is-eq tx-sender (var-get protocol-coordinator))
)

;; --- Internal Guards ---

(define-private (guard-entry (protocol-status { compliant: bool, paused: bool, tenure-id: (optional uint), version: (string-ascii 2) }))
  (begin
    (asserts! (not (get paused protocol-status)) (err ERR_CONTRACT_PAUSED))
    (asserts! (get compliant protocol-status) (err ERR_NON_COMPLIANT))
    (ok true)
  )
)

;; --- Configuration ---


;; @desc Set protocol coordinator
;; @returns (response bool uint)
(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)

;; --- Facade Functions: Position Management ---

(define-private (get-module-contract (name (string-ascii 32)))
  (let ((module-data (contract-call? .conxian-protocol get-module name)))
    (match module-data
      data (begin
        (asserts! (get active data) (err ERR_MODULE_NOT_ACTIVE))
        (ok (get contract data))
      )
      (err u5003)
    )
  )
)


;; @desc Open position
;; @returns (response bool uint)
(define-public (open-position
    (position-manager <position-manager-trait>)
    (token principal)
    (amount uint)
    (leverage uint)
    (long bool)
    (slippage-limit (optional uint))
    (metadata (optional (string-utf8 1024)))
  )
  (begin
    (let (
        (protocol-status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
        (registered-manager (unwrap-panic (get-module-contract "position-manager")))
      )
      (asserts! (is-eq (contract-of position-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (try! (guard-entry protocol-status))
      (let ((result (contract-call? position-manager open-position tx-sender token amount leverage long)))
        (print {
          event: "facade-open-position",
          sender: tx-sender,
          tenure-id: (get tenure-id protocol-status),
        })
        result
      )
    )
  )
)


;; @desc Close position
;; @returns (response bool uint)
(define-public (close-position
    (position-manager <position-manager-trait>)
    (position-id uint)
    (token principal)
    (slippage-limit (optional uint))
  )
  (begin
    (let (
        (protocol-status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
        (registered-manager (unwrap-panic (get-module-contract "position-manager")))
      )
      (asserts! (is-eq (contract-of position-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (try! (guard-entry protocol-status))
      (contract-call? position-manager close-position tx-sender position-id)
    )
  )
)

;; --- Facade Functions: Collateral Management ---


;; @desc Deposit funds
;; @returns (response bool uint)
(define-public (deposit-funds
    (collateral-manager <collateral-manager-trait>)
    (amount uint)
    (token-trait <sip-010-trait>)
  )
  (begin
    (let (
        (protocol-status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
        (registered-manager (unwrap-panic (get-module-contract "collateral-manager")))
      )
      (asserts! (is-eq (contract-of collateral-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (try! (guard-entry protocol-status))
      (contract-call? collateral-manager deposit-funds amount token-trait)
    )
  )
)


;; @desc Withdraw funds
;; @returns (response bool uint)
(define-public (withdraw-funds
    (collateral-manager <collateral-manager-trait>)
    (amount uint)
    (token-trait <sip-010-trait>)
  )
  (begin
    (let (
        (protocol-status (unwrap-panic (contract-call? .conxian-protocol get-protocol-status)))
        (registered-manager (unwrap-panic (get-module-contract "collateral-manager")))
      )
      (asserts! (is-eq (contract-of collateral-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (try! (guard-entry protocol-status))
      (contract-call? collateral-manager withdraw-funds amount token-trait)
    )
  )
)

;; --- Facade Functions: Risk Management ---


;; @desc Check position health
;; @returns (response bool uint)
(define-public (check-position-health
    (risk-manager <risk-manager-trait>)
    (position-id uint)
  )
  (begin
    (let ((registered-manager (try! (get-module-contract "risk-manager"))))
      (asserts! (is-eq (contract-of risk-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (contract-call? risk-manager get-health-factor position-id)
    )
  )
)


;; @desc Liquidate position
;; @returns (response bool uint)
(define-public (liquidate-position
    (risk-manager <risk-manager-trait>)
    (position-id uint)
  )
  (begin
    (let ((registered-manager (try! (get-module-contract "risk-manager"))))
      (asserts! (is-eq (contract-of risk-manager) registered-manager) (err ERR_UNAUTHORIZED))
      (contract-call? risk-manager liquidate position-id)
    )
  )
)
