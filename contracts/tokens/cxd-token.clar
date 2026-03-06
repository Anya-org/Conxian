;; cxd-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token cxd)

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? cxd amount recipient)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (ft-transfer? cxd amount sender recipient)
)

(define-read-only (get-name) (ok "Conxian Dollar"))
(define-read-only (get-symbol) (ok "CXD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxd w)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))
(define-read-only (get-token-uri) (ok none))
