;; mock-clp-v2-intermediary.clar
;;
;; Simnet-only forwarding contract used to prove that executable CLP V2
;; routes preserve the originating tx-sender across nested contract-call?.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-public (forward-open-position-v2
    (pool-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (tick-lower int)
    (tick-upper int)
    (max-amount0 uint)
    (max-amount1 uint)
    (min-liquidity uint)
  )
  (contract-call? .liquidity-manager open-position-v2
    pool-id token-0 token-1 tick-lower tick-upper
    max-amount0 max-amount1 min-liquidity)
)

(define-public (forward-close-position-v2
    (position-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (min-amount0 uint)
    (min-amount1 uint)
  )
  (contract-call? .liquidity-manager close-position-v2
    position-id token-0 token-1 min-amount0 min-amount1)
)

(define-public (forward-rebalance-position-v2
    (position-id uint)
    (token-0 <sip-010-ft-trait>)
    (token-1 <sip-010-ft-trait>)
    (target-tick-lower int)
    (target-tick-upper int)
    (max-amount0 uint)
    (max-amount1 uint)
    (min-liquidity uint)
    (min-close-amount0 uint)
    (min-close-amount1 uint)
  )
  (contract-call? .liquidity-manager rebalance-position-v2
    position-id token-0 token-1 target-tick-lower target-tick-upper
    max-amount0 max-amount1 min-liquidity min-close-amount0 min-close-amount1)
)

(define-public (forward-exact-input-single-v2
    (pool-id uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (sqrt-price-limit uint)
    (min-amount-out uint)
    (recipient principal)
  )
  (contract-call? .swap-router exact-input-single-v2
    pool-id token-in token-out amount-in sqrt-price-limit min-amount-out recipient)
)
