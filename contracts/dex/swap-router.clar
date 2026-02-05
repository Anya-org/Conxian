;; swap-router.clar
;; DEX Interaction Layer: Handles Single and Multi-hop swaps
;; Nakamoto-aligned with burn-block-height

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_SLIPPAGE u3000)
(define-constant ERR_INVALID_PATH u2005)

(define-constant BASE-FEE u30) ;; 0.3%
(define-constant MAX-FEE u100) ;; 1.0%

;; State
(define-data-var last-check-height uint u0)
(define-data-var current-fee uint u30)

;; Public Functions

(define-public (set-fee (new-fee uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u1)) (err ERR_UNAUTHORIZED)) ;; ROLE_ADMIN
    (var-set current-fee new-fee)
    (ok true)
  )
)

;; @desc Executes a single-hop swap between two tokens using a specific pool.
(define-public (exact-input-single
    (pool-id uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (min-amount-out uint)
  )
  (begin
    (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))

    (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
    
    (let (
      (pool-state (unwrap! (contract-call? .concentrated-liquidity-pool get-pool pool-id) (err ERR_INVALID_PATH)))
      (zero-for-one (is-eq (contract-of token-in) (get token0 pool-state)))
    )
      (let ((amount-out (as-contract (if zero-for-one
                          (try! (contract-call? .concentrated-liquidity-pool swap pool-id zero-for-one amount-in token-in token-out))
                          (try! (contract-call? .concentrated-liquidity-pool swap pool-id zero-for-one amount-in token-out token-in))
                        ))))
        (begin
          (asserts! (>= amount-out min-amount-out) (err ERR_SLIPPAGE))
          
          (let ((user tx-sender))
            (try! (as-contract (contract-call? token-out transfer amount-out (as-contract tx-sender) user none)))
          )
          
          (print {
            event: "router-swap",
            user: tx-sender,
            pool-id: pool-id,
            amount-in: amount-in,
            amount-out: amount-out,
            burn-height: burn-block-height
          })
          (ok amount-out)
        )
      )
    )
  )
)

;; Multi-hop stub
(define-public (exact-input-multi
    (pool-ids (list 5 uint))
    (tokens (list 6 principal))
    (amount-in uint)
    (min-amount-out uint)
  )
  (begin
    (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))
    (ok amount-in)
  )
)

(define-read-only (get-fee)
  (ok (var-get current-fee))
)

(define-public (set-fee (new-fee uint))
  (begin
    (asserts! (or (is-eq contract-caller .ops-engine) (unwrap-panic (contract-call? .admin-facade is-authorized u1))) (err ERR_UNAUTHORIZED))
    (var-set current-fee new-fee)
    (ok true)
  )
)

(define-public (update-volatility-fees)
  (begin
    (asserts! (or (is-eq contract-caller .ops-engine) (unwrap-panic (contract-call? .admin-facade is-authorized u1))) (err ERR_UNAUTHORIZED))
    (let
        (
            (current-height block-height)
            (height-diff (- current-height (var-get last-check-height)))
        )
        (if (<= height-diff u10)
          (ok (var-get current-fee))
          (let
              (
                  (volatility-index (unwrap-panic (contract-call? .oracle-aggregator get-volatility-index)))
                  (new-fee (if (> volatility-index u50) MAX-FEE BASE-FEE))
              )
              (begin
                (try! (contract-call? .concentrated-liquidity-pool set-pool-fee u1 new-fee))
                (var-set current-fee new-fee)
                (var-set last-check-height current-height)
                (print { event: "dex-fee-updated", new-fee: new-fee, volatility: volatility-index })
                (ok new-fee)
              )
          )
        )
    )
  )
)
