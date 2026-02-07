;; kyc-registry.clar
;; Conxian Identity Standard: KYC Registry
;; Adheres to Decentralized Modularity and Bitcoin Ethos

;; Traits
(use-trait nft-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_NOT_FOUND u8001)

;; Maps
(define-map user-kyc
  principal
  {
    tier: uint,
    expiry: uint,
    verified-by: principal,
    flags: uint,
    jurisdiction: (string-ascii 32)
  }
)

;; @desc Sets the KYC tier for a user
(define-public (set-kyc-tier
    (user principal)
    (tier uint)
    (expiry uint)
  )
  (begin
    ;; Authorization logic (e.g. only designated verifiers)
    (map-set user-kyc user {
      tier: tier,
      expiry: expiry,
      verified-by: tx-sender,
      flags: u0,
      jurisdiction: "UNKNOWN"
    })
    (print {
      event: "kyc-updated",
      user: user,
      tier: tier,
      tenure-id: (contract-call? .block-utils get-current-tenure-id),
    })
    (ok true)
  )
)

;; @desc Full identity status update (used by tests)
(define-public (set-identity-status
    (user principal)
    (tier uint)
    (flags uint)
    (jurisdiction (string-ascii 32))
  )
  (begin
    (map-set user-kyc user {
      tier: tier,
      expiry: u0,
      verified-by: tx-sender,
      flags: flags,
      jurisdiction: jurisdiction
    })
    (ok true)
  )
)

;; @desc Gets the KYC tier for a user
(define-read-only (get-kyc-tier (user principal))
  (match (map-get? user-kyc user)
    data
    (ok (get tier data))
    (ok u0) ;; Default to Tier 0 (Not verified)
  )
)

;; @desc Checks if a user has a minimum KYC tier
(define-read-only (has-min-tier
    (user principal)
    (min-tier uint)
  )
  (let ((current-tier (unwrap-panic (get-kyc-tier user))))
    (ok (>= current-tier min-tier))
  )
)

(define-read-only (is-sanctioned (subject principal))
  (match (map-get? user-kyc subject)
    data (or (is-eq (get flags data) u2) (is-eq (mod (/ (get tier data) u2) u2) u1))
    false
  )
)

(define-read-only (get-flags (user principal))
  (match (map-get? user-kyc user)
    data (ok (get flags data))
    (ok u0)
  )
)
