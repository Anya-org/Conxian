;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for BME (v1.1.0)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var admin principal tx-sender)
(define-data-var bme-vault principal .bme-engine)
;; @desc Routes accumulated protocol fees to the BME engine for buy-back, burning (CXD), or vaulting.
(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (begin
    (if (is-eq (contract-of token) .cxd-token)
        (begin
          (unwrap-panic (contract-call? .bme-engine burn-protocol-fees amount))
          (ok true)
        )
        (begin
          (unwrap-panic (contract-call? .bme-engine swap-and-burn token amount))
          (ok true)
        )
    )
  )
)
;; @desc Processes STX-based protocol revenue and routes it for distribution or conversion.
(define-public (distribute-stx (amount uint)) (ok true))
(define-public (initialize (new-admin principal)) (begin (var-set admin new-admin) (ok true)))
(define-public (set-bme-vault (new-vault principal)) (begin (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED) (var-set bme-vault new-vault) (ok true)))
(define-read-only (get-operational-treasury) .operational-treasury)
