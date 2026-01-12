;; cxd-bonding-curve-amm.clar
;; Conxian Enterprise Standard: CXD Bonding Curve AMM
;; Provides instant, algorithmic liquidity for CXD token initialization.
;; Tier 0: "Clean-Hands" Compliance Enforced.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_SLIPPAGE (err u1001))
(define-constant ERR_NON_COMPLIANT (err u1002))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1003))

;; Data Vars
(define-data-var slope uint u1000) ;; Price increase per token (in micro-STX per micro-CXD)
(define-data-var base-price uint u1000000) ;; Starting price (1 STX)
(define-data-var fee-basis-points uint u50) ;; 0.5% fee
(define-data-var fee-collector principal .operational-treasury)
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var cxd-token-contract principal .cxd-token)
(define-data-var token-system-coordinator-contract principal .token-system-coordinator)

;; Compliance
(define-private (check-compliance (user principal))
  (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
    (if (is-ok compliance-status)
      true
      false
    )
  )
)

;; Price Calculation
;; Price P = base + slope * supply
;; Cost to mint amount dx: Integral(P) from S to S+dx
;; Approximation for Clarity: Average Price * Amount
(define-read-only (get-price (current-supply uint))
  (+ (var-get base-price) (/ (* (var-get slope) current-supply) u1000000))
)

(define-read-only (get-buy-quote (amount-cxd uint))
  (let (
      (supply (unwrap-panic (contract-call? .cxd-token get-total-supply)))
      (price-start (get-price supply))
      (price-end (get-price (+ supply amount-cxd)))
      (average-price (/ (+ price-start price-end) u2))
      (cost (/ (* amount-cxd average-price) u1000000))
      (fee (/ (* cost (var-get fee-basis-points)) u10000))
    )
    (ok (+ cost fee))
  )
)

(define-read-only (get-sell-quote (amount-cxd uint))
  (let (
      (supply (unwrap-panic (contract-call? .cxd-token get-total-supply)))
      (price-start (get-price supply))
      (price-end (get-price (- supply amount-cxd)))
      (average-price (/ (+ price-start price-end) u2))
      (proceeds (/ (* amount-cxd average-price) u1000000))
      (fee (/ (* proceeds (var-get fee-basis-points)) u10000))
    )
    (ok (- proceeds fee))
  )
)

;; Core Actions

(define-public (buy
    (amount-cxd uint)
    (max-spend-stx uint)
  )
  (let (
      (buyer tx-sender)
      (quote (unwrap-panic (get-buy-quote amount-cxd)))
    )
    ;; Compliance Check
    (asserts! (check-compliance buyer) ERR_NON_COMPLIANT)
    (asserts! (<= quote max-spend-stx) ERR_SLIPPAGE)

    ;; Transfer STX to Contract (Reserve)
    ;; Note: We keep fees separate or in reserve? 
    ;; Let's send fee to treasury, rest to reserve (this contract)
    (let (
        (fee (/ (* quote (var-get fee-basis-points)) u10000))
        (reserve-amt (- quote fee))
      )
      (try! (stx-transfer? reserve-amt buyer (as-contract tx-sender)))
      (try! (stx-transfer? fee buyer (var-get fee-collector)))
    )

    ;; Mint CXD via Coordinator
    ;; Coordinator must have authorized this contract as a minter
    (try! (contract-call? .token-system-coordinator mint-cxd
      amount-cxd buyer
    ))

    (print {
      event: "buy",
      buyer: buyer,
      amount: amount-cxd,
      cost: quote,
    })
    (ok true)
  )
)

(define-public (sell
    (amount-cxd uint)
    (min-receive-stx uint)
  )
  (let (
      (seller tx-sender)
      (quote (unwrap-panic (get-sell-quote amount-cxd)))
    )
    ;; Compliance Check
    (asserts! (check-compliance seller) ERR_NON_COMPLIANT)
    (asserts! (>= quote min-receive-stx) ERR_SLIPPAGE)

    ;; Burn CXD
    (try! (contract-call? .token-system-coordinator burn-cxd
      amount-cxd seller
    ))

    ;; Transfer STX from Reserve
    (try! (as-contract (stx-transfer? quote tx-sender seller)))

    (print {
      event: "sell",
      seller: seller,
      amount: amount-cxd,
      proceeds: quote,
    })
    (ok true)
  )
)
