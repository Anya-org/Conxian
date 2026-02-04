;; mock-token.clar
;; A simple mock SIP-010 token for testing

(define-fungible-token mock-token)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; SIP-010 FT Trait
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (>= (ft-get-balance mock-token sender) amount) (err ERR_INSUFFICIENT_BALANCE))
    (try! (ft-transfer? mock-token amount sender recipient))
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Mock Token")
)

(define-read-only (get-symbol)
  (ok "MOCK")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance mock-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply mock-token))
)

(define-read-only (get-token-uri)
  (ok none)
)

;; Mint function for testing
(define-public (mint (amount uint) (recipient principal))
  (begin
    (ft-mint? mock-token amount recipient)
  )
)

;; Burn function for testing
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (ft-burn? mock-token amount owner)
  )
)
