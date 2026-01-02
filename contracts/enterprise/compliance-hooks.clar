;; compliance-hooks.clar
;; Provides compliance hooks for the Conxian DEX.

(define-constant ERR_UNAUTHORIZED (err u7000))

(define-public (check-kyc (user principal))
  (let ((kyc-tier (unwrap! (contract-call? .kyc-registry get-kyc-tier user) ERR_UNAUTHORIZED)))
    (asserts! (>= kyc-tier u1) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-public (check-aml (user principal))
  (let ((is-sanctioned (unwrap! (contract-call? .kyc-registry is-sanctioned user) ERR_UNAUTHORIZED)))
    (asserts! (not is-sanctioned) ERR_UNAUTHORIZED)
    (ok true)
  )
)
