;; security-monitoring.clar
;; Security and monitoring traits

(define-trait circuit-breaker-trait
    (
        (is-contract-paused (principal) (response bool uint))
        (set-contract-paused (principal bool) (response bool uint))
    )
)

(define-trait mev-protector-trait
    (
        (is-mempool-safe () (response bool uint))
    )
)
