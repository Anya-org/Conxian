;; sip-018-signed-messages-trait.clar
;; SIP-018 Standard Trait

(define-trait sip-018-trait
    (
        (sign-message ((buff 32)) (response (buff 65) uint))
        (verify-signature ((buff 32) (buff 65) principal) (response bool uint))
    )
)
