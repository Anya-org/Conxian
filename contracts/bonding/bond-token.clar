;; Bond Token Implementation
;; SIP-010 compliant fungible token for bond system

(impl-trait .sip-standards.sip-010-ft-trait)

;; Token Configuration
(define-fungible-token bond-token)
(define-constant CONTRACT_OWNER tx-sender)

;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INVALID_RECIPIENT (err u1003))

;; Token Metadata
(define-constant TOKEN_NAME "Bond Token")
(define-constant TOKEN_SYMBOL "BOND")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI u"https://bond.protocol/metadata.json")

;; Data Variables
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://bond.protocol/metadata.json"))
(define-data-var total-supply uint u0)

;; SIP-010 Standard Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (ft-transfer? bond-token amount sender recipient))
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

(define-read-only (get-name)
    (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
    (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
    (ok TOKEN_DECIMALS)
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance bond-token account))
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Administrative Functions
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (ft-mint? bond-token amount recipient))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

(define-public (burn (amount uint) (owner principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (ft-burn? bond-token amount owner))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set token-uri new-uri)
        (ok true)
    )
)
