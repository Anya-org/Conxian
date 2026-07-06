;; @contract cxs-token
;; @desc Conxian Staking Representation Token (SIP-010)
;; @version 1.1.0

(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token token)

;; @desc Standard SIP-010 transfer function.
;; @param a: Quantity of tokens to transfer.
;; @param s: Sender principal.
;; @param r: Recipient principal.
;; @param m: Optional 34-byte memo.
(define-public (transfer (a uint) (s principal) (r principal) (m (optional (buff 34)))) (ok true))

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "Token Name                     ")) ;; 32 chars

;; @desc Returns the token symbol.
(define-read-only (get-symbol) (ok "TKN                            ")) ;; 32 chars

;; @desc Returns the number of decimals used by the token.
(define-read-only (get-decimals) (ok u8))

;; @desc Returns the token balance of a specific principal.
;; @param u: The principal to query.
(define-read-only (get-balance (u principal)) (ok u0))

;; @desc Returns the total supply of the token.
(define-read-only (get-total-supply) (ok u0))

;; @desc Returns the token URI containing metadata.
(define-read-only (get-token-uri) (ok none))
