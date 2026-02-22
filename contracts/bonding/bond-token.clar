;; bond-token.clar
;; Bond Token - SIP-010 FT Implementation
;; Optimized for Conxian Protocol

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; Data Vars
(define-data-var total-supply uint u0)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var token-name (string-ascii 32) "Conxian Bond Token")
(define-data-var token-symbol (string-ascii 10) "CXBD")
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://conxian.io/metadata/bond"))

(define-fungible-token bond-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (try! (ft-transfer? bond-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance bond-token owner))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Minting/Burning (Authorized)
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; In a real scenario, this would be authorized by the bond-factory
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (try! (ft-mint? bond-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (try! (ft-burn? bond-token amount owner))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
