;; core-traits.clar
;; Definition of core module traits

(define-trait ownable-trait (
    (get-owner
        ()
        (response principal uint)
    )
    (set-owner
        (principal)
        (response bool uint)
    )
))

(define-trait rbac-trait (
    (has-role
        (principal uint)
        (response bool uint)
    )
    (grant-role
        (principal uint)
        (response bool uint)
    )
    (revoke-role
        (principal uint)
        (response bool uint)
    )
))

(define-trait position-manager-trait
    (
        (open-position (principal principal uint uint bool) (response uint uint))
        (close-position (principal uint) (response bool uint))
    )
)

(define-trait collateral-manager-trait
    (
        (deposit (principal principal uint) (response bool uint))
        (withdraw (principal principal uint) (response bool uint))
    )
)

(define-trait risk-manager-trait
    (
        (get-health-factor (uint) (response uint uint))
        (liquidate (uint) (response uint uint))
    )
)

(define-trait funding-rate-trait
    (
        (get-funding-rate (uint) (response uint uint))
    )
)
