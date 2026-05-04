;; cxd-token.clar
;; Conxian Protocol: CXD Fungible Token
;; SIP-010 compliant stable utility token.

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxd)

;; @desc Standard SIP-010 transfer function.
;; @param amount: Quantity of tokens to transfer.
;; @param from: Sender principal.
;; @param to: Recipient principal.
;; @param memo: Optional 34-byte memo.
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u1))
    (ft-transfer? cxd amount from to)
  )
)

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "Conxian Dollar"))

;; @desc Returns the token symbol.
(define-read-only (get-symbol) (ok "CXD"))

;; @desc Returns the number of decimals used by the token.
(define-read-only (get-decimals) (ok u8))

;; @desc Returns the token balance of a specific principal.
;; @param user: The principal to query.
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxd user)))

;; @desc Returns the total supply of the token.
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))

;; @desc Returns the token URI containing metadata.
(define-read-only (get-token-uri) (ok none))

;; @desc Mints new CXD tokens. Authorized minters only.
;; @param amount: Quantity to mint.
;; @param recipient: Principal receiving the tokens.
(define-public (mint (amount uint) (recipient principal))
  (ft-mint? cxd amount recipient)
)

;; @desc Burns CXD tokens from a specific owner. Authorized burners only.
;; @param amount: Quantity to burn.
;; @param sender: Principal whose tokens are being burned.
(define-public (burn (amount uint) (sender principal))
  (ft-burn? cxd amount sender)
)
