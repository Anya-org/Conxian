;; compliance-manager.clar
;; Main compliance manager that orchestrates all compliance services
;; Integrates sanctions oracle, travel rule, and compliance API

(use-trait compliance-trait .compliance-trait.compliance-trait)
(use-trait kyc-registry-trait .enterprise-traits.kyc-registry-trait)

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_COMPLIANCE_FAILED (err u9501))
(define-constant ERR_NOT_COMPLIANT (err u9502))
(define-constant ERR_INVALID_AMOUNT (err u9503))
(define-constant ERR_INVALID_KYC_TRAIT (err u9504))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-enabled bool true)
(define-data-var sanctions-oracle principal tx-sender)
(define-data-var travel-rule-service principal tx-sender)
(define-data-var compliance-api principal tx-sender)
(define-data-var kyc-registry principal tx-sender)

;; --- Compliance State ---
(define-map compliance-status {
  user: principal,
} {
  is-sanctioned: bool,
  kyc-level: uint,
  last-checked: uint,
  requires-travel-rule: bool,
})

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-compliance-enabled (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set compliance-enabled enabled)
    (print {
      event: "compliance-status-changed",
      enabled: enabled,
      changed-at: block-height,
    })
    (ok true)
  )
)

(define-public (set-compliance-services
    (new-sanctions-oracle principal)
    (new-travel-rule-service principal)
    (new-compliance-api principal)
    (new-kyc-registry principal)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set sanctions-oracle new-sanctions-oracle)
    (var-set travel-rule-service new-travel-rule-service)
    (var-set compliance-api new-compliance-api)
    (var-set kyc-registry new-kyc-registry)
    (ok true)
  )
)

;; --- Compliance Checks ---

;; @notice Comprehensive compliance check for a user
(define-public (check-user-compliance (user principal) (kyc-contract <kyc-registry-trait>))
  (begin
    (asserts! (var-get compliance-enabled) ERR_COMPLIANCE_FAILED)
    ;; Verify passed contract matches storage
    (asserts! (is-eq (contract-of kyc-contract) (var-get kyc-registry)) ERR_INVALID_KYC_TRAIT)
    
    (let ((oracle (var-get sanctions-oracle))
          (current-height block-height))
      
      ;; Check sanctions
      (match (contract-call? .sanctions-oracle is-sanctioned user)
        is-sanctioned
          (begin
            (map-set compliance-status {user: user} {
              is-sanctioned: true,
              kyc-level: u0,
              last-checked: current-height,
              requires-travel-rule: false,
            })
            (ok false)  ;; Not compliant
          )
          ;; Continue with KYC check if not sanctioned
          (check-kyc-compliance user current-height kyc-contract)
        )
        error (err error)
      )
    )
  )
)

(define-private (check-kyc-compliance (user principal) (current-height uint) (kyc-contract <kyc-registry-trait>))
  ;; Integrate with KYC registry
  (let ((kyc-level (unwrap! (contract-call? kyc-contract get-kyc-tier user) (err u9504))))
    (map-set compliance-status {user: user} {
      is-sanctioned: false,
      kyc-level: kyc-level,
      last-checked: current-height,
      requires-travel-rule: (>= kyc-level u2),
    })
    (ok true)  ;; Compliant
  )
)

;; @notice Pre-transfer compliance validation
(define-public (validate-transfer
    (from principal)
    (to principal)
    (amount uint)
    (kyc-contract <kyc-registry-trait>)
  )
  (begin
    (asserts! (var-get compliance-enabled) ERR_COMPLIANCE_FAILED)
    
    ;; Check sender compliance
    (match (check-user-compliance from kyc-contract)
      sender-ok 
      (if sender-ok
        ;; Check recipient compliance
        (match (check-user-compliance to kyc-contract)
          recipient-ok
          (if recipient-ok
            ;; Check if Travel Rule is required
            (match (check-travel-rule-requirement from to amount)
              success (ok true)
              error (err error)
            )
            (ok false)  ;; Recipient not compliant
          )
          (ok false)  ;; Sender not compliant
        )
        (ok false)
      )
      error (err error)
    )
  )
)

(define-private (check-travel-rule-requirement (from principal) (to principal) (amount uint))
  (let ((travel-rule-threshold u1000000000))
    (if (>= amount travel-rule-threshold)
      (begin
        ;; High-value transfer requires Travel Rule
        (match (contract-call? .travel-rule-service initiate-travel-rule-transfer
                "transfer"
                to to amount tx-sender "originator-info" "beneficiary-info")
          success (ok {
            compliant: true,
            travel-rule-required: true,
            transfer-id: "initiated",
          })
          error (err error)
        )
      )
      (ok {
        compliant: true,
        travel-rule-required: false,
        transfer-id: "not-required",
      })
    )
  )
)

;; --- Compliance Reporting ---

;; @notice Generate compliance report for monitoring
(define-read-only (generate-compliance-report)
  (ok {
    report-id: "report",
    generated-at: block-height,
    compliance-enabled: (var-get compliance-enabled),
    total-checks: u0,  ;; Would calculate from stored data
    sanctions-blocked: u0,
    travel-rule-transfers: u0,
    active-compliance-services: {
      sanctions-oracle: (var-get sanctions-oracle),
      travel-rule-service: (var-get travel-rule-service),
      compliance-api: (var-get compliance-api),
    },
  })
)

;; --- Read-Only Views ---

(define-read-only (get-user-compliance-status (user principal))
  (map-get? compliance-status {user: user})
)

(define-read-only (is-compliance-enabled)
  (ok (var-get compliance-enabled))
)

(define-read-only (get-compliance-services)
  (ok {
    sanctions-oracle: (var-get sanctions-oracle),
    travel-rule-service: (var-get travel-rule-service),
    compliance-api: (var-get compliance-api),
  })
)

;; --- Emergency Controls ---

(define-public (emergency-disable-compliance)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set compliance-enabled false)
    (print {
      event: "compliance-emergency-disabled",
      disabled_at: block-height,
      disabled_by: tx-sender,
    })
    (ok true)
  )
)

(define-public (emergency-enable-compliance)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set compliance-enabled true)
    (print {
      event: "compliance-emergency-enabled",
      enabled_at: block-height,
      enabled_by: tx-sender,
    })
    (ok true)
  )
)
