;; compliance-manager.clar
;; Conxian Oracle Standard: Compliance Intelligence Layer
;; Orchestrates Sanctions Checks, KYC/AML, and Travel Rule

;; Traits
(use-trait compliance-trait .compliance-trait.compliance-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_NON_COMPLIANT (err u6001))

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-enabled bool true)

;; Maps
(define-map compliance-status
  { user: principal }
  {
    is-sanctioned: bool,
    kyc-level: uint,
    last-checked: uint,
    requires-travel-rule: bool,
  }
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Administrative Functions
(define-public (set-owner (new-owner principal))
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
      tenure-id: (contract-call? .block-utils get-current-tenure-id),
    })
    (ok true)
  )
)

;; @desc Full user check (Aggregated)
(define-public (check-user-compliance (user principal))
  (let ((current-height block-height))
    (begin
      (asserts! (var-get compliance-enabled) (ok true))
      ;; 1. Check Sanctions (Mock integration)
      (let ((sanction-check false)) ;; Mock implementation
        (if sanction-check
          (begin
            (map-set compliance-status { user: user } {
              is-sanctioned: true,
              kyc-level: u0,
              last-checked: current-height,
              requires-travel-rule: false,
            })
            (ok false)
          )
          (ok true)
        )
      )
    )
  )
)

;; Read Only
(define-read-only (is-compliant (user principal))
  (let ((status (map-get? compliance-status { user: user })))
    (match status
      data
      (ok (not (get is-sanctioned data)))
      (ok true) ;; Assume compliant if never checked
    )
  )
)
