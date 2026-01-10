;; File: contracts/traits/oracle-trait.clar
;; Centralized oracle trait for Conxian Protocol

(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
    (fetch-price (principal) (response uint uint))
    (get-name () (response (string-ascii 32) uint))
  )
)
