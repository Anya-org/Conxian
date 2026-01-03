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
    (get-weights
        (principal)
        (response (list 10 uint) uint)
    )
))
