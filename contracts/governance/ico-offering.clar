;; ico-offering.clar

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_COMPLIANCE_FAILED u1004)

;; @desc Allows a user to purchase tokens during an ICO offering.
;; @param amount: The amount of tokens to buy.
;; @param token: The trait of the token used for purchase.
(define-public (buy-tokens (amount uint) (token <sip-010-trait>))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_COMPLIANCE_FAILED))
    (ok true)
  )
)
