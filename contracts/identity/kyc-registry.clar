;; kyc-registry.clar
;; Conxian Identity Standard: KYC Registry
;; Adheres to Decentralized Modularity and Bitcoin Ethos

;; Traits
(use-trait nft-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_NOT_FOUND (err u8001))

;; Maps
(define-map user-kyc
    principal
    {
        tier: uint,
        expiry: uint,
        verified-by: principal
    }
)

;; @desc Sets the KYC tier for a user
(define-public (set-kyc-tier (user principal) (tier uint) (expiry uint))
    (begin
        ;; Authorization logic (e.g. only designated verifiers)
        (map-set user-kyc user {
            tier: tier,
            expiry: expiry,
            verified-by: tx-sender
        })
        (print {
            event: "kyc-updated",
            user: user,
            tier: tier,
            tenure-id: (contract-call? .block-utils get-current-tenure-id)
        })
        (ok true)
    )
)

;; @desc Gets the KYC tier for a user
(define-read-only (get-kyc-tier (user principal))
    (match (map-get? user-kyc user)
        data (ok (get tier data))
        (ok u0) ;; Default to Tier 0 (Not verified)
    )
)

;; @desc Checks if a user has a minimum KYC tier
(define-read-only (has-min-tier (user principal) (min-tier uint))
    (let ((current-tier (unwrap-panic (get-kyc-tier user))))
        (ok (>= current-tier min-tier))
    )
)
