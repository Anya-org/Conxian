;; oracle.clar
;; Oracle Stub

(impl-trait .oracle-pricing.oracle-trait)

(define-read-only (get-price (asset principal))
  (ok u0))

(define-read-only (get-name)
  (ok "stub-oracle")
)