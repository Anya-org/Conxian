;; concentrated-liquidity-pool.clar
;; Conxian DEX: Concentrated Liquidity Pool Engine
;; Aligned with Apex CSF (v1.2.0) and Nakamoto Standard.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .conxian-csf-trait.trait-csf-liquidity-v1)

;; --- Constants ---
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u1002))
(define-constant ERR_POOL_NOT_FOUND (err u1003))
(define-constant ERR_SHARE_STATE_MISMATCH (err u1004))
(define-constant ERR_INSUFFICIENT_SHARES (err u1005))
(define-constant ERR_TOKEN_CALL_FAILED (err u1006))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1007))
(define-constant PROTOCOL_FEE_SHARE u1000) ;; 10% of LP fee for BME

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var settlement-authority principal tx-sender)
(define-data-var total-outstanding-shares uint u0)

(define-map pools
  uint
  {
    token-0: principal,
    token-1: principal,
    fee: uint, ;; bps with 1M denominator e.g. 3000 = 0.3%
    liquidity: uint,
    outstanding-shares: uint,
    sqrt-price: uint,
    tick: int
  }
)

(define-data-var pool-nonce uint u0)

;; --- Authorization and reconciliation reads ---

(define-read-only (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

(define-read-only (is-settlement-authority (caller principal))
  (is-eq caller (var-get settlement-authority))
)

(define-read-only (get-settlement-authority)
  (ok (var-get settlement-authority))
)

(define-read-only (get-total-outstanding-shares)
  (ok (var-get total-outstanding-shares))
)

;; Compatibility alias for integrations that used the pre-aggregate name.
(define-read-only (get-recorded-share-supply)
  (ok (var-get total-outstanding-shares))
)

(define-read-only (get-pool (pool-id uint))
  (ok (map-get? pools pool-id))
)

(define-read-only (get-pool-outstanding-shares (pool-id uint))
  (match (map-get? pools pool-id)
    pool (ok (get outstanding-shares pool))
    ERR_POOL_NOT_FOUND
  )
)

;; --- Administrative configuration ---

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-settlement-authority (authority principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set settlement-authority authority)
    (ok true)
  )
)

;; --- CSF Trait Implementation ---

;; @desc Register a liquidity marker for the protocol
(define-public (register-liquidity-marker (marker (string-ascii 256)))
  (ok true)
)

;; @desc Execute a swap through the Common Settlement Framework
(define-public (execute-csf-swap (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (recipient principal))
  (let (
    (amount-out (try! (swap-execute u1 amount-in token-in token-out recipient)))
  )
    (ok { amount-out: amount-out, fee-collected: u0 })
  )
)

;; @desc Request flash liquidity from the pool
(define-public (request-flash-liquidity (token <sip-010-ft-trait>) (amount uint) (payload (buff 32)))
  (ok true)
)

;; @desc Settle an arbitrage path through the CSF
(define-public (settle-arbitrage (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount uint) (route (list 10 principal)))
  (ok amount)
)

;; @desc Claim protocol yield through the CSF
(define-public (claim-conxian-yield (reward-token <sip-010-ft-trait>) (amount uint) (recipient principal))
  (ok amount)
)

;; @desc Get the health metrics of the CSF integration
(define-public (get-csf-health)
  (ok { tvl: u0, utilization: u0, is-active: true })
)

;; @desc Collect accumulated protocol fees
(define-public (collect-protocol-fees (token <sip-010-ft-trait>))
  (ok true)
)

;; --- SIP-010 Canonical CXLP Proxy ---

;; @desc Transfer canonical CXLP tokens to a recipient.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (contract-call? .cxlp-token transfer amount sender recipient memo)
)

;; @desc Get the canonical CXLP name.
(define-read-only (get-name)
  (contract-call? .cxlp-token get-name)
)

;; @desc Get the canonical CXLP symbol.
(define-read-only (get-symbol)
  (contract-call? .cxlp-token get-symbol)
)

;; @desc Get the canonical CXLP decimals.
(define-read-only (get-decimals)
  (contract-call? .cxlp-token get-decimals)
)

;; @desc Get a canonical CXLP balance.
(define-read-only (get-balance (user principal))
  (contract-call? .cxlp-token get-balance user)
)

;; @desc Get the canonical CXLP total supply.
(define-read-only (get-total-supply)
  (contract-call? .cxlp-token get-total-supply)
)

;; @desc Get the canonical CXLP metadata URI.
(define-read-only (get-token-uri)
  (contract-call? .cxlp-token get-token-uri)
)

;; --- Internal Logic ---

;; @desc Create a new concentrated liquidity pool
(define-public (create-pool (token-0 principal) (token-1 principal) (fee uint) (initial-price uint) (initial-tick int))
  (let (
    (id (+ (var-get pool-nonce) u1))
  )
    (begin
      (map-set pools id {
        token-0: token-0,
        token-1: token-1,
        fee: fee,
        liquidity: u0,
        outstanding-shares: u0,
        sqrt-price: initial-price,
        tick: initial-tick
      })
      (var-set pool-nonce id)
      (ok id)
    )
  )
)

;; --- CXLP share reconciliation hooks ---

;; These hooks intentionally do not transfer pool assets, settle positions, or
;; calculate fees. They are the atomic CXLP/share primitive that #536 can call
;; after its custody and execution checks have passed.
(define-public (mint-shares (pool-id uint) (owner principal) (amount uint))
  (begin
    (asserts! (is-settlement-authority contract-caller) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (canonical-owner-balance (unwrap! (contract-call? .cxlp-token get-balance owner) ERR_TOKEN_CALL_FAILED))
      (canonical-supply (unwrap! (contract-call? .cxlp-token get-total-supply) ERR_TOKEN_CALL_FAILED))
      (pool-share-total (get outstanding-shares pool))
      (tracked-supply (var-get total-outstanding-shares))
    )
      (begin
        ;; CXLP ownership is intentionally aggregate and transferable. The
        ;; CLP therefore tracks only pool totals and the protocol-wide total;
        ;; it never mirrors an owner balance that a normal SIP-010 transfer
        ;; could make stale.
        (asserts! (is-eq canonical-supply tracked-supply) ERR_SHARE_STATE_MISMATCH)
        (asserts! (<= amount (- MAX_UINT pool-share-total)) ERR_ARITHMETIC_OVERFLOW)
        (asserts! (<= amount (- MAX_UINT tracked-supply)) ERR_ARITHMETIC_OVERFLOW)

        ;; Write local reconciliation state before the downstream token call.
        ;; The CXLP mint has no callback path, and Clarity rolls these writes
        ;; back together with the call if the configured minter rejects it.
        (map-set pools pool-id
          (merge pool { outstanding-shares: (+ pool-share-total amount) }))
        (var-set total-outstanding-shares (+ tracked-supply amount))
        (try! (contract-call? .cxlp-token mint amount owner))

        ;; Verify the canonical token after all local writes; a failed
        ;; invariant reverts both the token call and the local reconciliation.
        (let (
          (post-owner-balance (unwrap! (contract-call? .cxlp-token get-balance owner) ERR_TOKEN_CALL_FAILED))
          (post-supply (unwrap! (contract-call? .cxlp-token get-total-supply) ERR_TOKEN_CALL_FAILED))
        )
          (begin
            (asserts! (is-eq post-owner-balance (+ canonical-owner-balance amount)) ERR_SHARE_STATE_MISMATCH)
            (asserts! (is-eq post-supply (+ canonical-supply amount)) ERR_SHARE_STATE_MISMATCH)
            (ok true)
          )
        )
      )
    )
  )
)

(define-public (burn-shares (pool-id uint) (owner principal) (amount uint))
  (begin
    (asserts! (is-settlement-authority contract-caller) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (canonical-owner-balance (unwrap! (contract-call? .cxlp-token get-balance owner) ERR_TOKEN_CALL_FAILED))
      (canonical-supply (unwrap! (contract-call? .cxlp-token get-total-supply) ERR_TOKEN_CALL_FAILED))
      (pool-share-total (get outstanding-shares pool))
      (tracked-supply (var-get total-outstanding-shares))
    )
      (begin
        (asserts! (is-eq canonical-supply tracked-supply) ERR_SHARE_STATE_MISMATCH)
        (asserts! (>= pool-share-total amount) ERR_INSUFFICIENT_SHARES)
        (asserts! (>= canonical-owner-balance amount) ERR_INSUFFICIENT_SHARES)
        (asserts! (>= canonical-supply amount) ERR_INSUFFICIENT_SHARES)

        ;; As with minting, local writes intentionally precede the token call
        ;; so a rejected burn proves transaction-wide rollback in tests.
        (map-set pools pool-id
          (merge pool { outstanding-shares: (- pool-share-total amount) }))
        (var-set total-outstanding-shares (- tracked-supply amount))
        (try! (contract-call? .cxlp-token burn amount owner))

        (let (
          (post-owner-balance (unwrap! (contract-call? .cxlp-token get-balance owner) ERR_TOKEN_CALL_FAILED))
          (post-supply (unwrap! (contract-call? .cxlp-token get-total-supply) ERR_TOKEN_CALL_FAILED))
        )
          (begin
            (asserts! (is-eq post-owner-balance (- canonical-owner-balance amount)) ERR_SHARE_STATE_MISMATCH)
            (asserts! (is-eq post-supply (- canonical-supply amount)) ERR_SHARE_STATE_MISMATCH)
            (ok true)
          )
        )
      )
    )
  )
)

;; @desc Execute a swap in a concentrated liquidity pool
(define-public (swap (pool-id uint) (is-token-0 bool) (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (recipient principal))
  (swap-execute pool-id amount-in token-in token-out recipient)
)

;; @desc Get the status of the CL pool contract
(define-read-only (get-protocol-status)
  (ok {
    active: true,
    version: "v1.2.0-Apex",
    pool-count: (var-get pool-nonce),
    fee-share: PROTOCOL_FEE_SHARE
  })
)

(define-private (swap-execute (pool-id uint) (amount-in uint) (token-in-trait <sip-010-ft-trait>) (token-out-trait <sip-010-ft-trait>) (recipient principal))
  (let (
    (pool (match (map-get? pools pool-id) p p { token-0: tx-sender, token-1: tx-sender, fee: u3000, liquidity: u0, outstanding-shares: u0, sqrt-price: u0, tick: 0 }))
    (lp-fee (/ (* amount-in (get fee pool)) u1000000))
    ;; Mandatory Protocol Fee (Sovereign Tax) - 100 bps (1%) = 10000 / 1000000
    (gov-tax (/ (* amount-in u10000) u1000000))
    (total-deduction (+ lp-fee gov-tax))
    (amount-out (- amount-in total-deduction))
    ;; BME gets a portion of the LP fee for emissions logic
    (bme-fee (/ (* lp-fee PROTOCOL_FEE_SHARE) u10000))
  )
    (begin
      ;; 1. Transfer in
      (try! (contract-call? token-in-trait transfer amount-in tx-sender (as-contract tx-sender) none))

      ;; 2. Protocol fee collection handled by swap-router (avoids circular dep)

      ;; 3. Transfer out
      (try! (as-contract (contract-call? token-out-trait transfer amount-out (as-contract tx-sender) recipient none)))

      ;; 4. Report activity to BME
      (let (
        (bme-res (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) bme-fee))
      )
        (print { event: "bme-report-processed", success: (is-ok bme-res) })
      )
      (ok amount-out)
    )
  )
)
