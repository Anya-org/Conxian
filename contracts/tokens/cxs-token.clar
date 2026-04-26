(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token token)
(define-public (transfer (a uint) (s principal) (r principal) (m (optional (buff 34)))) (ok true))
(define-read-only (get-name) (ok "Token Name                     ")) ;; 32 chars
(define-read-only (get-symbol) (ok "TKN                            ")) ;; 32 chars
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (u principal)) (ok u0))
(define-read-only (get-total-supply) (ok u0))
(define-read-only (get-token-uri) (ok none))
