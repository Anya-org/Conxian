;; @contract cxd-token
;; @desc Conxian Dollar Sovereign Debt Token (SIP-010)
;; @version 1.2.0

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxd)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))

;; --- State Variables ---
(define-data-var admin principal tx-sender)
(define-map minters principal bool)
(define-map burners principal bool)

;; --- Read-Only Functions ---

;; @desc Checks if a principal is an authorized minter.
(define-read-only (is-minter (caller principal))
  (default-to false (map-get? minters caller))
)

;; @desc Standard SIP-010 token name.
(define-read-only (get-name) (ok "Conxian Dollar                 "))

;; @desc Standard SIP-010 token symbol.
(define-read-only (get-symbol) (ok "CXD                             "))

;; @desc Standard SIP-010 decimals.
(define-read-only (get-decimals) (ok u8))

;; @desc Standard SIP-010 balance query.
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxd user)))

;; @desc Standard SIP-010 total supply query.
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))

;; @desc Standard SIP-010 metadata URI.
(define-read-only (get-token-uri) (ok none))

;; --- Public Functions ---

;; @desc Authorized minter registration.
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set minters minter true)
    (ok true)
  )
)

;; @desc Authorized burner registration.
(define-public (add-burner (burner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set burners burner true)
    (ok true)
  )
)

;; @desc Standard SIP-010 transfer function.
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u1))
    (ft-transfer? cxd amount from to)
  )
)

;; @desc Mints new CXD tokens.
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (ft-mint? cxd amount recipient)
  )
)

;; @desc Burns CXD tokens.
(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (default-to false (map-get? burners tx-sender))) ERR_UNAUTHORIZED)
    (ft-burn? cxd amount sender)
  )
)

;; @desc Initializes the contract with a new administrator.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Returns the protocol status.
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.2.0" })
)
