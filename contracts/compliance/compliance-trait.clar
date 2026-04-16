;; compliance-trait.clar
;; Standard trait for compliance-verifiable components.

(define-trait compliance-trait
  (
    ;; @desc Returns if a principal is compliant
    (is-compliant (principal) (response bool uint))
  )
)
