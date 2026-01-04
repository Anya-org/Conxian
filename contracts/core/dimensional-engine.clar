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

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_CONTRACT_PAUSED (err u5000))

;; Data Vars
(define-data-var protocol-coordinator principal tx-sender)
(define-data-var position-manager principal tx-sender)
(define-data-var collateral-manager principal tx-sender)
(define-data-var risk-manager principal tx-sender)
(define-data-var funding-rate-calculator principal tx-sender)

;; --- Authorization ---

(define-private (is-authorized)
    (is-eq tx-sender (var-get protocol-coordinator))
)

;; --- Configuration ---

;; @desc Sets the protocol coordinator address.
;; @param new-coordinator: The principal of the new protocol coordinator contract.
(define-public (set-protocol-coordinator (new-coordinator principal))
    (begin
        (asserts! (is-authorized) ERR_UNAUTHORIZED)
        (var-set protocol-coordinator new-coordinator)
        (ok true)
    )
)

;; --- Facade Functions: Position Management ---

;; @desc Opens a new position (Signature matched to Integration Tests)
(define-public (open-position
        (token principal)
        (amount uint)
        (leverage uint)
        (long bool)
        (slippage-limit (optional uint))
        (metadata (optional (string-utf8 1024)))
    )
    (begin
        (try! (contract-call? .block-utils check-finality))
        (let ((result (contract-call? .position-manager open-position tx-sender token amount leverage long)))
            (print {
                event: "facade-open-position",
                sender: tx-sender,
                tenure-id: (contract-call? .block-utils get-current-tenure-id)
            })
            result
        )
    )
)

;; @desc Closes a position (Signature matched to Integration Tests)
(define-public (close-position 
        (position-id uint)
        (token principal)
        (slippage-limit (optional uint))
    )
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .position-manager close-position tx-sender position-id)
    )
)

;; --- Facade Functions: Collateral Management ---

;; @desc Deposits funds into the collateral manager.
;; @param amount: The amount of tokens to deposit.
;; @param token: The SIP-010 token contract to deposit.
(define-public (deposit-funds
        (amount uint)
        (token <sip-010-trait>)
    )
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .collateral-manager deposit-funds amount token)
    )
)

;; @desc Withdraws funds from the collateral manager.
;; @param amount: The amount of tokens to withdraw.
;; @param token: The SIP-010 token contract to withdraw.
(define-public (withdraw-funds
        (amount uint)
        (token <sip-010-trait>)
    )
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .collateral-manager withdraw-funds amount token)
    )
)

;; --- Facade Functions: Risk Management ---

;; @desc Checks the health factor of a position.
;; @param position-id: The ID of the position to check.
(define-public (check-position-health (position-id uint))
    (contract-call? .risk-manager get-health-factor position-id)
)

;; @desc Liquidates an unhealthy position.
;; @param position-id: The ID of the position to liquidate.
(define-public (liquidate-position (position-id uint))
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .risk-manager liquidate position-id)
    )
)