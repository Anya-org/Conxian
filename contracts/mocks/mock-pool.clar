;; mock-pool.clar
;; Mock Pool for testing

(define-public (swap (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))
    (ok amount-in)
)

(define-read-only (get-price (token principal))
    (ok u100000000)
)
