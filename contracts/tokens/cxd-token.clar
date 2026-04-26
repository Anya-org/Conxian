;; cxd-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxd)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u1))
    (ft-transfer? cxd amount from to)
  )
)

(define-read-only (get-name) (ok "Conxian Dollar"))
(define-read-only (get-symbol) (ok "CXD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxd user)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? cxd amount recipient)
)

(define-public (burn (amount uint) (sender principal))
  (ft-burn? cxd amount sender)
)
