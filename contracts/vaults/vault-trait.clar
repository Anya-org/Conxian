;; vault-trait.clar
;; Standard trait for Conxian Vaults

(define-trait vault-trait (
    (deposit
        (uint principal)
        (response bool uint)
    )
    (withdraw
        (uint principal)
        (response bool uint)
    )
    (get-balance
        (principal)
        (response uint uint)
    )
))