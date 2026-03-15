;; cxvg-token.clar
(impl-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.ft-mintable-trait)
(define-constant ERR_NON_COMPLIANT u1001)
(define-constant ERR_UNAUTHORIZED u1002)
(define-fungible-token cxvg)

;; @desc Mints new CXVG governance tokens to a recipient.
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; In production add authorization check (e.g. only coordinator)
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (ft-mint? cxvg amount recipient)
  )
)

;; @desc Burns CXVG governance tokens from an owner.
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (ft-burn? cxvg amount owner)
  )
)

;; @desc Transfers CXVG governance tokens. Includes regulatory compliance checks.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance sender)) (err ERR_NON_COMPLIANT))
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (try! (ft-transfer? cxvg amount sender recipient))
    (ok true)
  )
)

;; @desc Returns the human-readable name of the token.
(define-read-only (get-name) (ok "CXVG Governance Token"))

;; @desc Returns the ticker symbol of the token.
(define-read-only (get-symbol) (ok "CXVG"))

;; @desc Returns the number of decimal places for the token.
(define-read-only (get-decimals) (ok u6))

;; @desc Returns the token balance of a specific principal.
(define-read-only (get-balance (w principal)) (ok (ft-get-balance cxvg w)))

;; @desc Returns the total circulating supply of the token.
(define-read-only (get-total-supply) (ok (ft-get-supply cxvg)))

;; @desc Returns an optional URI for the token's metadata.
(define-read-only (get-token-uri) (ok none))
