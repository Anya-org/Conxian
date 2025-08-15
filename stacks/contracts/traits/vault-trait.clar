;; vault-trait.clar
;; Standardized vault interface for interoperability (ERC-4626-inspired)

(define-trait vault-trait
  (
    ;; Core flows
    ;; Deposit tokens from `user` into the vault; credits tx-sender per implementation
    (deposit (user principal) (amount uint) (response uint uint))
    ;; Withdraw tokens to `user` from the vault; debits tx-sender per implementation
    (withdraw (user principal) (amount uint) (response uint uint))

    ;; Views
    (get-balance (user principal) (response uint uint))
    (get-total-assets () (response uint uint))
    (preview-deposit (amount uint) (response uint uint))
    (preview-withdraw (amount uint) (response uint uint))

    ;; Metadata / config
    (get-token () (response principal uint))
    (paused () (response bool uint))
  )
)
