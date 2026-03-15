;; compliance-hooks.clar
;; Conxian Compliance Hooks: KYC/AML checks and audit trails
;;
;; REPAIRED: Added proper authorization for KYC provider management

(define-constant ERR_UNAUTHORIZED u4000)
(define-constant ERR_KYC_FAILED u4001)
(define-constant ERR_ALREADY_PROVIDER u4002)
(define-constant ERR_NOT_PROVIDER u4003)

;; Data vars
(define-data-var contract-owner principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var compliance-manager principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

(define-map kyc-providers
    principal
    {
        active: bool
        name: (string-ascii 64)
        registered-at: uint
    }
)

(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-compliance-manager)
    (is-eq tx-sender (var-get compliance-manager))
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-compliance-manager (new-manager principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set compliance-manager new-manager)
        (ok true)
    )
)

(define-public (add-kyc-provider (provider principal) (name (string-ascii 64)))
    (begin
        (asserts! (or (is-owner) (is-compliance-manager)) (err ERR_UNAUTHORIZED))
        (asserts! (is-none (map-get? kyc-providers provider)) (err ERR_ALREADY_PROVIDER))
        (map-set kyc-providers provider {
            active: true
            name: name
            registered-at: burn-block-height
        })
        (print {
            event: "kyc-provider-added"
            provider: provider
            name: name
            timestamp: burn-block-height
        })
        (ok true)
    )
)

(define-public (remove-kyc-provider (provider principal))
    (begin
        (asserts! (or (is-owner) (is-compliance-manager)) (err ERR_UNAUTHORIZED))
        (asserts! (is-some (map-get? kyc-providers provider)) (err ERR_NOT_PROVIDER))
        (map-delete kyc-providers provider)
        (print {
            event: "kyc-provider-removed"
            provider: provider
            timestamp: burn-block-height
        })
        (ok true)
    )
)

(define-public (verify-kyc (user principal) (kyc-level uint))
    (let ((provider-data (map-get? kyc-providers tx-sender)))
        (begin
            (asserts! (is-some provider-data) (err ERR_UNAUTHORIZED))
            (asserts! (get active (unwrap-panic provider-data)) (err ERR_UNAUTHORIZED))
            ;; Call compliance-manager to update status
            (try! (contract-call? .compliance-manager check-user-compliance user false kyc-level false))
            (print {
                event: "kyc-verified"
                user: user
                provider: tx-sender
                kyc-level: kyc-level
                timestamp: burn-block-height
            })
            (ok true)
        )
    )
)

(define-read-only (get-kyc-provider (provider principal))
    (map-get? kyc-providers provider)
)

(define-read-only (is-active-provider (provider principal))
    (match (map-get? kyc-providers provider)
        data (get active data)
        false
    )
)

(define-public (log-audit-event (event (string-ascii 50)) (details (buff 256)))
    (begin
        (print {
            event: "audit"
            type: event
            details: details
        })
        (ok true)
    )
)

;; --- Test Alignment Hooks ---

(define-constant ERR_POLICY_VIOLATION u7000)

(define-read-only (check-kyc (user principal))
  (let ((status (contract-call? .kyc-registry get-identity-status user)))
    (if (>= (get tier status) u1)
      (ok true)
      (err ERR_POLICY_VIOLATION)
    )
  )
)

(define-read-only (check-aml (user principal))
  (if (contract-call? .kyc-registry is-sanctioned user)
    (err ERR_POLICY_VIOLATION)
    (ok true)
  )
)
