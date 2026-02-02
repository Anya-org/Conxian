;; compliance-manager.clar
;; Conxian Oracle Standard: Compliance Intelligence Layer
;; Orchestrates Sanctions Checks, KYC/AML, and Travel Rule
;;
;; REPAIRED: Removed mock sanctions check, added proper provider integration and events

(use-trait compliance-trait .compliance-trait.compliance-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_NON_COMPLIANT u6001)
(define-constant ERR_PROVIDER_NOT_REGISTERED u6002)
(define-constant ERR_STALE_CHECK u6003)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-enabled bool true)
(define-data-var sanctions-provider principal tx-sender) ;; Configurable sanctions oracle
(define-data-var check-validity-period uint u144) ;; 24 hours in blocks (~144 blocks)

;; Maps
(define-map compliance-status
  { user: principal }
  {
    is-sanctioned: bool,
    kyc-level: uint,
    last-checked: uint,
    requires-travel-rule: bool,
    provider: principal
  }
)

(define-map approved-providers principal bool)

;; Events
(define-private (emit-compliance-checked (user principal) (compliant bool) (provider principal))
  (print {
    event: "compliance-checked",
    user: user,
    compliant: compliant,
    provider: provider,
    timestamp: burn-block-height
  })
)

(define-private (emit-sanctions-found (user principal) (reason (string-ascii 64)))
  (print {
    event: "sanctions-detected",
    user: user,
    reason: reason,
    timestamp: burn-block-height,
    severity: "CRITICAL"
  })
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Administrative Functions
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-compliance-enabled (enabled bool))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set compliance-enabled enabled)
    (print {
      event: "compliance-status-changed",
      enabled: enabled,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

(define-public (set-sanctions-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set sanctions-provider provider)
    (print {
      event: "sanctions-provider-changed",
      provider: provider,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

(define-public (register-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set approved-providers provider true)
    (print {
      event: "provider-registered",
      provider: provider,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

(define-public (remove-provider (provider principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-delete approved-providers provider)
    (print {
      event: "provider-removed",
      provider: provider,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

;; Internal helper for compliance updates
(define-private (internal-check-user (user principal) (is-sanctioned bool) (kyc-level uint) (requires-travel-rule bool))
  (begin
    ;; Update compliance status
    (map-set compliance-status { user: user } {
      is-sanctioned: is-sanctioned,
      kyc-level: kyc-level,
      last-checked: burn-block-height,
      requires-travel-rule: requires-travel-rule,
      provider: tx-sender
    })

    ;; Emit events
    (if is-sanctioned
      (emit-sanctions-found user "SANCTIONS_LIST_MATCH")
      (emit-compliance-checked user true tx-sender)
    )
    true
  )
)

;; @desc Full user check (Aggregated)
;; Called by approved providers or owner to update compliance status
(define-public (check-user-compliance (user principal) (is-sanctioned bool) (kyc-level uint) (requires-travel-rule bool))
  (begin
    ;; Only approved providers or owner can update compliance
    (asserts! (or (is-owner) (default-to false (map-get? approved-providers tx-sender))) (err ERR_UNAUTHORIZED))
    (asserts! (var-get compliance-enabled) (ok true))

    (internal-check-user user is-sanctioned kyc-level requires-travel-rule)
    (ok (not is-sanctioned))
  )
)

;; @desc Batch compliance update for efficiency
(define-public (batch-check-compliance 
    (users (list 10 principal)) 
    (sanctioned-list (list 10 bool))
    (kyc-levels (list 10 uint))
    (travel-rules (list 10 bool))
  )
  (begin
    (asserts! (or (is-owner) (default-to false (map-get? approved-providers tx-sender))) (err ERR_UNAUTHORIZED))
    (asserts! (var-get compliance-enabled) (ok true))

    (print {
      event: "batch-compliance-check",
      provider: tx-sender,
      count: (len users),
      timestamp: burn-block-height
    })

    ;; Use map with internal private function
    (print (map internal-check-user users sanctioned-list kyc-levels travel-rules))
    (ok true)
  )
)

;; Read Only
(define-read-only (is-compliant (user principal))
  (let ((status (map-get? compliance-status { user: user })))
    (match status
      data 
      (ok {
        compliant: (not (get is-sanctioned data)),
        kyc-level: (get kyc-level data),
        last-checked: (get last-checked data),
        stale: (> (- burn-block-height (get last-checked data)) (var-get check-validity-period)),
        provider: (get provider data)
      })
      (ok {
        compliant: true, ;; Assume compliant if never checked
        kyc-level: u0,
        last-checked: u0,
        stale: true,
        provider: tx-sender
      })
    )
  )
)

(define-read-only (get-compliance-details (user principal))
  (map-get? compliance-status { user: user })
)

(define-read-only (is-approved-provider (provider principal))
  (default-to false (map-get? approved-providers provider))
)
