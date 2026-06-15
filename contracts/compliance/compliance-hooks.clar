;; compliance-hooks.clar
;; Conxian Compliance Hooks: KYC/AML checks and audit trails
;; Manages KYC providers and provides hooks for user verification.

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u4000)
(define-constant ERR_KYC_FAILED u4001)
(define-constant ERR_ALREADY_PROVIDER u4002)
(define-constant ERR_NOT_PROVIDER u4003)
(define-constant ERR_POLICY_VIOLATION u7000)

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-manager principal tx-sender)

(define-map kyc-providers
  principal
  {
    active: bool,
    name: (string-ascii 64),
    registered-at: uint
  }
)

;; --- Authorization ---

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-compliance-manager)
  (is-eq tx-sender (var-get compliance-manager))
)

;; --- Admin Functions ---

;; @desc Update the contract owner. Owner only.
;; @param new-owner: The new administrator principal.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Update the authorized compliance manager. Owner only.
;; @param new-manager: The new manager principal.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-compliance-manager (new-manager principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set compliance-manager new-manager)
    (ok true)
  )
)

;; @desc Register a new KYC provider. Owner or Compliance Manager only.
;; @param provider: The principal of the provider.
;; @param name: The name of the provider organization.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (add-kyc-provider (provider principal) (name (string-ascii 64)))
  (begin
    (asserts! (or (is-owner) (is-compliance-manager)) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? kyc-providers provider)) (err ERR_ALREADY_PROVIDER))
    (map-set kyc-providers provider {
      active: true,
      name: name,
      registered-at: burn-block-height
    })
    (print {
      event: "kyc-provider-added",
      provider: provider,
      name: name,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

;; @desc Revoke a KYC provider's authorization. Owner or Compliance Manager only.
;; @param provider: The principal to remove.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (remove-kyc-provider (provider principal))
  (begin
    (asserts! (or (is-owner) (is-compliance-manager)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? kyc-providers provider)) (err ERR_NOT_PROVIDER))
    (map-delete kyc-providers provider)
    (print {
      event: "kyc-provider-removed",
      provider: provider,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

;; --- Verification Functions ---

;; @desc Verify a user's KYC level (Authorized providers only).
;; @param user: The principal being verified.
;; @param kyc-level: The tier level achieved.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (verify-kyc (user principal) (kyc-level uint))
  (let ((provider-data (map-get? kyc-providers tx-sender)))
    (begin
      (asserts! (is-some provider-data) (err ERR_UNAUTHORIZED))
      (asserts! (get active (unwrap-panic provider-data)) (err ERR_UNAUTHORIZED))
      ;; Call compliance-manager to update status
      (unwrap-panic (contract-call? .compliance-manager check-user-compliance user false kyc-level false))
      (print {
        event: "kyc-verified",
        user: user,
        provider: tx-sender,
        kyc-level: kyc-level,
        timestamp: burn-block-height
      })
      (ok true)
    )
  )
)

;; @desc Log an audit event for institutional compliance.
;; @param event: The type of event (e.g. "DEPOSIT").
;; @param details: Hex-encoded event data.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (log-audit-event (event (string-ascii 50)) (details (buff 256)))
  (begin
    (print {
      event: "audit",
      type: event,
      details: details
    })
    (ok true)
  )
)

;; --- Read-only Functions ---

;; @desc Get metadata for a KYC provider
;; @param provider: The principal to query
(define-read-only (get-kyc-provider (provider principal))
  (map-get? kyc-providers provider)
)

;; @desc Check if a provider is currently active
;; @param provider: The principal to check
(define-read-only (is-active-provider (provider principal))
  (match (map-get? kyc-providers provider)
    data (get active data)
    false
  )
)

;; @desc Check if a user has a valid KYC tier
;; @param user: The principal to check
(define-read-only (check-kyc (user principal))
  (let ((status (contract-call? .kyc-registry get-identity-status user)))
    (if (>= (get tier status) u1)
      (ok true)
      (err ERR_POLICY_VIOLATION)
    )
  )
)

;; @desc Check if a user is on the sanctions list
;; @param user: The principal to check
(define-read-only (check-aml (user principal))
  (if (contract-call? .kyc-registry is-sanctioned user)
    (err ERR_POLICY_VIOLATION)
    (ok true)
  )
)
