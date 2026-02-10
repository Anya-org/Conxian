;; swap-router.clar
;; DEX Interaction Layer: Handles Single and Multi-hop swaps
;; COMPATIBILITY MODE

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
          (ok amount-out)
        )
      )
    )
  )
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
                (var-set current-fee new-fee)
                (var-set last-check-height current-height)
                (ok new-fee)
              )
          )
        )
    )
  )
)

(define-read-only (get-fee)
  (ok (var-get current-fee))
)
(define-public (swap-direct (amount-in uint) (min-amount-out uint) (pool principal) (token-in principal) (token-out principal))
  (ok amount-in)
)
