;; dimensional-engine.clar
;; Facade contract for the Core Module
;; Central entry point for position management, collateral, and risk.

(use-trait position-manager-trait .core-traits.position-manager-trait)
(use-trait collateral-manager-trait .core-traits.collateral-manager-trait)
(use-trait risk-manager-trait .core-traits.risk-manager-trait)
(use-trait funding-rate-trait .core-traits.funding-rate-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_CONTRACT_PAUSED (err u5000))

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

(define-public (set-position-manager (new-manager principal))
    (begin
        (asserts! (is-authorized) ERR_UNAUTHORIZED)
        (var-set position-manager new-manager)
        (ok true)
    )
)

(define-public (set-collateral-manager (new-manager principal))
    (begin
        (asserts! (is-authorized) ERR_UNAUTHORIZED)
        (var-set collateral-manager new-manager)
        (ok true)
    )
)

(define-public (set-risk-manager (new-manager principal))
    (begin
        (asserts! (is-authorized) ERR_UNAUTHORIZED)
        (var-set risk-manager new-manager)
        (ok true)
    )
)

(define-public (set-funding-rate-calculator (new-calculator principal))
    (begin
        (asserts! (is-authorized) ERR_UNAUTHORIZED)
        (var-set funding-rate-calculator new-calculator)
        (ok true)
    )
)

;; --- Facade Functions: Position Management ---

(define-public (open-position
        (token principal)
        (amount uint)
        (leverage uint)
        (long bool)
    )
    (contract-call? .position-manager open-position tx-sender token amount
        leverage long
    )
)

(define-public (close-position (position-id uint))
    (contract-call? .position-manager close-position tx-sender position-id)
)

;; --- Facade Functions: Collateral Management ---

(define-public (deposit-funds
        (token principal)
        (amount uint)
    )
    (contract-call? .collateral-manager deposit tx-sender token amount)
)

(define-public (withdraw-funds
        (token principal)
        (amount uint)
    )
    (contract-call? .collateral-manager withdraw tx-sender token amount)
)

;; --- Facade Functions: Risk Management ---

(define-public (check-position-health (position-id uint))
    (contract-call? .risk-manager get-health-factor position-id)
)

(define-public (liquidate-position (position-id uint))
    (contract-call? .risk-manager liquidate position-id)
)