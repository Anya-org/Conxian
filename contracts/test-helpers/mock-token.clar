;; mock-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token mock)
(define-data-var transfer-failure bool false)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    ;; Test-only fault injection lets custody rollback tests make the token
    ;; transfer fail after the collector has checked live balance/excess.
    (asserts! (not (var-get transfer-failure)) (err u2))
    (asserts! (is-eq tx-sender from) (err u1))
    (ft-transfer? mock amount from to)
  )
)

(define-read-only (get-name) (ok "Mock Token"))
(define-read-only (get-symbol) (ok "MOCK"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance mock user)))
(define-read-only (get-total-supply) (ok (ft-get-supply mock)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? mock amount recipient)
)

(define-public (set-transfer-failure (should-fail bool))
  (begin
    (var-set transfer-failure should-fail)
    (ok should-fail)
  )
)
