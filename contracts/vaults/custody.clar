;; custody.clar
;; Conxian Enterprise: Asset Custody
;; Manages secure storage and authorized movement of protocol assets.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u8000)

;; State
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map authorized-managers principal bool)

;; Authorization
(define-private (is-admin) (is-eq tx-sender (var-get admin)))
(define-private (is-manager (m principal)) (default-to false (map-get? authorized-managers m)))

;; Public Functions

(define-public (add-manager (m principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-set authorized-managers m true)
    (ok true)
  )
)

(define-public (remove-manager (m principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-delete authorized-managers m)
    (ok true)
  )
)

;; @desc Move assets to a vault or recipient
(define-public (transfer-to-vault (token <sip-010-trait>) (amount uint) (vault principal))
  (begin
    (asserts! (or (is-admin) (is-manager tx-sender)) (err ERR_UNAUTHORIZED))
    (as-contract (contract-call? token transfer amount tx-sender vault none))
  )
)

;; @desc Emergency withdrawal by admin
(define-public (emergency-withdraw (token <sip-010-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)
