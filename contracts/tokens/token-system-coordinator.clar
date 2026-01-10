;; token-system-coordinator.clar
;; Conxian Enterprise Standard: Token System Coordinator (Facade)
;; Central entry point for token minting, burning, and specialized operations.
;; Orchestrates actions across CXD, CXVG, and other system tokens.
;; Tier 0: "Hands-Off" Coordination with Compliance.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_TOKEN (err u1001))
(define-constant ERR_NON_COMPLIANT (err u1002))

;; Data Vars
(define-data-var coordinator-admin principal tx-sender) ;; Ops Engine or Timelock

;; Authorized Minters (e.g. Emission Controller, AMM, Staking)
(define-map authorized-minters principal bool)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get coordinator-admin))
)

(define-private (is-authorized-minter)
    (default-to false (map-get? authorized-minters tx-sender))
)

;; Compliance
(define-private (check-compliance (user principal))
    (let ((compliance-status (contract-call? .compliance.regulatory-adapter check-clean-hands-compliance user)))
        (if (is-ok compliance-status) true false)
    )
)

;; --- Administration ---

(define-public (set-coordinator-admin (new-admin principal))
    (begin
        (asserts! (is-admin) ERR_UNAUTHORIZED)
        (var-set coordinator-admin new-admin)
        (ok true)
    )
)

(define-public (set-minter-status (minter principal) (status bool))
    (begin
        (asserts! (is-admin) ERR_UNAUTHORIZED)
        (map-set authorized-minters minter status)
        (ok true)
    )
)

;; --- Facade: Minting ---

;; @desc Mints CXD (Revenue Token)
;; Only authorized minters (e.g. Emission Controller) can trigger this via the coordinator.
(define-public (mint-cxd (amount uint) (recipient principal))
    (begin
        (asserts! (is-authorized-minter) ERR_UNAUTHORIZED)
        ;; Enforce Clean Hands on Recipient
        (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)
        
        (contract-call? .cxd-token mint amount recipient)
    )
)

;; @desc Mints CXVG (Voting Token)
;; Only authorized minters can trigger this.
(define-public (mint-cxvg (amount uint) (recipient principal))
    (begin
        (asserts! (is-authorized-minter) ERR_UNAUTHORIZED)
        ;; Enforce Clean Hands on Recipient
        (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)
        
        (contract-call? .cxvg-token mint amount recipient)
    )
)

;; --- Facade: Burning ---

(define-public (burn-cxd (amount uint) (sender principal))
    (begin
        ;; Anyone can burn their own tokens, or authorized operators can burn from users (if logic allows, here strict sender check)
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (contract-call? .cxd-token burn amount sender)
    )
)

(define-public (burn-cxvg (amount uint) (sender principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (contract-call? .cxvg-token burn amount sender)
    )
)
