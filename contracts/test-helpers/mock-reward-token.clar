;; mock-reward-token.clar
;; Distinct SIP-010 fixture so native custody and reward reserve accounting are
;; exercised against separate fungible-token contracts.

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token reward)
(define-data-var fail-transfer bool false)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (var-get fail-transfer)) (err u12))
    (asserts! (is-eq tx-sender from) (err u11))
    (ft-transfer? reward amount from to)
  )
)

(define-public (set-fail-transfer (should-fail bool))
  (begin
    (var-set fail-transfer should-fail)
    (ok true)
  )
)

(define-read-only (get-name) (ok "Mock Reward Token"))
(define-read-only (get-symbol) (ok "MREWARD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance reward user)))
(define-read-only (get-total-supply) (ok (ft-get-supply reward)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
  (ft-mint? reward amount recipient)
)
