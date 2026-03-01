;; token-system-coordinator.clar
(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)
(define-constant ERR_NON_COMPLIANT u1002)

(define-public (mint-cxd (token <ft-mintable-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (contract-call? token mint amount recipient)
  )
)

(define-public (mint-cxvg (token <ft-mintable-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance recipient)) (err ERR_NON_COMPLIANT))
    (contract-call? token mint amount recipient)
  )
)

(define-public (burn-cxd (token <ft-mintable-trait>) (amount uint) (owner principal))
  (contract-call? token burn amount owner)
)

(define-public (burn-cxvg (token <ft-mintable-trait>) (amount uint) (owner principal))
  (contract-call? token burn amount owner)
)
