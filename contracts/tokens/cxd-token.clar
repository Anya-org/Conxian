;; cxd-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.ft-mintable-trait)
(define-constant ERR_NON_COMPLIANT u1001)
(define-constant ERR_UNAUTHORIZED u1002)
(define-fungible-token cxd)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (ft-mint? cxd amount recipient)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (ft-burn? cxd amount owner)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance sender)) (err ERR_NON_COMPLIANT))
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (try! (ft-transfer? cxd amount sender recipient))
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian Dollar"))
(define-read-only (get-symbol) (ok "CXD"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxd w)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))
(define-read-only (get-token-uri) (ok none))
