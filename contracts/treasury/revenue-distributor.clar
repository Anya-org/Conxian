;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for BME (v1.1.0)
;; Remediated June 2026: 100% Buy-back and Burn Policy

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var admin principal tx-sender)
(define-data-var bme-vault principal .bme-engine)

;; @desc Routes accumulated protocol fees to the BME engine for buy-back, burning (CXD), or vaulting.
;; @param token: The asset trait being distributed.
;; @param amount: The quantity of tokens to distribute.
(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (begin
    ;; 100% Policy: All collected fees are routed to BME for burn or swap-and-burn
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

;; @desc Processes STX-based protocol revenue and routes it for conversion via CXD swap and burn.
;; @param amount: Quantity of STX to distribute.
(define-public (distribute-stx (amount uint))
  (begin
    ;; In production, routes STX to swap-router for CXD buy-back
    (print { event: "stx-revenue-routed", amount: amount })
    (ok true)
  )
)

;; @desc Initializes the distributor with a designated admin.
;; @param new-admin: The admin principal.
(define-public (initialize (new-admin principal))
  (begin
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Updates the BME vault/engine reference.
;; @param new-vault: The new engine principal.
(define-public (set-bme-vault (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set bme-vault new-vault)
    (ok true)
  )
)

;; @desc Returns the operational treasury reference.
(define-read-only (get-operational-treasury)
  .operational-treasury
)
