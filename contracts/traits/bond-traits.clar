;; bond-traits.clar
;; Standard Traits for Bonding Curves and Bond Tokens

(define-trait bond-token-trait (
  (mint
    (uint principal)
    (response bool uint)
  )
  (burn
    (uint principal)
    (response bool uint)
  )
))

(define-trait bonding-curve-trait (
  (get-price
    (uint)
    (response uint uint)
  )
  (calculate-purchase-return
    (uint uint)
    (response uint uint)
  )
))
