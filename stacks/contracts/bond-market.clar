;; Bond Market Protocol (Standalone Prototype)
;; Implements simple bond series issuance, coupon distribution, and redemption.
;; NOTE: Prototype only – not integrated with AutoVault economics yet.

(define-constant CONTRACT_VERSION u1)
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_SERIES_EXISTS u101)
(define-constant ERR_SERIES_UNKNOWN u102)
(define-constant ERR_NOT_MATURED u103)
(define-constant ERR_NO_HOLDING u104)
(define-constant ERR_COUPON_ALREADY_PAID u105)
(define-constant ERR_INVALID_AMOUNT u106)

(define-data-var admin principal tx-sender)
(define-data-var face-value uint u100_000_000) ;; 100 STX nominal (1e6 micro STX pips)

;; Each bond series has fixed parameters
(define-map bond-series
  { id: (string-ascii 32) }
  { issuer: principal,
    principal: uint,               ;; total principal (face value * quantity)
    coupon-bps: uint,              ;; annual coupon in basis points (e.g. 500 = 5%)
    issued: bool,
    maturity-height: uint,
    total-supply: uint,            ;; total tokens minted (face units)
    redeemed-supply: uint })

;; Track coupon payments per period (simple: 1 period) – extension: multi-period schedule
(define-map coupon-paid
  { id: (string-ascii 32) }
  { paid: bool })

;; Fungible token per series composed with ticker pattern: we model a single fungible token for prototype
(define-fungible-token bond-token)

;; Holder balances per series (logical partition of single token supply)
(define-map bond-holdings
  { id: (string-ascii 32), holder: principal }
  { amount: uint })

;; --- Helpers ---
(define-private (is-admin) (is-eq tx-sender (var-get admin)))

(define-read-only (get-series (sid (string-ascii 32)))
  (map-get? bond-series { id: sid }))

(define-read-only (get-holding (sid (string-ascii 32)) (holder principal))
  (map-get? bond-holdings { id: sid, holder: holder }))

;; --- Admin Actions ---
(define-public (set-admin (new principal))
  (begin (asserts! (is-admin) (err ERR_UNAUTHORIZED)) (var-set admin new) (ok true)))

(define-public (issue-bond-series
  (sid (string-ascii 32))
  (quantity uint)              ;; number of face units
  (coupon-bps uint)
  (maturity-height uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> quantity u0) (err ERR_INVALID_AMOUNT))
    (match (map-get? bond-series { id: sid })
      existing (err ERR_SERIES_EXISTS)
      (begin
        (map-set bond-series { id: sid } {
          issuer: tx-sender,
          principal: (* quantity (var-get face-value)),
          coupon-bps: coupon-bps,
          issued: true,
          maturity-height: maturity-height,
          total-supply: quantity,
          redeemed-supply: u0
        })
        ;; Mint fungible tokens representing the bond units to issuer (could go to investors via distribution)
        (ft-mint? bond-token quantity tx-sender)
        (map-set bond-holdings { id: sid, holder: tx-sender } { amount: quantity })
        (print { event: "bond-series-issued", id: sid, quantity: quantity, coupon: coupon-bps, maturity: maturity-height })
        (ok quantity)))) )

;; Transfer bond units between holders (secondary market primitive)
(define-public (transfer-bond (sid (string-ascii 32)) (amount uint) (to principal))
  (begin
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (let ((holding (unwrap! (map-get? bond-holdings { id: sid, holder: tx-sender }) (err ERR_NO_HOLDING))))
      (asserts! (>= (get amount holding) amount) (err ERR_INVALID_AMOUNT))
      (map-set bond-holdings { id: sid, holder: tx-sender } { amount: (- (get amount holding) amount) })
      (let ((to-holding (default-to { amount: u0 } (map-get? bond-holdings { id: sid, holder: to }))))
        (map-set bond-holdings { id: sid, holder: to } { amount: (+ (get amount to-holding) amount) }))
      ;; Move fungible representation
      (unwrap! (ft-transfer? bond-token amount tx-sender to) (err u200))
      (print { event: "bond-transfer", id: sid, from: tx-sender, to: to, amount: amount })
      (ok true))))

;; Pay single coupon (simple annual coupon model)
(define-public (pay-coupon (sid (string-ascii 32)))
  (begin
    (let ((s (unwrap! (map-get? bond-series { id: sid }) (err ERR_SERIES_UNKNOWN))))
      (asserts! (is-eq tx-sender (get issuer s)) (err ERR_UNAUTHORIZED))
      (let ((already (default-to { paid: false } (map-get? coupon-paid { id: sid }))))
        (asserts! (is-eq (get paid already) false) (err ERR_COUPON_ALREADY_PAID))
        (let ((coupon (/ (* (get principal s) (get coupon-bps s)) u10000)))
          ;; Payout linearly to each holder (naive iteration omitted -> event for off-chain distribution)
          (map-set coupon-paid { id: sid } { paid: true })
          (print { event: "coupon-declared", id: sid, gross: coupon })
          (ok coupon)))))

;; Redeem at maturity (holder burns units and receives principal per unit)
(define-public (redeem (sid (string-ascii 32)) (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (let ((s (unwrap! (map-get? bond-series { id: sid }) (err ERR_SERIES_UNKNOWN)))
          (h block-height))
      (asserts! (>= h (get maturity-height s)) (err ERR_NOT_MATURED))
      (let ((holding (unwrap! (map-get? bond-holdings { id: sid, holder: tx-sender }) (err ERR_NO_HOLDING))))
        (asserts! (>= (get amount holding) amount) (err ERR_INVALID_AMOUNT))
        (map-set bond-holdings { id: sid, holder: tx-sender } { amount: (- (get amount holding) amount) })
        ;; Burn fungible bond tokens (face units)
        (ft-burn? bond-token amount tx-sender)
        ;; Principal owed (face-value per unit)
        (let ((payout (* amount (var-get face-value))))
          (print { event: "bond-redeemed", id: sid, holder: tx-sender, units: amount, principal: payout })
          ;; Prototype: does not actually transfer STX; integration would hold STX escrow.
          (ok payout))))) )

;; --- Read-only views ---
(define-read-only (get-balance (sid (string-ascii 32)) (holder principal))
  (match (map-get? bond-holdings { id: sid, holder: holder }) h (ok (get amount h)) (ok u0)))

(define-read-only (get-coupon-status (sid (string-ascii 32)))
  (default-to { paid: false } (map-get? coupon-paid { id: sid }))

(define-read-only (contract-version) CONTRACT_VERSION)
