;; @contract cxtr-token
;; @desc Conxian Treasury Reward Token (SIP-010)
;; @version 1.1.0

(impl-trait .sip-standards.sip-010-ft-trait)

(define-fungible-token cxtr-token)

(define-constant ERR_UNAUTHORIZED (err u1000))

;; @desc Standard SIP-010 transfer function.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (ft-transfer? cxtr-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; @desc Standard SIP-010 token name.
(define-read-only (get-name) (ok "Conxian Treasury Reward        "))
;; @desc Standard SIP-010 token symbol.
(define-read-only (get-symbol) (ok "CXTR                            "))
;; @desc Standard SIP-010 decimals.
(define-read-only (get-decimals) (ok u8))
;; @desc Standard SIP-010 balance query.
(define-read-only (get-balance (who principal)) (ok (ft-get-balance cxtr-token who)))
;; @desc Standard SIP-010 total supply query.
(define-read-only (get-total-supply) (ok (ft-get-supply cxtr-token)))
;; @desc Standard SIP-010 metadata URI.
(define-read-only (get-token-uri) (ok none))
;; @desc Returns the protocol status.
(define-read-only (get-protocol-status) (ok { compliant: true, version: "v1.1.0" }))
