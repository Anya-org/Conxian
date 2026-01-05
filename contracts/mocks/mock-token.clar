;; mock-token.clar
;; Mock Token for testing

(impl-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-fungible-token mock-token)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (ft-transfer? mock-token amount sender recipient)
    )
)

(define-read-only (get-name)
    (ok "Mock Token")
)

(define-read-only (get-symbol)
    (ok "MOCK")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance mock-token who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply mock-token))
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (mint (amount uint) (recipient principal))
    (ft-mint? mock-token amount recipient)
)
