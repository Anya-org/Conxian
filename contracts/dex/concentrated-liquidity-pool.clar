;; concentrated-liquidity-pool.clar
;; Conxian DEX: Concentrated Liquidity Pool Engine
;; Aligned with Apex CSF (v1.2.0) and Nakamoto Standard.
;;
;; Phase 1 state primitives use concentrated-math's bounded 1e12 sqrt-price
;; scale and deterministic linear tick approximation. These reads do not claim
;; exact Uniswap V3 math and do not create executable positions, custody assets,
;; or mutate reserves.

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
(define-constant ERR_FEE_CUSTODY_UNAVAILABLE (err u1008))
(define-constant ERR_INVALID_TOKEN_PAIR (err u1100))
(define-constant ERR_INVALID_FEE (err u1101))
(define-constant ERR_INVALID_TICK (err u1102))
(define-constant ERR_INVALID_SQRT_PRICE (err u1103))
(define-constant ERR_POOL_ALREADY_EXISTS (err u1104))
(define-constant ERR_INVALID_TICK_RANGE (err u1105))
(define-constant ERR_INVALID_LIQUIDITY_BOUND (err u1106))
(define-constant ERR_SWAP_TOKEN_MISMATCH (err u1107))
(define-constant ERR_ALREADY_INITIALIZED (err u1108))
(define-constant MIN_POOL_FEE u1)
(define-constant MAX_POOL_FEE u10000)
(define-constant PROTOCOL_FEE_SHARE u1000) ;; 10% of LP fee for BME

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var pool-registrar principal tx-sender)
(define-data-var initialized bool false)
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

;; Pair keys are stored in both token orders so duplicate detection does not
;; require ordering or comparing principal values.
(define-map pool-ids-by-pair
  { token-a: principal, token-b: principal, fee: uint }
  uint
)

(define-data-var pool-nonce uint u0)

;; --- Authorization and reconciliation reads ---

(define-read-only (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

(define-read-only (is-settlement-authority (caller principal))
  (is-eq caller (var-get settlement-authority))
)

(define-read-only (is-pool-registrar (caller principal))
  (is-eq caller (var-get pool-registrar))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-pool-registrar)
  (ok (var-get pool-registrar))
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

(define-read-only (get-pool-id (token-a principal) (token-b principal) (fee uint))
  (map-get? pool-ids-by-pair { token-a: token-a, token-b: token-b, fee: fee })
)

(define-read-only (get-pool-state (pool-id uint))
  (match (map-get? pools pool-id)
    pool (ok pool)
    ERR_POOL_NOT_FOUND
  )
)

(define-read-only (get-current-tick (pool-id uint))
  (match (map-get? pools pool-id)
    pool (ok (get tick pool))
    ERR_POOL_NOT_FOUND
  )
)

(define-read-only (get-current-sqrt-price (pool-id uint))
  (match (map-get? pools pool-id)
    pool (ok (get sqrt-price pool))
    ERR_POOL_NOT_FOUND
  )
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
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (var-set admin new-admin)
    (var-set pool-registrar new-admin)
    (var-set initialized true)
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

(define-public (set-pool-registrar (registrar principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set pool-registrar registrar)
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
    (amount-out (try! (swap-execute u1 true amount-in token-in token-out recipient)))
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
  (begin
    ;; Fees are not segregated from pool/user custody; never transfer untracked assets.
    (asserts! false ERR_FEE_CUSTODY_UNAVAILABLE)
    (ok false)
  )
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

(define-private (valid-preview-range (tick-lower int) (tick-upper int))
  (and
    (< tick-lower tick-upper)
    (contract-call? .concentrated-math is-supported-execution-tick tick-lower)
    (contract-call? .concentrated-math is-supported-execution-tick tick-upper)
  )
)

(define-private (preview-amount0 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint) (round-up bool))
  (if round-up
    (contract-call? .concentrated-math get-amount0-delta-up sqrt-price-a sqrt-price-b liquidity)
    (contract-call? .concentrated-math get-amount0-delta-down sqrt-price-a sqrt-price-b liquidity)
  )
)

(define-private (preview-amount1 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint) (round-up bool))
  (if round-up
    (contract-call? .concentrated-math get-amount1-delta-up sqrt-price-a sqrt-price-b liquidity)
    (contract-call? .concentrated-math get-amount1-delta-down sqrt-price-a sqrt-price-b liquidity)
  )
)

;; @desc Pure amount preview from validated stored pool state and a caller range.
;; The result is a bounded approximation using the documented 1e12 scale. It
;; performs no custody, reserve, liquidity, share, or position mutation.
(define-read-only (preview-position-amounts
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
    (round-up bool)
  )
  (begin
    (asserts! (valid-preview-range tick-lower tick-upper) ERR_INVALID_TICK_RANGE)
    (asserts!
      (and
        (> liquidity u0)
        (<= liquidity (contract-call? .concentrated-math get-max-supported-liquidity))
      )
      ERR_INVALID_LIQUIDITY_BOUND
    )
    (let (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
      (current-sqrt-price (get sqrt-price pool))
      (lower-sqrt-price (unwrap!
        (contract-call? .concentrated-math get-sqrt-ratio-at-tick-checked tick-lower)
        ERR_INVALID_TICK_RANGE
      ))
      (upper-sqrt-price (unwrap!
        (contract-call? .concentrated-math get-sqrt-ratio-at-tick-checked tick-upper)
        ERR_INVALID_TICK_RANGE
      ))
    )
      (if (<= current-sqrt-price lower-sqrt-price)
        (ok {
          amount-0: (try! (preview-amount0 lower-sqrt-price upper-sqrt-price liquidity round-up)),
          amount-1: u0,
          approximation: "bounded-linear-tick-model",
          round-up: round-up
        })
        (if (< current-sqrt-price upper-sqrt-price)
          (ok {
            amount-0: (try! (preview-amount0 current-sqrt-price upper-sqrt-price liquidity round-up)),
            amount-1: (try! (preview-amount1 lower-sqrt-price current-sqrt-price liquidity round-up)),
            approximation: "bounded-linear-tick-model",
            round-up: round-up
          })
          (ok {
            amount-0: u0,
            amount-1: (try! (preview-amount1 lower-sqrt-price upper-sqrt-price liquidity round-up)),
            approximation: "bounded-linear-tick-model",
            round-up: round-up
          })
        )
      )
    )
  )
)

;; @desc Create a new concentrated liquidity pool
(define-public (create-pool (token-0 principal) (token-1 principal) (fee uint) (initial-price uint) (initial-tick int))
  (begin
    ;; Use the immediate caller so a configured registrar contract can create
    ;; pools without allowing an arbitrary transaction sender to reserve keys.
    (asserts!
      (or (is-admin contract-caller) (is-pool-registrar contract-caller))
      ERR_UNAUTHORIZED
    )
    (asserts! (not (is-eq token-0 token-1)) ERR_INVALID_TOKEN_PAIR)
    (asserts! (and (>= fee MIN_POOL_FEE) (<= fee MAX_POOL_FEE)) ERR_INVALID_FEE)
    (asserts!
      (contract-call? .concentrated-math is-supported-execution-tick initial-tick)
      ERR_INVALID_TICK
    )
    (let ((expected-price (unwrap!
        (contract-call? .concentrated-math get-sqrt-ratio-at-tick-checked initial-tick)
        ERR_INVALID_TICK
      )))
      (asserts! (is-eq initial-price expected-price) ERR_INVALID_SQRT_PRICE)
    )
    (asserts!
      (is-none (map-get? pool-ids-by-pair {
        token-a: token-0,
        token-b: token-1,
        fee: fee
      }))
      ERR_POOL_ALREADY_EXISTS
    )
    (asserts! (< (var-get pool-nonce) MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
    (let ((id (+ (var-get pool-nonce) u1)))
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
      (map-set pool-ids-by-pair {
        token-a: token-0,
        token-b: token-1,
        fee: fee
      } id)
      (map-set pool-ids-by-pair {
        token-a: token-1,
        token-b: token-0,
        fee: fee
      } id)
      (var-set pool-nonce id)
      (ok id)
      )
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
;; This legacy path only binds the requested token direction to a registered
;; pool before custody movement. It does not add reserve math, price movement,
;; or new swap economics.
(define-public (swap (pool-id uint) (is-token-0 bool) (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (recipient principal))
  (swap-execute pool-id is-token-0 amount-in token-in token-out recipient)
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

(define-private (swap-execute (pool-id uint) (is-token-0 bool) (amount-in uint) (token-in-trait <sip-010-ft-trait>) (token-out-trait <sip-010-ft-trait>) (recipient principal))
  (let (
    (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
    (expected-token-in (if is-token-0 (get token-0 pool) (get token-1 pool)))
    (expected-token-out (if is-token-0 (get token-1 pool) (get token-0 pool)))
  )
    (begin
      (asserts!
        (and
          (is-eq (contract-of token-in-trait) expected-token-in)
          (is-eq (contract-of token-out-trait) expected-token-out)
        )
        ERR_SWAP_TOKEN_MISMATCH
      )
      (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
      (asserts! (<= amount-in (/ MAX_UINT u10000)) ERR_ARITHMETIC_OVERFLOW)
      (let (
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
  )
)
