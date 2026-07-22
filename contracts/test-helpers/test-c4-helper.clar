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

;; Contract-only governance stand-in used by collector tests. Production
;; deployments must use the approved DAO/timelock contract, not a wallet.
(define-public (collector-pause)
  (contract-call? .protocol-fee-collector pause)
)

(define-public (collector-unpause)
  (contract-call? .protocol-fee-collector unpause)
)

(define-public (collector-route-stx (amount uint))
  (contract-call? .protocol-fee-collector route-stx amount)
)

(define-public (collector-route-ft (token <sip-010-trait>) (amount uint))
  (contract-call? .protocol-fee-collector route-ft token amount)
)

(define-read-only (test-c4)
    (ok {
        time: burn-block-height,
        height: block-height
    })
)
