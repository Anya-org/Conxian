(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-fee-source-trait .protocol-fee-source-trait.protocol-fee-source-trait)

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

(define-public (collector-recover-excess-stx (amount uint))
  (contract-call? .protocol-fee-collector recover-excess-stx amount)
)

(define-public (collector-set-admin (new-admin principal))
  (contract-call? .protocol-fee-collector set-admin new-admin)
)

(define-public (collector-set-authorized-source (source principal) (authorized bool))
  (contract-call? .protocol-fee-collector set-authorized-source source authorized)
)

(define-public (collector-settle-source-ft
    (source <protocol-fee-source-trait>)
    (token <sip-010-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (contract-call? .protocol-fee-collector
    settle-source-ft
    source
    token
    stream-id
    eligible-fee-base
    settlement-id)
)

(define-public (deposit-stx-to-collector (amount uint))
  (stx-transfer? amount tx-sender .protocol-fee-collector)
)

(define-read-only (test-c4)
    (ok {
        time: burn-block-height,
        height: block-height
    })
)
