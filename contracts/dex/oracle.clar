;; oracle.clar
;; Oracle Stub
(impl-trait .oracle-pricing.oracle-trait)

(define-read-only (get-price (asset principal))
  (ok u0)
)

(define-read-only (get-name)
  (ok "Conxian-Oracle")
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)
