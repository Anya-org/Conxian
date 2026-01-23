;; ownership-trait.clar
;; Standard Ownership Trait

(define-trait ownership-trait
    (
        (get-owner () (response principal uint))
        (set-owner (principal) (response bool uint))
    )
)
