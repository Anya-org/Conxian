;; vault-trait.clar
;; Standardized vault interface for interoperability (ERC-4626-inspired)

(define-trait vault-trait
  (
    ;; Core flows (argument names omitted per trait syntax requirements)
    (deposit (principal uint) (response uint uint))
    (withdraw (principal uint) (response uint uint))
    ;; Views
    (get-balance (principal) (response uint uint))
    (get-total-assets () (response uint uint))
    (preview-deposit (uint) (response uint uint))
    (preview-withdraw (uint) (response uint uint))
    ;; Metadata / config
    (get-token () (response principal uint))
    (paused () (response bool uint))
  )
)
