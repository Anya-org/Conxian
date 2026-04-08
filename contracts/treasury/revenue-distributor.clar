;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for BME (v1.1.0)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var admin principal tx-sender)

;; State
(define-data-var bme-vault principal .bme-engine)

;; --- Public Functions ---

;; @desc Distribute tokens for buy-back and burn
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

(define-public (distribute-stx (amount uint))
  (ok true)
)

;; Admin Functions

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-bme-vault (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set bme-vault new-vault)
    (ok true)
  )
)
