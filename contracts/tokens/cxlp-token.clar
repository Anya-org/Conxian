;; @contract cxlp-token
;; @desc Conxian Liquidity Pool Token (SIP-010)
;; @version 1.2.0

(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.ft-mintable-trait)

(define-fungible-token cxlp-token)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_SUPPLY_OVERFLOW (err u1003))
(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-data-var admin principal tx-sender)
(define-map minters principal bool)
(define-map burners principal bool)
(define-data-var token-uri (optional (string-ascii 256)) none)

;; Privileged calls use contract-caller so an authorized protocol contract can
;; invoke this token through another contract without authorizing the user's
;; originating EOA. The admin starts as the publishing principal and can be
;; rotated with initialize/set-admin.
(define-read-only (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

(define-read-only (is-minter (caller principal))
  (default-to false (map-get? minters caller))
)

(define-read-only (is-burner (caller principal))
  (default-to false (map-get? burners caller))
)

(define-read-only (is-approved-contract (caller principal))
  (and (is-minter caller) (is-burner caller))
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
;; @desc Authorized minter registration.
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-set minters minter true)
    (ok true)
  )
)

;; @desc Authorized minter revocation.
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-delete minters minter)
    (ok true)
  )
)

;; @desc Authorized burner registration.
(define-public (add-burner (burner principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-set burners burner true)
    (ok true)
  )
)

;; @desc Authorized burner revocation.
(define-public (remove-burner (burner principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-delete burners burner)
    (ok true)
  )
)

;; @desc Compatibility helper that grants both mint and burn roles.
(define-public (add-approved-contract (contract principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-set minters contract true)
    (map-set burners contract true)
    (ok true)
  )
)

;; @desc Compatibility helper that revokes both mint and burn roles.
(define-public (remove-approved-contract (contract principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (map-delete minters contract)
    (map-delete burners contract)
    (ok true)
  )
)

;; @desc Mints CXLP only when the immediate calling principal is an authorized
;; minter. The recipient is explicit so an authorized pool cannot mint to the
;; originating user by accident.
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-minter contract-caller) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (- MAX_UINT (ft-get-supply cxlp-token))) ERR_SUPPLY_OVERFLOW)
    (ft-mint? cxlp-token amount recipient)
  )
)

;; @desc Burns CXLP only when the immediate calling principal is an authorized
;; burner and the named owner has enough balance.
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-burner contract-caller) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance cxlp-token owner) amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= (ft-get-supply cxlp-token) amount) ERR_INSUFFICIENT_BALANCE)
    (ft-burn? cxlp-token amount owner)
  )
)

;; @desc Rotates the administrator. The current administrator is the only
;; principal that can perform this operation, including when it is a contract.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Explicit administrator alias retained for integrations that use the
;; conventional set-admin name.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Returns the protocol status.
(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.2.0" }))
