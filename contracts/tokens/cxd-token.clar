;; cxd-token.clar
;; CXD Governance Token - SIP-010 FT Implementation

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))

;; Data Vars
(define-data-var total-supply uint u1000000000) ;; 1 billion initial supply
(define-data-var contract-owner principal tx-sender)

;; Fungible Token
(define-fungible-token cxd-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (>= (ft-get-balance cxd-token sender) amount) ERR_INSUFFICIENT_BALANCE)
    (try! (ft-transfer? cxd-token amount sender recipient))
    (ok true)
  )
)

;; Burn function
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    (try! (ft-burn? cxd-token amount owner))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Conxian Governance Token")
)

(define-read-only (get-symbol)
  (ok "CXD")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance cxd-token owner))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (some "https://conxian.io/metadata/cxd"))
)

;; Mint function for initial distribution
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (try! (ft-mint? cxd-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)
