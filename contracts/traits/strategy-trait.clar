;; Strategy trait definition for Conxian
(define-trait auto-strategy-trait
  (
    (deposit (uint) (response uint uint))       ;; returns shares or received amount
    (withdraw (uint) (response uint uint))      ;; returns underlying withdrawn
    (harvest () (response uint uint))           ;; returns harvested amount
    (get-tvl () (response uint uint))
  )
)
