;; @contract token-system-coordinator
;; @desc Coordinator for token system operations including minting and burning.
;; @version 1.1.0

(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)

(define-constant ERR_NON_COMPLIANT (err u1002))

;; @desc Mints CXD tokens to a recipient after regulatory check.
(define-public (mint-cxd (token <ft-mintable-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) ERR_NON_COMPLIANT)
    (contract-call? token mint amount recipient)
  )
)

;; @desc Mints CXVG tokens to a recipient after regulatory check.
(define-public (mint-cxvg (token <ft-mintable-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) ERR_NON_COMPLIANT)
    (contract-call? token mint amount recipient)
  )
)

;; @desc Burns CXD tokens from an owner.
(define-public (burn-cxd (token <ft-mintable-trait>) (amount uint) (owner principal))
  (contract-call? token burn amount owner)
)

;; @desc Burns CXVG tokens from an owner.
(define-public (burn-cxvg (token <ft-mintable-trait>) (amount uint) (owner principal))
  (contract-call? token burn amount owner)
)
