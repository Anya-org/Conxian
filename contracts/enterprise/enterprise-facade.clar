;; enterprise-facade.clar
;; Enterprise Institutional Access Facade
;; Facade Pattern: Thin routing layer

(use-trait rbac-trait .core-traits.rbac-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var backend principal .institutional-account-manager)

(define-public (register-institution (name (string-ascii 64)) (limit uint))
    (begin
        ;; Access check handled by facade
        (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) ERR_UNAUTHORIZED)
        (contract-call? .institutional-account-manager register-institution name limit)
    )
)

(define-public (set-account-limit (institution principal) (new-limit uint))
    (begin
        (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) ERR_UNAUTHORIZED)
        (contract-call? .institutional-account-manager set-limit institution new-limit)
    )
)
