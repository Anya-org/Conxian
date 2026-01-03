;; governance-token.clar
;; Conxian Governance Token (CXG)

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxg)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u100))
        (ft-transfer? cxg amount sender recipient)
    )
)

(define-read-only (get-name) (ok "Conxian Governance Token"))
(define-read-only (get-symbol) (ok "CXG"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxg user)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxg)))
(define-read-only (get-token-uri) (ok none))
