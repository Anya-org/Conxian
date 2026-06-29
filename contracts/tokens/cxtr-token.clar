;; cxtr-token.clar
;; Conxian Protocol: CXTR Treasury Token
;; SIP-010 compliant treasury representation token.

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxtr-token)

;; @desc Standard SIP-010 transfer function.
;; @param amount: Quantity of tokens to transfer.
;; @param sender: Sender principal.
;; @param recipient: Recipient principal.
;; @param memo: Optional 34-byte memo.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1))
    (ft-transfer? cxtr-token amount sender recipient)
  )
)

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "Conxian Treasury Token"))

;; @desc Returns the token symbol.
(define-read-only (get-symbol) (ok "CXTR"))

;; @desc Returns the number of decimals used by the token.
(define-read-only (get-decimals) (ok u8))

;; @desc Returns the token balance of a specific principal.
;; @param user: The principal to query.
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxtr-token user)))

;; @desc Returns the total supply of the token.
(define-read-only (get-total-supply) (ok (ft-get-supply cxtr-token)))

;; @desc Returns the token URI containing metadata.
(define-read-only (get-token-uri) (ok none))

;; @desc Mints new CXTR tokens. Authorized minters only.
;; @param amount: Quantity to mint.
;; @param recipient: Principal receiving the tokens.
(define-public (mint (amount uint) (recipient principal))
  (ft-mint? cxtr-token amount recipient)
)

;; @desc Burns CXTR tokens from a specific owner.
;; @param amount: Quantity to burn.
;; @param owner: Principal whose tokens are being burned.
(define-public (burn (amount uint) (owner principal))
  (ft-burn? cxtr-token amount owner)
)
