;; @contract cxlp-token
;; @desc Conxian Liquidity Pool Token (SIP-010)
;; @version 1.1.0

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxlp-token)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var token-uri (optional (string-ascii 256)) none)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (ft-transfer? cxlp-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian LP Token               "))
(define-read-only (get-symbol) (ok "CXLP                            "))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance cxlp-token who)))
(define-read-only (get-total-supply) (ok (ft-get-supply cxlp-token)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))
(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.1.0" }))
