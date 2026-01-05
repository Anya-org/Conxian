;; core-protocol.clar
;; Core Protocol Traits

(define-trait protocol-manager-trait
    (
        (is-paused () (response bool uint))
        (get-admin () (response principal uint))
        (set-paused (bool) (response bool uint))
    )
)
