;; mock-regulatory-adapter.clar
;; Deterministic compliance trait double for governance error-path tests.

(impl-trait .core-traits.regulatory-adapter-trait)

(define-data-var mode uint u0)

;; mode u0: compliant, u1: adapter error, u2: negative compliance.
(define-public (set-mode (new-mode uint))
  (begin
    (var-set mode new-mode)
    (ok true)
  )
)

(define-public (check-clean-hands-compliance (user principal))
  (if (is-eq (var-get mode) u1)
    (err u6001)
    (if (is-eq (var-get mode) u2)
      (ok false)
      (ok true)
    )
  )
)
