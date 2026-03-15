;; bond-token.clar
;; Bond Token - SIP-010 FT Implementation
;; Optimized for Conxian Protocol

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; State
(define-data-var contract-owner principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-fungible-token bond-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (try! (ft-transfer? bond-token amount sender recipient))
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian Bond Token"))
(define-read-only (get-symbol) (ok "CXBD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (owner principal)) (ok (ft-get-balance bond-token owner)))
(define-read-only (get-total-supply) (ok (ft-get-supply bond-token)))
(define-read-only (get-token-uri) (ok none))

;; Minting/Burning (Authorized)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ft-mint? bond-token amount recipient)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (ft-burn? bond-token amount owner)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
