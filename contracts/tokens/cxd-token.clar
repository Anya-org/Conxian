;; cxd-token.clar
;; CXD Governance Token - SIP-010 FT Implementation

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)
(define-constant ERR_MAX_SUPPLY_REACHED u1002)

;; Data Vars
(define-data-var total-supply uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var max-supply uint u100000000000000000) ;; 1 billion with 8 decimals

(define-map minters { minter: principal } { authorized: bool })

(define-fungible-token cxd-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (try! (ft-transfer? cxd-token amount sender recipient))
    (ok true)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (try! (ft-burn? cxd-token amount owner))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian Governance Token"))
(define-read-only (get-symbol) (ok "CXD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (owner principal)) (ok (ft-get-balance cxd-token owner)))
(define-read-only (get-total-supply) (ok (var-get total-supply)))
(define-read-only (get-token-uri) (ok (some u"https://conxian.io/metadata/cxd")))

;; Admin functions
(define-read-only (is-minter (minter principal))
  (default-to false (get authorized (map-get? minters { minter: minter })))
)

(define-public (add-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set minters { minter: minter } { authorized: true })
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (<= (+ (var-get total-supply) amount) (var-get max-supply)) (err ERR_MAX_SUPPLY_REACHED))
    (try! (ft-mint? cxd-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)
