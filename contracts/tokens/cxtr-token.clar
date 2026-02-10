;; cxtr-token.clar
;; CXTR Treasury Token - SIP-010 FT Implementation

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; Data Vars
(define-data-var total-supply uint u0)
(define-data-var contract-owner principal tx-sender)

;; Fungible Token
(define-fungible-token cxtr-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (>= (ft-get-balance cxtr-token sender) amount) (err ERR_INSUFFICIENT_BALANCE))
    (try! (ft-transfer? cxtr-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Conxian Treasury Token")
)

(define-read-only (get-symbol)
  (ok "CXTR")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance cxtr-token owner))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (some u"https://conxian.io/metadata/cxtr"))
)

;; Mint function
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (try! (ft-mint? cxtr-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

;; Burn function
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (try! (ft-burn? cxtr-token amount owner))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)
