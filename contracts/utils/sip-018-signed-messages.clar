;; sip-018-signed-messages.clar
;; Standard implementation of SIP-018 message signing verification

(impl-trait .sip-018-signed-messages-trait.sip-018-signed-messages-trait)

(define-constant ERR_INVALID_SIGNATURE (err u100))

(define-public (recover-signer (message-hash (buff 32)) (signature (buff 65)))
  (let ((recovered-pubkey (unwrap! (secp256k1-recover? message-hash signature) ERR_INVALID_SIGNATURE)))
    (ok (principal-of recovered-pubkey))
  )
)

(define-read-only (get-signer (message-hash (buff 32)) (signature (buff 65)))
  (recover-signer message-hash signature)
)
