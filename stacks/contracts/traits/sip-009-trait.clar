;; SIP-009 Non-Fungible Token Trait (minimal)
(define-trait sip-009-trait
  (
    ;; Transfer token-id from sender to recipient
    (transfer (uint principal principal) (response bool uint))
    ;; Get balance of NFTs owned by principal
    (get-balance (principal) (response uint uint))
    ;; Get owner of a given token-id
    (get-owner (uint) (response (optional principal) uint))
    ;; Optional metadata functions (kept minimal for type usage)
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
  )
)
