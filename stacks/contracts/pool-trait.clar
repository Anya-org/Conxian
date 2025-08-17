;; BETA: Pool trait foundation for experimental DEX components.
(define-trait pool-trait
  (
    (add-liquidity (uint uint uint uint) (response (tuple (shares uint)) uint))
    (remove-liquidity (uint uint uint uint) (response (tuple (dx uint) (dy uint)) uint))
    (swap-exact-in (uint uint bool uint) (response (tuple (amount-out uint)) uint))
    (get-reserves () (response (tuple (rx uint) (ry uint)) uint))
    (get-fee-info () (response (tuple (lp-fee-bps uint) (protocol-fee-bps uint)) uint))
    (get-price () (response (tuple (price-x-y uint) (price-y-x uint)) uint))
  )
)
