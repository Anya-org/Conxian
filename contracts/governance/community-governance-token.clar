;; community-governance-token.clar
;; Conxian PaaS Standard: Community Governance Token Template
;; Standard SIP-010 Token with Governance Checkpoints (Vote Weighting)
;; Tier 0: "Hands-Off" DAO Token

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_TOKEN_OWNER (err u1001))
(define-constant ERR_NON_COMPLIANT (err u1002))

;; Data Vars
(define-data-var token-name (string-ascii 32) "Community Governance Token")
(define-data-var token-symbol (string-ascii 10) "CGT")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal tx-sender)

;; Token
(define-fungible-token cgt)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Compliance
(define-private (check-compliance (user principal))
    (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
        (if (is-ok compliance-status) true false)
    )
)

;; SIP-010 Interface
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        
        ;; Enforce Clean Hands Compliance for Sender AND Recipient
        (asserts! (check-compliance sender) ERR_NON_COMPLIANT)
        (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)

        (try! (ft-transfer? cgt amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance cgt who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply cgt))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Governance / Minting
;; Only the owner (DAO/Timelock) can mint
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (ft-mint? cgt amount recipient)
    )
)

;; Admin
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set token-uri new-uri)
        (ok true)
    )
)
