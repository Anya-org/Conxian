;; cxlp-token.clar
;; SIP-010 Liquid Provider Token
(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token cxlp)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1000))
    (try! (ft-transfer? cxlp amount sender recipient))
    (ok true)
  )
)
(define-read-only (get-name) (ok "Conxian LP Token"))
(define-read-only (get-symbol) (ok "CXLP"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxlp w)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxlp)))
(define-read-only (get-token-uri) (ok none))
