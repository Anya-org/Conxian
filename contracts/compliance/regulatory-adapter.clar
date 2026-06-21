;; regulatory-adapter.clar
;; SIP-018 Compliant Regulatory Adapter for Conxian Protocol

(use-trait kyc-registry-trait .identity.kyc-registry-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NON_COMPLIANT (err u1001))

(define-data-var admin principal tx-sender)

;; SIP-018 Domain Separator
(define-constant DOMAIN_NAME "Conxian Finance")
(define-constant DOMAIN_VERSION "1.0.0")
(define-constant CHAIN_ID u1)

;; @desc Checks if a principal is compliant with "Clean Hands" policy.
(define-read-only (check-clean-hands-compliance (user principal))
  (ok (is-ok (contract-call? .kyc-registry is-verified user)))
)

;; @desc Verify a structured data signature (SIP-018 inspired)
(define-public (verify-structured-data (payload { amount: uint, recipient: principal, nonce: uint }) (signature (buff 65)) (pubkey (buff 33)))
  (let ((msg-hash (sha256 (keccak256 (unwrap-panic (to-consensus-buff? payload))))))
    (ok (secp256k1-verify msg-hash signature pubkey))
  )
)

;; @desc Updates the administrator.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
