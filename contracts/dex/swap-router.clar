;; swap-router.clar - Dynamic Dispatch Router
;; Conxian Protocol - Apex CSF Upgrade (v1.1.0)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait csf-liquidity-trait .conxian-csf-trait.trait-csf-liquidity-v1)

;; --- Constants ---
(define-constant BASE-FEE u30)
(define-constant MAX-FEE u100)
(define-constant ERR_INTERNAL (err u500))
(define-constant ERR_SLIPPAGE (err u501))
(define-constant ERR_NON_COMPLIANT (err u502))
(define-constant ERR_PROTOCOL_PAUSED (err u503))
(define-constant ERR_SOURCE_ISOLATED (err u504))

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
    (paused-state (unwrap! (contract-call? .enhanced-circuit-breaker is-contract-paused .swap-router) ERR_INTERNAL))
    (is-isolated-res (unwrap! (contract-call? .enhanced-circuit-breaker is-isolated (contract-of liquidity-source)) ERR_INTERNAL))
  )
    (begin
      (asserts! (not paused-state) ERR_PROTOCOL_PAUSED)
      (asserts! (not is-isolated-res) ERR_SOURCE_ISOLATED)

      (let (
        (swap-res (try! (contract-call? liquidity-source execute-csf-swap token-in token-out amount-in tx-sender)))
        (amount-out (get amount-out swap-res))
        (fee-collected (get fee-collected swap-res))
      )
        (begin
          (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE)

          (match (contract-call? .bme-engine register-fee-activity (contract-of liquidity-source) fee-collected)
            res true
            err-val false
          )

          (print {
            event: "csf-swap-executed",
            source: (contract-of liquidity-source),
            token-in: (contract-of token-in),
            token-out: (contract-of token-out),
            amount-out: amount-out,
            fee: fee-collected,
            sender: tx-sender
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
    (vol (unwrap! (contract-call? .oracle-aggregator get-volatility-index) ERR_INTERNAL))
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
  (begin
    (try! (contract-call? token-in transfer amount-in tx-sender .concentrated-liquidity-pool none))
    (contract-call? .concentrated-liquidity-pool swap pool-id true amount-in token-in token-out)
  )
)

;; @desc Get the current operational status of the swap router
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", tenure-id: (some (/ block-height u10)) })
)
