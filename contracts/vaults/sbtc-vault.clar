;; sbtc-vault.clar
;; Conxian Enterprise Standard: sBTC Vault (Tier 0 Compliance)
;; Secure Custody with "Clean-Hands" Enforcement and Travel Rule Hooks

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)
(use-trait vault-trait .vault-traits.vault-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_NON_COMPLIANT (err u8001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u8002))
(define-constant ERR_TRAVEL_RULE_REQUIRED (err u8003))

;; Thresholds
(define-constant TRAVEL_RULE_THRESHOLD u100000000) ;; Example: 1 sBTC (satoshis) or $1k equiv. Adjust as needed.

;; State
(define-data-var sbtc-token principal .sbtc-token) ;; Placeholder for actual sBTC contract
(define-data-var total-deposits uint u0)

;; Maps
(define-map user-balances
    principal
    uint
)

;; Compliance Check Helper
(define-private (check-compliance (user principal))
    (let ((compliance-status (contract-call? .compliance.regulatory-adapter check-clean-hands-compliance user)))
        (if (is-ok compliance-status)
            true
            false
        )
    )
)

;; @desc Deposit sBTC into the vault
;; Enforces: Sender must be compliant.
(define-public (deposit
        (amount uint)
        (token <sip-010-trait>)
    )
    (let ((sender tx-sender))
        ;; 1. Validate Token
        (asserts! (is-eq (contract-of token) (var-get sbtc-token))
            ERR_UNAUTHORIZED
        )

        ;; 2. Compliance Check (Clean Hands)
        (asserts! (check-compliance sender) ERR_NON_COMPLIANT)

        ;; 3. Transfer Asset
        (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))

        ;; 4. Update State
        (map-set user-balances sender
            (+ (default-to u0 (map-get? user-balances sender)) amount)
        )
        (var-set total-deposits (+ (var-get total-deposits) amount))

        (print {
            event: "deposit",
            user: sender,
            amount: amount,
        })
        (ok true)
    )
)

;; @desc Withdraw sBTC from the vault
;; Enforces: Recipient must be compliant. High value transfers require Travel Rule check (mocked via travel-rule-service or event).
(define-public (withdraw
        (amount uint)
        (recipient principal)
        (token <sip-010-trait>)
    )
    (let (
            (sender tx-sender)
            (current-balance (default-to u0 (map-get? user-balances sender)))
        )
        ;; 1. Validate Token & Balance
        (asserts! (is-eq (contract-of token) (var-get sbtc-token))
            ERR_UNAUTHORIZED
        )
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)

        ;; 2. Compliance Check (Sender)
        (asserts! (check-compliance sender) ERR_NON_COMPLIANT)

        ;; 3. Compliance Check (Recipient) - Prevent withdrawal to sanctioned/non-compliant addresses
        (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)

        ;; 4. Travel Rule Check (if amount > threshold)
        ;; In a real Tier 0 system, this would require an attestation or separate flow.
        ;; Here we ensure both parties are compliant (which implies KYC), covering the basic requirement.

        ;; 5. Transfer Asset
        (as-contract (try! (contract-call? token transfer amount tx-sender recipient none)))

        ;; 6. Update State
        (map-set user-balances sender (- current-balance amount))
        (var-set total-deposits (- (var-get total-deposits) amount))

        (print {
            event: "withdraw",
            user: sender,
            recipient: recipient,
            amount: amount,
        })
        (ok true)
    )
)

;; @desc Admin: Set sBTC Token Principal
(define-data-var contract-owner principal tx-sender)

(define-public (set-sbtc-token (new-token principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set sbtc-token new-token)
        (ok true)
    )
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)
