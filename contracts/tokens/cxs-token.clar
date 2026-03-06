;; cxs-token.clar
;; SIP-010 Staking Token
(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token cxs)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1000))
    (try! (ft-transfer? cxs amount sender recipient))
    (ok true)
  )
)
(define-read-only (get-name) (ok "Conxian Staking Token"))
(define-read-only (get-symbol) (ok "CXS"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxs w)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxs)))
(define-read-only (get-token-uri) (ok none))
