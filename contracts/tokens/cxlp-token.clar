;; cxlp-token.clar
;; SIP-010 Liquid Provider Token

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxlp)

;; @desc Transfer tokens.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1000))
    (try! (ft-transfer? cxlp amount sender recipient))
    (ok true)
  )
)

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "Conxian LP Token"))

;; @desc Returns the ticker symbol of the token.
(define-read-only (get-symbol) (ok "CXLP"))

;; @desc Returns the number of decimal places for the token.
(define-read-only (get-decimals) (ok u8))

;; @desc Returns the token balance of a specific principal.
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxlp w)))

;; @desc Returns the total circulating supply of the token.
(define-read-only (get-total-supply) (ok (ft-get-supply cxlp)))

;; @desc Returns an optional URI for the token's metadata.
(define-read-only (get-token-uri) (ok none))
