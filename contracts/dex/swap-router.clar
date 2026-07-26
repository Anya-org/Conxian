;; swap-router.clar - Dynamic Dispatch Router
;; Conxian Protocol - Apex CSF Upgrade (v1.1.0)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait csf-liquidity-trait .conxian-csf-trait.trait-csf-liquidity-v1)

;; --- Constants ---
(define-constant BASE-FEE u30)
(define-constant MAX-FEE u100)
(define-constant ERR_INTERNAL u500)
(define-constant ERR_SLIPPAGE u501)
(define-constant ERR_NON_COMPLIANT u502)
(define-constant ERR_PROTOCOL_PAUSED u503)
(define-constant ERR_SOURCE_ISOLATED u504)
(define-constant ERR_V2_INVALID_PAIR u2301)
(define-constant ERR_V2_PRICE_LIMIT u2316)

;; --- Data Vars ---
(define-data-var current-fee uint u30)
(define-data-var admin principal tx-sender)

;; --- CSF Dynamic Dispatch ---

;; @desc Swap tokens through any CSF-compliant liquidity source
(define-public (csf-swap
    (liquidity-source <csf-liquidity-trait>)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (min-amount-out uint)
  )
  (let (
    (paused-state (unwrap-panic (contract-call? .enhanced-circuit-breaker is-contract-paused .swap-router)))
    (is-isolated-res (unwrap-panic (contract-call? .enhanced-circuit-breaker is-isolated (contract-of liquidity-source))))
    (user tx-sender)
  )
    (begin
      (asserts! (not paused-state) (err ERR_PROTOCOL_PAUSED))
      (asserts! (not is-isolated-res) (err ERR_SOURCE_ISOLATED))

      ;; 1. Transfer tokens from User to Router
      (try! (contract-call? token-in transfer amount-in user (as-contract tx-sender) none))

      (let (
        ;; 2. Execute swap as Router
        (swap-res (try! (as-contract (contract-call? liquidity-source execute-csf-swap token-in token-out amount-in (as-contract tx-sender)))))
        (amount-out (get amount-out swap-res))
        (fee-collected (get fee-collected swap-res))
      )
        (begin
          (asserts! (>= amount-out min-amount-out) (err ERR_SLIPPAGE))

          (match (contract-call? .bme-engine register-fee-activity (contract-of liquidity-source) fee-collected)
            res true
            err-val false
          )

          ;; 3. Transfer tokens back to User
          (try! (as-contract (contract-call? token-out transfer amount-out (as-contract tx-sender) user none)))

          (print {
            event: "csf-swap-executed",
            source: (contract-of liquidity-source),
            token-in: (contract-of token-in),
            token-out: (contract-of token-out),
            amount-out: amount-out,
            fee: fee-collected,
            sender: user
          })
          (ok amount-out)
        )
      )
    )
  )
)

;; @desc Claim external protocol yield through a CSF source
(define-public (claim-external-yield
    (liquidity-source <csf-liquidity-trait>)
    (reward-token <sip-010-ft-trait>)
    (amount uint)
  )
  (begin
    (contract-call? liquidity-source claim-conxian-yield reward-token amount tx-sender)
  )
)

;; @desc Update the protocol fees based on current market volatility
(define-public (update-volatility-fees)
  (let (
    (vol (unwrap-panic (contract-call? .oracle-aggregator get-volatility-index)))
    (new-fee (if (> vol u75) MAX-FEE BASE-FEE))
  )
    (begin
      (var-set current-fee new-fee)
      (ok new-fee)
    )
  )
)

;; @desc Execute a swap on a single pool with exact input amount
(define-public (exact-input-single
    (pool-id uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (min-amount-out uint)
  )
  (let (
    (user tx-sender)
  )
    (begin
      ;; 1. Transfer tokens from User to Router
      (try! (contract-call? token-in transfer amount-in user (as-contract tx-sender) none))

      (let (
        ;; 2. Execute swap as Router (fee collection handled upstream)
        (amount-out (try! (as-contract (contract-call? .concentrated-liquidity-pool swap pool-id true amount-in token-in token-out (as-contract tx-sender)))))
      )
        (begin
          (asserts! (>= amount-out min-amount-out) (err ERR_SLIPPAGE))

          ;; 3. Transfer tokens back to User
          (try! (as-contract (contract-call? token-out transfer amount-out (as-contract tx-sender) user none)))

          (ok amount-out)
        )
      )
    )
  )
)

;; @desc Execute an exact-input swap against the V2 direct-custody pool. Token
;; direction is derived only from the pool's canonical token order. The router
;; neither pre-transfers nor retains input/output funds.
(define-public (exact-input-single-v2
    (pool-id uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (sqrt-price-limit uint)
    (min-amount-out uint)
    (recipient principal)
  )
  (let (
      (paused-state (unwrap! (contract-call? .enhanced-circuit-breaker
        is-contract-paused .swap-router) (err ERR_PROTOCOL_PAUSED)))
      (is-isolated-res (unwrap! (contract-call? .enhanced-circuit-breaker
        is-isolated .concentrated-liquidity-pool-v2) (err ERR_SOURCE_ISOLATED)))
      (pool (unwrap! (contract-call? .concentrated-liquidity-pool-v2 get-pool pool-id)
        (err u2306)))
      (zero-for-one (and
        (is-eq (contract-of token-in) (get token-0 pool))
        (is-eq (contract-of token-out) (get token-1 pool))))
      (one-for-zero (and
        (is-eq (contract-of token-in) (get token-1 pool))
        (is-eq (contract-of token-out) (get token-0 pool))))
    )
    (begin
      (asserts! (not paused-state) (err ERR_PROTOCOL_PAUSED))
      (asserts! (not is-isolated-res) (err ERR_SOURCE_ISOLATED))
      (asserts! (or zero-for-one one-for-zero) (err ERR_V2_INVALID_PAIR))
      (asserts! (if zero-for-one
        (< sqrt-price-limit (get sqrt-price pool))
        (> sqrt-price-limit (get sqrt-price pool))) (err ERR_V2_PRICE_LIMIT))
      (contract-call? .concentrated-liquidity-pool-v2 swap-exact-input
        pool-id token-in token-out zero-for-one amount-in sqrt-price-limit
        min-amount-out recipient)
    )
  )
)

;; @desc Swap external token to CXD and burn the proceeds.
;; Orchestrates token->CXD swap via CLP, then burns CXD via bme-engine.
;; Callable by revenue-distributor or any authorized module.
(define-public (swap-and-burn (token <sip-010-ft-trait>) (amount uint))
  (let (
    (user tx-sender)
  )
    (begin
      ;; 1. Transfer tokens from user to router
      (try! (contract-call? token transfer amount user (as-contract tx-sender) none))
      ;; 2. Swap token -> CXD via CLP (pool u1, token-in is token-0)
      (let ((amount-out (try! (as-contract (contract-call? .concentrated-liquidity-pool swap u1 true amount token .cxd-token (as-contract tx-sender))))))
        ;; 3. Burn the received CXD via bme-engine
        (try! (contract-call? .bme-engine burn-cxd amount-out))
        (print { event: "swap-and-burn-executed", token: (contract-of token), amount: amount, cxd-burned: amount-out })
        (ok true)
      )
    )
  )
)

;; @desc Get the current operational status of the swap router
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", tenure-id: (some (/ block-height u10)) })
)
