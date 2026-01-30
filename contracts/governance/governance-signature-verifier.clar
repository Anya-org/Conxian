;; governance-signature-verifier.clar
;; Verifies off-chain signatures for proposals (SIP-018)
;; Enables "Zero-Gas" voting (vote signing)

(define-constant ERR_INVALID_SIGNATURE u1000)

;; Public Functions
(define-public (verify-message-signature (message (buff 32)) (signature (buff 65)) (pubkey (buff 33)))
    (begin
        (asserts! (secp256k1-verify message signature pubkey) (err ERR_INVALID_SIGNATURE))
        (ok true)
    )
)

(define-read-only (verify-signature-read-only (message (buff 32)) (signature (buff 65)) (pubkey (buff 33)))
    (ok (secp256k1-verify message signature pubkey))
)
