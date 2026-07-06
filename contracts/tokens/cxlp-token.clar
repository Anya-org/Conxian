;; @contract cxlp-token
;; @desc Conxian Liquidity Pool Token (SIP-010)
;; @version 1.1.0

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxlp-token)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var token-uri (optional (string-ascii 256)) none)

;; @desc Standard SIP-010 transfer function.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (ft-transfer? cxlp-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; @desc Standard SIP-010 token name.
(define-read-only (get-name) (ok "Conxian LP Token               "))
;; @desc Standard SIP-010 token symbol.
(define-read-only (get-symbol) (ok "CXLP                            "))
;; @desc Standard SIP-010 decimals.
(define-read-only (get-decimals) (ok u8))
;; @desc Standard SIP-010 balance query.
(define-read-only (get-balance (who principal)) (ok (ft-get-balance cxlp-token who)))
;; @desc Standard SIP-010 total supply query.
(define-read-only (get-total-supply) (ok (ft-get-supply cxlp-token)))
;; @desc Standard SIP-010 metadata URI.
(define-read-only (get-token-uri) (ok (var-get token-uri)))
;; @desc Returns the protocol status.
(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.1.0" }))
