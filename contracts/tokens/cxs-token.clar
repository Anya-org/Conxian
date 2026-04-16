;; cxs-token.clar
;; SIP-010 Staking Token

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxs)

;; @desc Transfer tokens.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1000))
    (try! (ft-transfer? cxs amount sender recipient))
    (ok true)
  )
)

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "Conxian Staking Token"))

;; @desc Returns the ticker symbol of the token.
(define-read-only (get-symbol) (ok "CXS"))

;; @desc Returns the number of decimal places for the token.
(define-read-only (get-decimals) (ok u8))

;; @desc Returns the token balance of a specific principal.
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxs w)))

;; @desc Returns the total circulating supply of the token.
(define-read-only (get-total-supply) (ok (ft-get-supply cxs)))

;; @desc Returns an optional URI for the token's metadata.
(define-read-only (get-token-uri) (ok none))
