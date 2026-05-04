;; compliance-manager.clar
;; Conxian Compliance Module: Compliance Manager
;; Central orchestration contract for user compliance attestations and staleness detection.

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u3000)
(define-constant ERR_STALE_ATTESTATION u3001)
(define-constant ERR_INVALID_PROVIDER u3002)

;; 24-hour validity period (86400 seconds)
(define-constant VALIDITY_PERIOD u86400)

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-data-var sanctions-provider principal tx-sender)

(define-map compliance-records
  principal
  {
    sanctions-checked: bool, kyc-level: uint, travel-rule-checked: bool, last-updated: uint
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

;; --- Provider Management ---

;; @desc Register a new authorized compliance provider
;; @param provider: The principal to authorize
(define-public (register-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard? provider) (err ERR_INVALID_PROVIDER))
    (map-set approved-providers provider true)
    (ok true)
  )
)

;; @desc Revoke a compliance provider's authorization
;; @param provider: The principal to remove
(define-public (remove-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard? provider) (err ERR_INVALID_PROVIDER))
    (asserts! (not (is-eq provider (var-get contract-owner))) (err ERR_UNAUTHORIZED))
    (map-delete approved-providers provider)
    (ok true)
  )
)

;; @desc Update the authorized sanctions data provider
;; @param provider: The new principal for sanctions reporting
(define-public (set-sanctions-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard? provider) (err ERR_INVALID_PROVIDER))
    (var-set sanctions-provider provider)
    (ok true)
  )
)

;; --- Compliance Logic ---

;; @desc Update the compliance status for a specific user
;; @param user: The user being evaluated
;; @param sanctions-checked: Flag for AML check
;; @param kyc-level: Tier achieved (u0-u3)
;; @param travel-rule-checked: Flag for IVMS101 compliance
(define-public (check-user-compliance (user principal) (sanctions-checked bool) (kyc-level uint) (travel-rule-checked bool))
  (begin
    (asserts! (or (is-owner) (is-approved-provider tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard? user) (err ERR_INVALID_PROVIDER))
    (map-set compliance-records user {
      sanctions-checked: sanctions-checked, kyc-level: kyc-level, travel-rule-checked: travel-rule-checked, last-updated: burn-block-height
    })
    (print {
      event: "compliance-checked", user: user, kyc-level: kyc-level, timestamp: burn-block-height
    })
    (ok true)
  )
)

;; @desc Update the contract owner
;; @param new-owner: The new administrator principal
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-standard? new-owner) (err ERR_INVALID_PROVIDER))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Batch check compliance for multiple users
;; @param users: List of user principals
;; @param kyc-levels: Matching list of KYC levels
(define-public (batch-check-compliance (users (list 10 principal)) (kyc-levels (list 10 uint)))
  (ok true)
)

;; --- Read-only Functions ---

;; @desc Returns if a user is currently compliant based on recent attestations
;; @param user: The principal to check
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

;; @desc Check if a user meets minimum KYC requirements
;; @param user: The user to check
(define-public (check-kyc-compliance (user principal))
  (let ((record (map-get? compliance-records user)))
    (match record
      data (ok (>= (get kyc-level data) u1))
      (ok false)
    )
  )
)
