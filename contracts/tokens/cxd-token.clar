;; cxd-token.clar
;; Standard SIP-010 Fungible Token for Conxian Dollar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)
;; Upgraded for BME (Burn-Mint Equilibrium)

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxd)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ALREADY_MINTER (err u1001))
(define-constant ERR_NOT_MINTER (err u1002))
(define-constant ERR_MAX_SUPPLY_REACHED (err u1003))

(define-constant MAX_SUPPLY u100000000000000000) ;; 1 Billion CXD (8 decimals)

;; Admin and authorized minters/burners
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map authorized-minters principal bool)
(define-map authorized-burners principal bool)

;; @desc Check if caller is admin or authorized minter
(define-private (is-authorized-minter)
  (or
    (is-eq tx-sender (var-get admin))
    (default-to false (map-get? authorized-minters tx-sender))
  )
)

;; @desc Check if caller is authorized burner
(define-private (is-authorized-burner)
  (or
    (is-eq tx-sender (var-get admin))
    (default-to false (map-get? authorized-burners tx-sender))
  )
)

;; @desc Mint new tokens - requires admin or authorized minter
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized-minter) ERR_UNAUTHORIZED)
    (asserts! (<= (+ (ft-get-supply cxd) amount) MAX_SUPPLY) ERR_MAX_SUPPLY_REACHED)
    (ft-mint? cxd amount recipient)
  )
)

;; @desc Burn tokens - requires authorized burner
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-authorized-burner) ERR_UNAUTHORIZED)
    (ft-burn? cxd amount owner)
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

;; @desc Add authorized burner (admin only)
(define-public (add-burner (burner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-burners burner true)
    (print {
      event: "burner-added",
      burner: burner,
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
