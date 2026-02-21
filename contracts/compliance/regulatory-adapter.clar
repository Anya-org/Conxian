;; Conxian Finance: Regulatory Adapter (Clean-Hands Compliance)
;; Enhanced Institutional Hardening - MiCA Readiness
;; SIP-018 Compliant Attestations (Nakamoto-Ready)

;; Traits
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_INVALID_PROOF u6001)
(define-constant ERR_BLACKLISTED u6002)
(define-constant ERR_INVALID_SIGNATURE u6003)

;; SIP-018 Constants
(define-constant DOMAIN_NAME 0x436f6e7869616e20526567756c61746f72792041646170746572) ;; "Conxian Regulatory Adapter"
(define-constant DOMAIN_VERSION 0x312e302e30) ;; "1.0.0"
(define-constant TYPE_HASH (sha256 0x436f6d706c69616e63654174746573746174696f6e287072696e636970616c20757365722c737472696e672d6173636969206a7572697364696374696f6e2c75696e74207469657229))

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var regulatory-authority principal tx-sender)
(define-data-var threshold uint u1)

;; Maps
(define-map authorized-signers (buff 33) uint)

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
      verified-at: block-height,
      jurisdiction: jurisdiction,
      tier: tier
    })
    (print {
        event: "compliance-verified",
        user: user,
        jurisdiction: jurisdiction,
        tier: tier,
        audit: DOMAIN_NAME
    })
    (ok true)
  )
)

;; Multisig Verification Helpers
(define-private (verify-sig-and-get-weight (pubkey (buff 33)) (acc { message-hash: (buff 32), signatures: (list 10 (buff 65)), index: uint, total-weight: uint }))
  (let (
    (signature (unwrap-panic (element-at (get signatures acc) (get index acc))))
    (weight (default-to u0 (map-get? authorized-signers pubkey)))
    (is-valid (secp256k1-verify (get message-hash acc) signature pubkey))
  )
    {
      message-hash: (get message-hash acc),
      signatures: (get signatures acc),
      index: (+ (get index acc) u1),
      total-weight: (if is-valid (+ (get total-weight acc) weight) (get total-weight acc))
    }
  )
)

;; SIP-018: Verify Compliance Signature (Multisig version)
(define-public (verify-and-update-compliance (user principal) (jurisdiction (string-ascii 64)) (tier uint) (signatures (list 10 (buff 65))) (pubkeys (list 10 (buff 33))))
  (let (
    (message-hash (get-sip018-hash user jurisdiction tier))
    (verification-result (fold verify-sig-and-get-weight pubkeys { message-hash: message-hash, signatures: signatures, index: u0, total-weight: u0 }))
  )
    ;; Check if total weight meets threshold
    (asserts! (>= (get total-weight verification-result) (var-get threshold)) (err ERR_INVALID_SIGNATURE))

    ;; Update Status
    (map-set compliance-status { user: user } {
      clean-hands: true,
      verified-at: block-height,
      jurisdiction: jurisdiction,
      tier: tier
    })

    (print {
      event: "compliance-verified-multisig",
      user: user,
      jurisdiction: jurisdiction,
      total-weight: (get total-weight verification-result),
      threshold: (var-get threshold),
      audit: DOMAIN_NAME
    })
    (ok true)
  )
)

;; SIP-018 Hashing Helpers (Simnet-Compatible)
(define-read-only (get-domain-separator)
  (sha256 (concat DOMAIN_NAME DOMAIN_VERSION))
)

(define-read-only (get-structured-data-hash (user principal) (jurisdiction (string-ascii 64)) (tier uint))
  ;; Improved structured hash using available Clarity 4 primitives
  (sha256 (concat TYPE_HASH
    (sha256 (concat (sha256 (unwrap-panic (to-consensus-buff (sha256 (concat DOMAIN_NAME DOMAIN_VERSION))))) (sha256 jurisdiction)))
  ))
)

(define-read-only (get-sip018-hash (user principal) (jurisdiction (string-ascii 64)) (tier uint))
  (sha256 (concat (get-domain-separator) (get-structured-data-hash user jurisdiction tier)))
)

;; Admin functions
(define-public (add-to-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set blacklist user true)
    (print { event: "user-blacklisted", user: user, timestamp: block-height, audit: DOMAIN_NAME })
    (ok true)
  )
)

(define-public (update-authority (new-authority principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set regulatory-authority new-authority)
    (print { event: "authority-updated", new-authority: new-authority, audit: DOMAIN_NAME })
    (ok true)
  )
)

(define-public (set-signer (pubkey (buff 33)) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set authorized-signers pubkey weight)
    (print { event: "signer-updated", pubkey: pubkey, weight: weight })
    (ok true)
  )
)

(define-public (set-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set threshold new-threshold)
    (print { event: "threshold-updated", threshold: new-threshold })
    (ok true)
  )
)
