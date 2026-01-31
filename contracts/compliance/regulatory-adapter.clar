;; regulatory-adapter.clar
;; Conxian Finance: Regulatory Adapter (Clean-Hands Compliance)
;; Implements regulatory-adapter-trait from core-traits

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
    jurisdiction: (string-ascii 64)
  }
)

(define-map blacklist principal bool)

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
(define-public (add-to-whitelist (user principal) (jurisdiction (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set compliance-status { user: user } {
      clean-hands: true,
      verified-at: burn-block-height,
      jurisdiction: jurisdiction
    })
    (ok true)
  )
)

;; Admin: Add to Blacklist
(define-public (add-to-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set blacklist user true)
    ;; Use burn-block-height for high-precision audit logs (Clarity 4)
    (print { event: "user-blacklisted", user: user, audit-time: burn-block-height, status: "BLACKLISTED" })
    (ok true)
  )
)

;; Admin: Remove from Blacklist
(define-public (remove-from-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-delete blacklist user)
    (print { event: "user-removed-from-blacklist", user: user })
    (ok true)
  )
)

;; Read-only: Get Compliance Status
(define-read-only (get-compliance-status (user principal))
  (ok (map-get? compliance-status { user: user }))
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
