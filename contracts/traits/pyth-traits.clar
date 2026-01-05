;; pyth-traits.clar
;; Traits for Pyth Network integration

(define-trait pyth-core-trait
    (
        (verify-and-update-price-feeds ((buff 2048)) (response (list 10 uint) uint))
        (get-price (principal) (response uint uint))
    )
)

(define-trait pyth-store-trait
    (
        (add-price (principal uint uint) (response bool uint))
        (get-price (principal) (response uint uint))
    )
)
