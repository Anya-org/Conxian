;; @contract cxlp-token
;; @desc Conxian Liquidity Pool Token (SIP-010)
;; @version 1.2.0

(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.ft-mintable-trait)

(define-fungible-token cxlp-token)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_OWNER_MISMATCH (err u1002))
(define-data-var admin principal tx-sender)
(define-map minters principal bool)
(define-map burners principal bool)
(define-data-var token-uri (optional (string-ascii 256)) none)

;; @desc Checks whether a principal is the current administrator.
(define-read-only (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

;; @desc Checks if a principal is an authorized minter.
(define-read-only (is-minter (caller principal))
  (default-to false (map-get? minters caller))
)

;; @desc Checks if a principal is an authorized burner.
(define-read-only (is-burner (caller principal))
  (default-to false (map-get? burners caller))
)

;; @desc Returns the current administrator.
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; @desc Standard SIP-010 transfer function.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (ft-transfer? cxlp-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; @desc Adds an authorized minter. Admin only.
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set minters minter true)
    (ok true)
  )
)

;; @desc Removes an authorized minter. Admin only.
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-delete minters minter)
    (ok true)
  )
)

;; @desc Adds an authorized burner. Admin only.
(define-public (add-burner (burner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set burners burner true)
    (ok true)
  )
)

;; @desc Removes an authorized burner. Admin only.
(define-public (remove-burner (burner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-delete burners burner)
    (ok true)
  )
)

;; @desc Mints CXLP through the immediate caller's authorization.
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts!
      (or (is-eq contract-caller (var-get admin)) (is-minter contract-caller))
      ERR_UNAUTHORIZED
    )
    (ft-mint? cxlp-token amount recipient)
  )
)

;; @desc Burns CXLP through an authorized immediate caller.
;; Non-admin callers must initiate burns for their own balance. This keeps an
;; approved pool from burning a different user's CXLP when invoked by that user.
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts!
      (or (is-eq contract-caller (var-get admin)) (is-burner contract-caller))
      ERR_UNAUTHORIZED
    )
    (asserts!
      (or (is-eq contract-caller (var-get admin)) (is-eq tx-sender owner))
      ERR_OWNER_MISMATCH
    )
    (ft-burn? cxlp-token amount owner)
  )
)

;; @desc Standard SIP-010 token name.
(define-read-only (get-name) (ok "Conxian LP Token               "))
;; @desc Standard SIP-010 token symbol.
(define-read-only (get-symbol) (ok "CXLP                            "))
;; @desc Standard SIP-010 decimals.
(define-read-only (get-decimals) (ok u8))
;; @desc Standard SIP-010 balance query.
(define-read-only (get-balance (who principal)) (ok (ft-get-balance cxlp-token who)))
;; @desc Standard SIP-010 total supply query.
(define-read-only (get-total-supply) (ok (ft-get-supply cxlp-token)))
;; @desc Standard SIP-010 metadata URI.
(define-read-only (get-token-uri) (ok (var-get token-uri)))
;; @desc Returns the protocol status.
(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.2.0" }))

;; @desc Initializes the contract with a new administrator.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
