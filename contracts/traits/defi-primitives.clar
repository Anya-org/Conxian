;; defi-primitives.clar
;; DeFi Primitive Traits

(define-trait swap-pool-trait
    (
        (swap (uint principal principal) (response uint uint))
        (get-reserves () (response { a: uint, b: uint } uint))
    )
)

(define-trait lending-pool-trait
    (
        (deposit (uint principal) (response bool uint))
        (borrow (uint principal) (response bool uint))
    )
)
