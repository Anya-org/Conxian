;; access-control-trait.clar
;; Standard Access Control Trait

(define-trait access-control-trait
    (
        (has-role (principal uint) (response bool uint))
        (grant-role (principal uint) (response bool uint))
        (revoke-role (principal uint) (response bool uint))
    )
)
