;; defi-traits.clar
;; Standard DeFi Traits for Conxian Protocol

(define-trait flash-loan-user-trait
    (
        (execute-operation (uint principal) (response bool uint))
    )
)

(define-trait oracle-trait
    (
        (get-price (principal) (response uint uint))
        (fetch-price (principal) (response uint uint))
    )
)

(define-trait fee-receiver-trait
    (
        (receive-fee (uint principal) (response bool uint))
    )
)
