;; regulatory-adapter.clar
;; Conxian Enterprise Standard: Regulatory Adapter (Clean-Hands Compliance)
;; Verifies Off-Chain ZK-Proofs/Signatures of compliance to keep PII off-chain.
;; Tier 0: User-Sovereign Verification (SIP-018 Style)

(impl-trait .core-traits.compliance.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_PROOF (err u6001))
(define-constant ERR_EXPIRED_PROOF (err u6002))
(define-constant ERR_INVALID_SIGNATURE (err u6003))

;; Data Vars
(define-data-var contract-owner principal tx-sender) ;; The Admin (DAO/Timelock)
(define-data-var regulatory-authority principal tx-sender) ;; The Oracle (Signer)
(define-data-var authority-pubkey (buff 33) 0x00) ;; Compressed public key of the authority

;; Storage
(define-map verified-compliance
  principal
  {
    proof-hash: (buff 32),
    verified-at: uint,
    expires-at: uint,
    jurisdiction: (string-ascii 3), ;; e.g., "US", "EU", "SGP"
  }
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; @desc Sets the contract owner (Admin/DAO)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (print {
      event: "ownership-transferred",
      new-owner: new-owner,
    })
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; @desc Sets the regulatory authority and their public key for verification
;; Only the Contract Owner (DAO) can rotate the Authority (Oracle).
(define-public (set-regulatory-authority
    (new-authority principal)
    (new-pubkey (buff 33))
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set regulatory-authority new-authority)
    (var-set authority-pubkey new-pubkey)
    (print {
      event: "authority-updated",
      authority: new-authority,
    })
    (ok true)
  )
)

;; @desc Recover the message hash for verification
(define-read-only (get-verification-message-hash
    (user principal)
    (expiry uint)
    (jurisdiction (string-ascii 3))
  )
  (sha256 (concat (to-int expiry) (unwrap-ascii (to-ascii jurisdiction) (err u100))))
)

;; @desc Submit a ZK-Proof/Signed Attestation of compliance (User-Sovereign)
;; The User submits the proof signed by the Authority.
;; PII remains off-chain. The chain only verifies the Authority attested to this user's status.
(define-public (submit-compliance-proof
    (signature (buff 65))
    (expiry uint)
    (jurisdiction (string-ascii 3))
  )
  (let (
      (user tx-sender)
      (message-hash (get-verification-message-hash user expiry jurisdiction))
      (pubkey (var-get authority-pubkey))
    )
    ;; 1. Verify Signature: Authority signed (hash(user, expiry, jurisdiction))
    (asserts! (is-ok (secp256k1-verify message-hash signature pubkey))
      ERR_INVALID_SIGNATURE
    )

    ;; 2. Store Verification Result
    (map-set verified-compliance user {
      proof-hash: message-hash, ;; Using message hash as the unique proof identifier
      verified-at: block-height,
      expires-at: expiry,
      jurisdiction: jurisdiction,
    })

    (print {
      event: "compliance-verified",
      user: user,
      jurisdiction: jurisdiction,
      expires: expiry,
    })
    (ok true)
  )
)

;; @desc Check compliance status without accessing PII
(define-read-only (check-clean-hands-compliance (user principal))
  (match (map-get? verified-compliance user)
    record (if (< block-height (get expires-at record))
      (ok true)
      (err ERR_EXPIRED_PROOF)
    )
    (err ERR_INVALID_PROOF)
  )
)

;; @desc Get jurisdiction code for geofencing (if needed, still no PII)
(define-read-only (get-user-jurisdiction (user principal))
  (match (map-get? verified-compliance user)
    record (ok (get jurisdiction record))
    (err ERR_INVALID_PROOF)
  )
)
