;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for BME (v1.1.0)
;; Gross-STX enterprise revenue is routed into cxd-treasury's Fiscal Dam.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_SOURCE_UNAUTHORIZED (err u1001))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1002))

(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-data-var admin principal tx-sender)
(define-data-var bme-vault principal .bme-engine)
(define-data-var revenue-automation-principal principal tx-sender)
(define-data-var next-legacy-payment-id uint u1)
(define-map authorized-stx-sources principal bool)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right)))
)

(define-private (is-authorized-source (source principal))
  (default-to false (map-get? authorized-stx-sources source))
)

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
  (let (
    (source tx-sender)
    (payment-id (var-get next-legacy-payment-id))
  )
    (begin
      ;; Compatibility callers, including integration-fee-collector, must be
      ;; explicitly authorized before their custody can enter the Fiscal Dam.
      (asserts! (is-authorized-source source) ERR_SOURCE_UNAUTHORIZED)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (try! (as-contract
        (contract-call? .cxd-treasury record-stx-revenue source payment-id amount)))
      (var-set next-legacy-payment-id
        (unwrap! (safe-add payment-id u1) ERR_ARITHMETIC_OVERFLOW))
      (print {
        event: "legacy-stx-revenue-routed-to-fiscal-dam",
        source: source,
        payment-id: payment-id,
        amount: amount
      })
      (ok true)
    )
  )
)

;; Canonical enterprise adapter hop. The caller must be revenue-automation,
;; and the source is checked again at this boundary before custody moves.
(define-public (route-stx-revenue
    (amount uint)
    (source principal)
    (payment-id uint))
  (begin
    (asserts! (is-eq contract-caller (var-get revenue-automation-principal)) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-source source) ERR_SOURCE_UNAUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (as-contract
      (contract-call? .cxd-treasury record-stx-revenue source payment-id amount)))
    (print {
      event: "enterprise-stx-revenue-routed-to-fiscal-dam",
      source: source,
      payment-id: payment-id,
      amount: amount
    })
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

(define-public (set-revenue-automation (new-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set revenue-automation-principal new-principal)
    (ok true)
  )
)

(define-public (authorize-stx-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-stx-sources source true)
    (ok true)
  )
)

(define-public (revoke-stx-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-stx-sources source false)
    (ok true)
  )
)

;; @desc Returns the operational treasury reference.
(define-read-only (get-operational-treasury)
  .operational-treasury
)
