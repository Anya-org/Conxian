;; revenue-automation.clar
;; Enforces non-negotiable protocol fee extraction (100 bps)
;; Aligned with CON-60 and Apex BME (v1.1.0)
;; Standardized for Mainnet (March 2026)

(impl-trait .enterprise-revenue-trait.enterprise-revenue-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_SOURCE_UNAUTHORIZED (err u1001))
(define-constant PROTOCOL_FEE_BPS u100)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-map authorized-stx-sources principal bool)

(define-private (is-authorized-source (source principal))
  (default-to false (map-get? authorized-stx-sources source))
)

;; --- Public Functions ---

;; @desc Calculate and collect protocol fee for a given amount.
;; @param token: The FT trait of the asset being processed.
;; @param amount: The base amount to calculate the fee from.
;; @param payer: The principal providing the fee.
;; @returns (response uint uint)
(define-public (collect-revenue (token <sip-010-ft-trait>) (amount uint) (payer principal))
  (let (
    (fee (/ (* amount PROTOCOL_FEE_BPS) u10000))
  )
    (begin
      (if (<= fee u0)
        (ok u0)
        (begin
          (try! (contract-call? token transfer fee payer .revenue-distributor none))
          (print { event: "revenue-collected", token: (contract-of token), amount: fee, payer: payer })
          (ok fee)
        )
      )
    )
  )
)

;; Route the full gross STX amount. This function intentionally does not
;; calculate or deduct the legacy 100 bps token fee; enterprise subscription
;; prices enter the Fiscal Dam unchanged.
(define-public (route-stx-revenue
    (amount uint)
    (source principal)
    (payment-id uint))
  (begin
    (asserts! (is-eq contract-caller source) ERR_UNAUTHORIZED)
    (asserts! (is-authorized-source source) ERR_SOURCE_UNAUTHORIZED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (as-contract
      (contract-call? .revenue-distributor route-stx-revenue amount source payment-id)))
    (print {
      event: "gross-stx-revenue-forwarded",
      source: source,
      payment-id: payment-id,
      amount: amount
    })
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

;; --- Admin ---

;; @desc Sets a new administrative principal for the revenue automation contract.
;; @param new-admin: The new administrator principal.
;; @returns (response bool uint)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Returns the current operational status of the revenue automation engine.
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", fee-bps: PROTOCOL_FEE_BPS })
)
