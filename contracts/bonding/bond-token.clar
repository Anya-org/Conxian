;; bond-token.clar
;; Bond Token - SIP-010 FT Implementation
;; Optimized for Conxian Protocol

(impl-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; --- State ---

(define-data-var contract-owner principal tx-sender)
(define-fungible-token bond-token)

;; --- SIP-010 FT Implementation ---

;; @desc Transfer tokens to a recipient
;; @param amount: The number of tokens to transfer
;; @param sender: The principal sending the tokens
;; @param recipient: The principal receiving the tokens
;; @param memo: Optional data for the transfer
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (try! (ft-transfer? bond-token amount sender recipient))
    (ok true)
  )
)

;; @desc Returns the token name
(define-read-only (get-name)
  (ok "Conxian Bond Token")
)

;; @desc Returns the token symbol
(define-read-only (get-symbol)
  (ok "CXBD")
)

;; @desc Returns the token decimals
(define-read-only (get-decimals)
  (ok u8)
)

;; @desc Returns the balance for a specific principal
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance bond-token owner))
)

;; @desc Returns the total supply of the token
(define-read-only (get-total-supply)
  (ok (ft-get-supply bond-token))
)

;; @desc Returns the token URI
(define-read-only (get-token-uri)
  (ok none)
)

;; --- Minting/Burning (Authorized) ---

;; @desc Mint new bond tokens (Authorized)
;; @param amount: The number of tokens to mint
;; @param recipient: The principal receiving the tokens
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ft-mint? bond-token amount recipient)
  )
)

;; @desc Burn bond tokens
;; @param amount: The number of tokens to burn
;; @param owner: The principal whose tokens are being burned
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (ft-burn? bond-token amount owner)
  )
)

;; @desc Update the contract owner
;; @param new-owner: The new administrator principal
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
