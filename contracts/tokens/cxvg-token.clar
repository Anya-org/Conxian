;; @contract cxvg-token
;; @desc Conxian Vanguard Governance Token (SIP-010)
;; @version 1.1.0

(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.ft-mintable-trait)

(define-fungible-token cxvg-token)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var admin principal tx-sender)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (ft-transfer? cxvg-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian Vanguard               "))
(define-read-only (get-symbol) (ok "CXVG                            "))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance cxvg-token who)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxvg-token)))
(define-read-only (get-token-uri) (ok none))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) ERR_UNAUTHORIZED)
    (ft-mint? cxvg-token amount recipient)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    (ft-burn? cxvg-token amount owner)
  )
)

(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.1.0" }))
(define-public (initialize (a principal)) (begin (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED) (ok (var-set admin a))))
