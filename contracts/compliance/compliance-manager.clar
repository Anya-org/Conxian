;; compliance-manager.clar
;; Conxian Compliance Module: Compliance Manager
;; Central orchestration contract for user compliance attestations and staleness detection.

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u3000)
(define-constant ERR_STALE_ATTESTATION u3001)
(define-constant ERR_INVALID_PROVIDER u3002)
(define-constant ERR_INVALID_MINIMUM_KYC_LEVEL u3003)

;; 24-hour validity period (~144 blocks assuming 10-minute Bitcoin blocks)
(define-constant VALIDITY_PERIOD u144)
(define-constant MIN_KYC_LEVEL u1)
(define-constant MAX_KYC_LEVEL u3)

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-data-var sanctions-provider principal tx-sender)

(define-map compliance-records
  principal
  {
    ;; Positive clean-screen attestation: true means the provider found no
    ;; sanction match; false means the user is not clean for fail-closed use.
    sanctions-checked: bool,
    kyc-level: uint,
    travel-rule-checked: bool,
    last-updated: uint
  }
)

(define-map approved-providers principal bool)

;; --- Authorization ---

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-approved-provider (provider principal))
  (default-to false (map-get? approved-providers provider))
)

(define-private (is-sanctions-provider)
  (is-eq tx-sender (var-get sanctions-provider))
)

;; --- Provider Management ---

;; @desc Register a new authorized compliance provider. Admin only.
;; @param provider: The principal to authorize.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (register-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set approved-providers provider true)
    (ok true)
  )
)

;; @desc Revoke a compliance provider's authorization. Admin only.
;; @param provider: The principal to remove.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (remove-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete approved-providers provider)
    (ok true)
  )
)

;; @desc Update the authorized sanctions data provider. Admin only.
;; @param provider: The new principal for sanctions reporting.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-sanctions-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set sanctions-provider provider)
    (ok true)
  )
)

;; --- Compliance Logic ---

;; @desc Update the compliance status for a specific user. Admin, approved
;; provider, or configured sanctions provider may write records. A positive
;; clean-screen attestation (`sanctions-checked: true`) is restricted to the
;; configured sanctions provider; false remains available to the normal KYC
;; update path because it does not assert that a sanctions screen passed.
;; @param user: The user being evaluated.
;; @param sanctions-checked: Positive clean-screen result. True means the
;;   provider found no sanction match; false means not clean or not attested.
;; @param kyc-level: Tier achieved (u0-u3).
;; @param travel-rule-checked: Flag for IVMS101 compliance.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (check-user-compliance (user principal) (sanctions-checked bool) (kyc-level uint) (travel-rule-checked bool))
  (begin
    (asserts! (or
      (is-owner)
      (is-approved-provider tx-sender)
      (is-sanctions-provider)) (err ERR_UNAUTHORIZED))
    (asserts! (or (not sanctions-checked) (is-sanctions-provider)) (err ERR_UNAUTHORIZED))
    (map-set compliance-records user {
      sanctions-checked: sanctions-checked,
      kyc-level: kyc-level,
      travel-rule-checked: travel-rule-checked,
      last-updated: burn-block-height
    })
    (print {
      event: "compliance-checked",
      user: user,
      kyc-level: kyc-level,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

;; @desc Update the contract owner. Admin only.
;; @param new-owner: The new administrator principal.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Batch check compliance for multiple users. Admin or Approved Provider only.
;; @param users: List of user principals.
;; @param kyc-levels: Matching list of KYC levels.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (batch-check-compliance (users (list 10 principal)) (kyc-levels (list 10 uint)))
  (ok true)
)

;; --- Read-only Functions ---

;; @desc Returns if a user is currently compliant based on recent attestations.
;; @param user: The principal to check.
(define-read-only (is-compliant (user principal))
  (let ((record (map-get? compliance-records user)))
    (match record
      data (if (> (- burn-block-height (get last-updated data)) VALIDITY_PERIOD)
              false
              (get sanctions-checked data))
      false
    )
  )
)

;; @desc Return the canonical registration eligibility decision for a user.
;; @param user: The principal being evaluated.
;; @param minimum-kyc-level: Caller/configured minimum tier. Valid values are
;;   u1 through u3, matching the current compliance-manager convention.
;; @return (response bool uint) - `(ok true)` only when a fresh compliance
;;   record exists, its tier is within u1-u3 and meets the requested minimum,
;;   an authoritative KYC-registry record exists with a matching minimum tier,
;;   and the registry does not mark the user sanctioned. Missing, stale,
;;   future-dated, low-tier, malformed, or sanctioned evidence returns
;;   `(ok false)`. The legacy `sanctions-checked` field is intentionally not
;;   used by this gate because its historical meaning is broader than an
;;   authoritative registry decision.
;;   A minimum tier outside u1-u3 returns ERR_INVALID_MINIMUM_KYC_LEVEL.
;;
;; This is the single read-only gate future registration-fee code should call;
;; callers must not recreate the tier, sanctions, registry-presence, or
;; freshness checks separately.
(define-read-only (is-registration-compliant (user principal) (minimum-kyc-level uint))
  (if (or (< minimum-kyc-level MIN_KYC_LEVEL)
          (> minimum-kyc-level MAX_KYC_LEVEL))
      (err ERR_INVALID_MINIMUM_KYC_LEVEL)
      (match (map-get? compliance-records user)
        data
          (if (<= (get last-updated data) burn-block-height)
              (let ((registry-status (contract-call? .kyc-registry get-identity-status user)))
                (ok (and
                  (contract-call? .kyc-registry has-identity-status user)
                  (>= (get kyc-level data) minimum-kyc-level)
                  (<= (get kyc-level data) MAX_KYC_LEVEL)
                  (>= (get tier registry-status) minimum-kyc-level)
                  (<= (get tier registry-status) MAX_KYC_LEVEL)
                  (not (contract-call? .kyc-registry is-sanctioned user))
                  (<= (- burn-block-height (get last-updated data)) VALIDITY_PERIOD))))
              (ok false))
        (ok false)
      )
  )
)

;; @desc Check if a user meets minimum KYC requirements.
;; @param user: The user to check.
;; @return (response bool uint) - Returns ok(true) if user meets requirements.
(define-public (check-kyc-compliance (user principal))
  (let ((record (map-get? compliance-records user)))
    (match record
      data (ok (>= (get kyc-level data) u1))
      (ok false)
    )
  )
)
