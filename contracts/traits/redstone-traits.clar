;; redstone-traits.clar
;; Traits for RedStone Oracle integration

(define-trait redstone-core-trait
    (
        (verify-data-package ((buff 2048)) (response bool uint))
        (get-price (principal) (response uint uint))
    )
)
