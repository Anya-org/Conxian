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
          ;; Transfer CXD to bme-engine, then burn
          (try! (as-contract (contract-call? token transfer amount tx-sender .bme-engine none)))
          (try! (contract-call? .bme-engine burn-protocol-fees amount))
          (ok true)
        )
        (begin
          ;; Transfer non-CXD tokens to swap-router, then swap-and-burn
          (try! (as-contract (contract-call? token transfer amount tx-sender .swap-router none)))
          (try! (contract-call? .swap-router swap-and-burn token amount))
          (ok true)
        )
    )
  )
)

;; @desc Processes STX-based protocol revenue and routes it for conversion via CXD swap and burn.
;; @param amount: Quantity of STX to distribute.
(define-public (distribute-stx (amount uint))
  (begin
    ;; Route STX to swap-router for CXD buy-back via the BME engine
    (try! (stx-transfer? amount tx-sender .swap-router))
    (print { event: "stx-revenue-routed-for-buyback", amount: amount })
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
