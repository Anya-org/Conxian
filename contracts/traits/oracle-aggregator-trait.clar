;; oracle-aggregator-trait.clar
;; Minimal trait for dynamic calls to the oracle aggregator

(define-trait oracle-aggregator-trait
  (
    ;; Register a new trading pair with initial oracle whitelist and min sources
    (register-pair (principal principal (list 10 principal) uint) (response bool uint))
  )
)
