;; pool-trait.clar
;; Standardized pool interface for AutoVault DeFi ecosystem

(define-trait pool-trait
  (
    ;; Core liquidity functions
    (add-liquidity (uint uint uint uint) (response {shares: uint} uint))
    (remove-liquidity (uint uint uint uint) (response {dx: uint, dy: uint} uint))
    
    ;; Swap functions
    (swap-exact-in (uint uint bool uint) (response {amount-out: uint} uint))
    
    ;; Pool information (read-only functions)
    (get-reserves () (response {rx: uint, ry: uint} uint))
    (get-fee-info () (response {lp-fee-bps: uint, protocol-fee-bps: uint} uint))
    (get-price () (response {price-x-y: uint, price-y-x: uint} uint))
  )
)
