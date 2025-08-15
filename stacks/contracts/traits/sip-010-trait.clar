(define-trait sip-010-trait
  (
    ;; transfer amount to recipient
    (transfer (principal uint) (response bool uint))
    ;; transfer amount from sender on behalf of spender
    (transfer-from (principal principal uint) (response bool uint))
    ;; allowance query (optional)
    (get-allowance (principal principal) (response uint uint))
    ;; metadata
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    ;; supply and balances
    (get-total-supply () (response uint uint))
    (get-balance-of (principal) (response uint uint))
  )
)
