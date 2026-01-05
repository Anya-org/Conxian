;; automation-traits.clar
;; Traits for Automation Systems (Keepers, etc.)

(define-trait keeper-trait
    (
        (check-upkeep () (response bool uint))
        (perform-upkeep ((buff 2048)) (response bool uint))
    )
)

(define-trait executable-trait
    (
        (execute () (response bool uint))
    )
)
