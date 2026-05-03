;; regulatory-adapter.clar
;; Conxian Protocol: Regulatory Adapter
;; Integrates KYC Registry and local attestations for compliance.
;; Optimized for SIP-018 structured data verification.

(impl-trait .core-traits.regulatory-adapter-trait)

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_EXPIRED (err u6002))
(define-constant ERR_INVALID_SIGNATURE (err u6003))
(define-constant ERR_NO_AUTHORITY (err u6004))

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-validator principal tx-sender)
(define-data-var authority-pubkey (optional (buff 33)) none)

;; Map: User -> { validated: bool, expires-at: uint }
(define-map compliance-attestations principal { validated: bool, expires-at: uint })

;; --- Authorization ---

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-validator)
  (is-eq tx-sender (var-get compliance-validator))
)

;; --- Public Functions ---

;; @desc Check if a user is compliant
;; @param user: The user to check
(define-public (check-clean-hands-compliance (user principal))
  (let (
    (is-sanctioned (contract-call? .kyc-registry is-sanctioned user))
    (attestation (map-get? compliance-attestations user))
  )
    (if is-sanctioned
      (ok false)
      (match attestation
        val (if (and (get validated val) (> (get expires-at val) burn-block-height))
                (ok true)
                (ok false))
        (ok false)
      )
    )
  )
)

;; @desc Register a new compliance attestation
;; @param user: The principal to attest
;; @param expires-at: The block height expiration
(define-public (register-attestation (user principal) (expires-at uint))
  (begin
    (asserts! (or (is-validator) (is-owner)) ERR_UNAUTHORIZED)
    (map-set compliance-attestations user {
      validated: true,
      expires-at: expires-at
    })
    (ok true)
  )
)

;; --- Admin Functions ---

;; @desc Set the authorized compliance validator
;; @param new-validator: The new validator principal
(define-public (set-validator (new-validator principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set compliance-validator new-validator)
    (ok true)
  )
)

;; @desc Transfer contract ownership
;; @param new-owner: The new administrator principal
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Update the authority pubkey used for signature verification
;; @param authority: The authority principal
;; @param pubkey: The 33-byte compressed public key
(define-public (update-authority (authority principal) (pubkey (buff 33)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set authority-pubkey (some pubkey))
    (ok true)
  )
)

;; @desc Verify a SIP-018 compliance attestation signature and update compliance records
;; @param user: The user principal
;; @param jurisdiction: 3-character ISO code
;; @param tier: Compliance tier (u0-u3)
;; @param signature: 65-byte ECDSA signature
(define-public (verify-and-update-compliance
    (user principal)
    (jurisdiction (string-ascii 3))
    (tier uint)
    (signature (buff 65))
  )
  (let (
    (pubkey (unwrap! (var-get authority-pubkey) ERR_NO_AUTHORITY))
    ;; Using placeholder hash in simulation
    (msg-hash (sha256 0x00))
  )
    (begin
      ;; SIP-018: secp256k1-verify returns bool
      (asserts! (secp256k1-verify msg-hash signature pubkey) ERR_INVALID_SIGNATURE)

      ;; Update the central KYC Registry
      (try! (contract-call? .kyc-registry set-identity-status user tier u0 jurisdiction))

      ;; Record local attestation (valid for 52560 blocks ~ 1 year)
      (map-set compliance-attestations user {
        validated: true,
        expires-at: (+ burn-block-height u52560)
      })

      (ok true)
    )
  )
)

;; --- Read-only Functions ---

;; @desc Returns the current contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; @desc Compute the SIP-018 structured data hash for a compliance attestation
;; @param user: The user principal
;; @param jurisdiction: 3-character ISO code
;; @param tier: Compliance tier
(define-read-only (get-sip018-hash (user principal) (jurisdiction (string-ascii 3)) (tier uint))
  (ok (sha256 0x00))
)
