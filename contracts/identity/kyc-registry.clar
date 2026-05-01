;; kyc-registry.clar
;; Conxian Identity Standard: KYC Registry
;; Manages identity tiers and sanction flags.

(define-constant ERR_UNAUTHORIZED u8000)

;; Data Vars
(define-data-var admin principal tx-sender)

;; Map: User -> { tier: uint, flags: uint, country: (string-ascii 3) }
(define-map identity-status
  principal
  {
    tier: uint, flags: uint, country: (string-ascii 3)
  }
)

;; Authorization
(define-private (is-admin) (is-eq tx-sender (var-get admin)))

;; Public Functions

(define-public (set-identity-status (user principal) (tier uint) (flags uint) (country (string-ascii 3)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-set identity-status user {
      tier: tier, flags: flags, country: country
    })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Read-only Functions

(define-read-only (get-identity-status (user principal))
  (default-to { tier: u0, flags: u0, country: "???" } (map-get? identity-status user))
)

(define-read-only (is-sanctioned (user principal))
  (let ((status (get-identity-status user)))
    ;; flag u2 = sanctioned
    (is-eq (get flags status) u2)
  )
)

(define-read-only (get-tier (user principal))
  (get tier (get-identity-status user))
)
