;; regulatory-adapter.clar
;; Conxian Finance: Regulatory Adapter (Clean-Hands Compliance)
;; Enhanced Institutional Hardening - MiCA Readiness

;; Traits
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_INVALID_PROOF u6001)
(define-constant ERR_BLACKLISTED u6002)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var regulatory-authority principal tx-sender)
(define-data-var authority-pubkey (buff 33) 0x00)

;; Maps
(define-map compliance-status
  { user: principal }
  {
    clean-hands: bool,
    verified-at: uint,
    jurisdiction: (string-ascii 64),
    tier: uint
  }
)

(define-map blacklist principal bool)

(define-map passported-jurisdictions (string-ascii 64) bool)

;; Read-only: Check Clean-Hands Compliance
(define-read-only (check-clean-hands-compliance (user principal))
  (let (
    (status (map-get? compliance-status { user: user }))
    (is-blacklisted (default-to false (map-get? blacklist user)))
  )
    (if is-blacklisted
      (err ERR_BLACKLISTED)
      (match status
        record (if (get clean-hands record)
          (ok true)
          (ok false)
        )
        (ok false) ;; Default: not verified
      )
    )
  )
)

;; Admin: Add to Whitelist
(define-public (add-to-whitelist (user principal) (jurisdiction (string-ascii 64)) (tier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set compliance-status { user: user } {
      clean-hands: true,
      verified-at: burn-block-height,
      jurisdiction: jurisdiction,
      tier: tier
    })
    (print { event: "compliance-verified", user: user, jurisdiction: jurisdiction, tier: tier })
    (ok true)
  )
)

;; Admin: Add to Blacklist
(define-public (add-to-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set blacklist user true)
    ;; Human-readable audit trails (Clarity 4 Vision)
    (print {
      event: "user-blacklisted",
      user: user,
      audit-time: burn-block-height,
      status: "LOCKED"
    })
    (ok true)
  )
)

;; Admin: Remove from Blacklist
(define-public (remove-from-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-delete blacklist user)
    (print { event: "user-removed-from-blacklist", user: user, timestamp: burn-block-height })
    (ok true)
  )
)

;; @desc Generates a compliance report for regulatory bodies (MiCA Readiness)
(define-read-only (generate-compliance-report (user principal))
  (let (
    (status (default-to { clean-hands: false, verified-at: u0, jurisdiction: "UNKNOWN", tier: u0 }
            (map-get? compliance-status { user: user })))
    (blacklisted (default-to false (map-get? blacklist user)))
  )
    (ok {
      user: user,
      status: (if blacklisted "BLACKLISTED" (if (get clean-hands status) "VERIFIED" "UNVERIFIED")),
      jurisdiction: (get jurisdiction status),
      tier: (get tier status),
      last-audit: (get verified-at status)
    })
  )
)

;; Admin: Update Authority
(define-public (update-authority (new-authority principal) (new-pubkey (buff 33)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set regulatory-authority new-authority)
    (var-set authority-pubkey new-pubkey)
    (ok true)
  )
)

;; Transfer Ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Passporting Logic (MiCA Compliance)
(define-public (set-passport-status (jurisdiction (string-ascii 64)) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set passported-jurisdictions jurisdiction active)
    (ok true)
  )
)

(define-read-only (is-jurisdiction-passported (jurisdiction (string-ascii 64)))
  (default-to false (map-get? passported-jurisdictions jurisdiction))
)
