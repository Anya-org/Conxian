;; enterprise-revenue-trait.clar
;; Canonical gross-STX revenue adapter interface.

(define-trait enterprise-revenue-trait
  (
    (route-stx-revenue
      (uint principal uint)
      (response bool uint))
  )
)
