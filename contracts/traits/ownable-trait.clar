;; ownable-trait.clar
;; Standardized ownership management trait

(define-trait ownable-trait
  (
    ;; Get current owner
    (get-owner () (response principal uint))
    
    ;; Transfer ownership
    (transfer-ownership (principal) (response bool uint))
    
    ;; Renounce ownership
    (renounce-ownership () (response bool uint))
  )
)
