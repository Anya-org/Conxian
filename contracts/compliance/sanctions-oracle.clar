;; sanctions-oracle.clar
;; Mock Sanctions Oracle for Conxian Compliance

(define-constant ERR_UNAUTHORIZED (err u5000))

(define-map sanctioned-addresses principal bool)

(define-read-only (is-sanctioned (user principal))
    (ok (default-to false (map-get? sanctioned-addresses user)))
)

(define-public (set-sanctioned (user principal) (status bool))
    (begin
        ;; Mock: only owner or admin can set this
        (map-set sanctioned-addresses user status)
        (ok true)
    )
)
