;; controller-traits.clar
;; Traits for Protocol Controllers

(define-trait controller-trait
    (
        (is-active () (response bool uint))
        (set-active (bool) (response bool uint))
        (get-controller-type () (response (string-ascii 32) uint))
    )
)
