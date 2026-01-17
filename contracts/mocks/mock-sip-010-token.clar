;; Mock SIP-010 Token
(define-trait sip-010-trait
  ((transfer (uint principal principal) (response bool uint))))

(define-fungible-token mock-token)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (ok true)
)
