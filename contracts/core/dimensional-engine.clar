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

(define-public (deposit-funds
        (amount uint)
        (token <sip-010-trait>)
    )
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .collateral-manager deposit-funds amount token)
    )
)

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

(define-public (check-position-health (position-id uint))
    (contract-call? .risk-manager get-health-factor position-id)
)

(define-public (liquidate-position (position-id uint))
    (begin
        (try! (contract-call? .block-utils check-finality))
        (contract-call? .risk-manager liquidate position-id)
    )
)