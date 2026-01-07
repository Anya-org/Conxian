;; oracle-pricing.clar
;; Trait definitions for Conxian Protocol Oracles

(define-trait oracle-trait (
  (get-price
    (principal)
    (response uint uint)
  )
  (get-name
    ()
    (response (string-ascii 32) uint)
  )
))

(define-trait oracle-aggregator-v2-trait (
  (get-price
    (principal)
    (response uint uint)
  )
  (get-price-by-intent
    (principal (string-ascii 20))
    (response uint uint)
  )
  (get-weights
    (principal)
    (response (list 10 uint) uint)
  )
))

(define-trait pyth-core-trait (
  (verify-and-update-price-feeds
    ((buff 2048))
    (response bool uint)
  )
  (get-price
    (principal)
    (
      response       {
      price: uint,
      expo: int,
      publish-time: uint,
    }
      uint
    )
  )
))

(define-trait redstone-core-trait (
  (recover-signer
    (
      uint       (list 10 {
      asset: (buff 32),
      value: uint,
    })
      (buff 65)
    )
    (response bool uint)
  )
))
