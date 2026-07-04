;; cxd-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)
(define-fungible-token cxd)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var admin principal tx-sender)
(define-map minters principal bool)
(define-map burners principal bool)

(define-read-only (is-minter (caller principal))
  (default-to false (map-get? minters caller))
)

(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set minters minter true)
    (ok true)
  )
)

(define-public (add-burner (burner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set burners burner true)
    (ok true)
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender from) (err u1))
    (ft-transfer? cxd amount from to)
  )
)

(define-read-only (get-name) (ok "Conxian Dollar                 "))
(define-read-only (get-symbol) (ok "CXD                             "))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance cxd user)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (ft-mint? cxd amount recipient)
  )
)

(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (default-to false (map-get? burners tx-sender))) ERR_UNAUTHORIZED)
    (ft-burn? cxd amount sender)
  )
)

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
