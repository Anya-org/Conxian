;; kyc-registry.clar
;; Conxian Identity Standard: KYC Registry
;; Adheres to Decentralized Modularity and Bitcoin Ethos

(define-constant ERR_UNAUTHORIZED u8000)

(define-map identity-status
  principal
  {
    tier: uint,
    flags: uint,
    country: (string-ascii 3)
  }
)

(define-public (set-identity-status (user principal) (tier uint) (flags uint) (country (string-ascii 3)))
  (begin
    (map-set identity-status user {
      tier: tier,
      flags: flags,
      country: country
    })
    (ok true)
  )
)

(define-read-only (get-identity-status (user principal))
  (default-to { tier: u0, flags: u0, country: "???" } (map-get? identity-status user))
)

(define-read-only (is-sanctioned (user principal))
  (let ((status (get-identity-status user)))
    ;; Assuming flag 2 means sanctioned based on test usage
    (is-eq (get flags status) u2)
  )
)
