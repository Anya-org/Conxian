;; pool-trait.clar
;; Standardized pool interface for AutoVault DeFi ecosystem

(define-trait pool-trait
  (
    ;; Core liquidity functions  
    (add-liquidity (uint uint uint uint) (response (tuple (shares uint)) uint))
    (remove-liquidity (uint uint uint uint) (response (tuple (dx uint) (dy uint)) uint))
    
    ;; Swap functions
    (swap-exact-in (uint uint bool uint) (response (tuple (amount-out uint)) uint))
    
    ;; Pool information (read-only functions)
    (get-reserves () (response (tuple (rx uint) (ry uint)) uint))
    (get-fee-info () (response (tuple (lp-fee-bps uint) (protocol-fee-bps uint)) uint))
    (get-price () (response (tuple (price-x-y uint) (price-y-x uint)) uint))
  )
)
;; Standardized pool interface for AutoVault DeFi ecosystem

(define-trait pool-trait
  (
    ;; Core liquidity functions
    (add-liquidity (uint uint uint uint) (response (tuple (shares uint)) uint))
    (remove-liquidity (uint uint uint uint) (response (tuple (dx uint) (dy uint)) uint))
    
    ;; Swap functions
    (swap-exact-in (uint uint bool uint) (response (tuple (amount-out uint)) uint))
    
    ;; Pool information
    (get-reserves () (response (tuple (rx uint) (ry uint)) uint))
    (get-fee-info () (response (tuple (lp-fee-bps uint) (protocol-fee-bps uint)) uint))
    (get-price () (response (tuple (price-x-y uint) (price-y-x uint)) uint))
  )
)
