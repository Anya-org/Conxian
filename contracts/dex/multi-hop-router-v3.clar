;; multi-hop-router-v3.clar
;; Advanced Router supporting multi-hop paths
;; Implements atomic execution and slippage protection

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait swap-pool-trait .defi-primitives.swap-pool-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_PATH (err u2005))
(define-constant ERR_SLIPPAGE (err u2006))
(define-constant ERR_INVALID_INPUT (err u2007))

;; @desc Swaps exact tokens for tokens supporting multi-hop
;; @param amount-in Amount of input tokens
;; @param amount-out-min Minimum amount of output tokens
;; @param pools List of pool contracts to swap through
;; @param tokens List of tokens involved (input, intermediate, output)
(define-public (swap-exact-tokens-for-tokens
    (amount-in uint)
    (amount-out-min uint)
    (pools (list 4 <swap-pool-trait>))
    (tokens (list 5 <sip-010-trait>))
)
    (let
        (
            (token-in (unwrap! (element-at tokens u0) ERR_INVALID_INPUT))
            (swap-1 (try! (swap-helper amount-in (element-at pools u0) (element-at tokens u0) (element-at tokens u1))))
            (swap-2 (if (> (len pools) u1)
                (try! (swap-helper swap-1 (element-at pools u1) (element-at tokens u1) (element-at tokens u2)))
                swap-1
            ))
            (swap-3 (if (> (len pools) u2)
                (try! (swap-helper swap-2 (element-at pools u2) (element-at tokens u2) (element-at tokens u3)))
                swap-2
            ))
            (swap-4 (if (> (len pools) u3)
                (try! (swap-helper swap-3 (element-at pools u3) (element-at tokens u3) (element-at tokens u4)))
                swap-3
            ))
        )
        (asserts! (>= swap-4 amount-out-min) ERR_SLIPPAGE)
        (ok swap-4)
    )
)

;; Helper to execute a single swap
;; Handles the trait call
(define-private (execute-swap (p <swap-pool-trait>) (amount-in uint) (ti <sip-010-trait>) (to <sip-010-trait>))
    (contract-call? p swap amount-in (contract-of ti) (contract-of to))
)

(define-private (swap-helper
    (amount-in uint)
    (pool (optional <swap-pool-trait>))
    (token-in (optional <sip-010-trait>))
    (token-out (optional <sip-010-trait>))
)
    (let (
        (ti (unwrap! token-in ERR_INVALID_INPUT))
        (to (unwrap! token-out ERR_INVALID_INPUT))
    )
        (execute-swap (unwrap! pool (ok amount-in)) amount-in ti to)
    )
)
