;; regulatory-adapter.clar
;; Conxian Protocol: Regulatory Adapter
;; Integrates KYC Registry and local attestations for compliance.

(impl-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_EXPIRED (err u6002))

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-validator principal tx-sender)

;; Map: User -> { validated: bool, expires-at: uint }
(define-map compliance-attestations principal { validated: bool, expires-at: uint })

;; Authorization
(define-private (is-owner) (is-eq tx-sender (var-get contract-owner)))
(define-private (is-validator) (is-eq tx-sender (var-get compliance-validator)))

;; Public Functions

;; @desc Check if a user is compliant
;; @param user: The user to check
;; @returns (response bool uint)
(define-public (check-clean-hands-compliance (user principal))
    (let (
        (is-sanctioned (contract-call? .kyc-registry is-sanctioned user))
        (attestation (map-get? compliance-attestations user))
    )
        (if is-sanctioned
            (ok false)
            (match attestation
                val (if (and (get validated val) (> (get expires-at val) burn-block-height))
                        (ok true)
                        (ok false))
                (ok false)
            )
        )
    )
)

;; @desc Register a new compliance attestation
(define-public (register-attestation (user principal) (expires-at uint))
    (begin
        (asserts! (or (is-validator) (is-owner)) ERR_UNAUTHORIZED)
        (map-set compliance-attestations user {
            validated: true,
            expires-at: expires-at
        })
        (ok true)
    )
)

;; Admin Functions

(define-public (set-validator (new-validator principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set compliance-validator new-validator)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-read-only (get-contract-owner) (ok (var-get contract-owner)))
