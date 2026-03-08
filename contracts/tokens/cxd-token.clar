;; cxd-token.clar
;; Standard SIP-010 Fungible Token for Conxian Dollar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxd)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ALREADY_MINTER (err u1001))
(define-constant ERR_NOT_MINTER (err u1002))

;; Admin and authorized minters
(define-data-var admin principal tx-sender)
(define-map authorized-minters principal bool)

;; @desc Check if caller is admin or authorized minter
(define-private (is-authorized-minter)
  (or
    (is-eq tx-sender (var-get admin))
    (default-to false (map-get? authorized-minters tx-sender))
  )
)

;; @desc Mint new tokens - requires admin or authorized minter
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized-minter) ERR_UNAUTHORIZED)
    (ft-mint? cxd amount recipient)
  )
)

;; @desc Add authorized minter (admin only)
(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (not (default-to false (map-get? authorized-minters minter))) ERR_ALREADY_MINTER)
    (map-set authorized-minters minter true)
    (print {
      event: "minter-added",
      minter: minter,
      admin: tx-sender
    })
    (ok true)
  )
)

;; @desc Remove authorized minter (admin only)
(define-public (remove-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? authorized-minters minter)) ERR_NOT_MINTER)
    (map-delete authorized-minters minter)
    (print {
      event: "minter-removed",
      minter: minter,
      admin: tx-sender
    })
    (ok true)
  )
)

;; @desc Check if address is authorized minter
(define-read-only (is-minter (account principal))
  (ok (default-to false (map-get? authorized-minters account)))
)

;; @desc Transfer tokens.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (match (ft-transfer? cxd amount sender recipient)
      res (begin
            (match memo m (begin (print m) true) true)
            (ok true))
      err-val (err err-val)
    )
  )
)

(define-read-only (get-name) (ok "Conxian Dollar"))
(define-read-only (get-symbol) (ok "CXD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxd w)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxd)))
(define-read-only (get-token-uri) (ok none))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
