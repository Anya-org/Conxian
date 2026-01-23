;; risk-management.clar
;; Risk Management Traits

(define-trait risk-manager-trait
    (
        (validate-position (uint uint uint) (response bool uint))
        (check-liquidation-risk (uint uint) (response bool uint))
    )
)
