;; bond-traits.clar
;; Standard Traits for Bonding Curves and Bond Tokens
;; Standardized for Mainnet (March 2026)

(define-trait bond-token-trait (
  (mint (uint principal) (response bool uint))
  (burn (uint principal) (response bool uint))
))

(define-trait bonding-curve-trait (
  (get-price (uint) (response uint uint))
  (calculate-purchase-return (uint uint) (response uint uint))
))

;; @desc DLC Bond Trait for Bitcoin-anchored debt instruments
(define-trait dlc-bond-trait (
  (initialize-bond (uint uint uint principal) (response uint uint))
  (distribute-coupon (uint) (response bool uint))
  (redeem-bond (uint) (response bool uint))
  (get-bond-data (uint) (response (optional (tuple (issuer principal) (token principal) (principal-amount uint) (coupon-rate uint) (maturity uint) (created-at uint) (status (string-ascii 20)))) uint))
))
