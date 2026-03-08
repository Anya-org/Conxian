;; sip-standards.clar
;; Standard SIP traits for Conxian Protocol

(define-trait sip-010-ft-trait (
    (transfer
        (uint principal principal (optional (buff 34)))
        (response bool uint)
    )
    (get-name
        ()
        (response (string-ascii 32) uint)
    )
    (get-symbol
        ()
        (response (string-ascii 32) uint)
    )
    (get-decimals
        ()
        (response uint uint)
    )
    (get-total-supply
        ()
        (response uint uint)
    )
    (get-token-uri
        ()
        (response (optional (string-utf8 256)) uint)
    )
    (get-balance
        (principal)
        (response uint uint)
    )
))

(define-trait sip-009-nft-trait (
    (get-last-token-id
        ()
        (response uint uint)
    )
    (get-token-uri
        (uint)
        (response (optional (string-ascii 256)) uint)
    )
    (get-owner
        (uint)
        (response (optional principal) uint)
    )
    (transfer
        (uint principal principal)
        (response bool uint)
    )
))

(define-trait ft-mintable-trait (
    (mint
        (uint principal)
        (response bool uint)
    )
    (burn
        (uint principal)
        (response bool uint)
    )
))
