(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Test-only nested-call helpers. This contract is excluded from production
;; deployment plans and exists solely to preserve contract-caller regression
;; coverage for treasury integrations.
(define-public (submit-opex-expense
    (token <sip-010-trait>)
    (category uint)
    (amount uint)
    (payee principal)
    (memo (string-ascii 128)))
  (contract-call? .opex-vault create-expense token category amount payee memo)
)

(define-public (approve-opex-expense (expense-id uint))
  (contract-call? .opex-vault approve-expense expense-id)
)

(define-read-only (test-c4)
    (ok {
        time: burn-block-height,
        height: block-height
    })
)
