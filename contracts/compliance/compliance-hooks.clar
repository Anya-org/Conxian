;; compliance-hooks.clar
;; Conxian Compliance Hooks

(define-constant ERR_UNAUTHORIZED (err u7000))

(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-manager principal .compliance-manager)
(define-data-var kyc-registry principal .kyc-registry)

(define-public (verify-kyc (user principal) (kyc-level uint))
  (begin
    (try! (contract-call? .compliance-manager check-user-compliance user false kyc-level false))
    (ok true)
  )
)

(define-read-only (check-kyc (user principal))
  (let ((tier (unwrap-panic (contract-call? .kyc-registry get-kyc-tier user))))
    (if (>= tier u1)
      (ok true)
      (err u4001)
    )
  )
)

(define-read-only (check-aml (user principal))
  (let ((is-sanctioned (contract-call? .kyc-registry is-sanctioned user)))
    (if is-sanctioned
      (err u4002)
      (ok true)
    )
  )
)

(define-public (set-compliance-manager (new-manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set compliance-manager new-manager)
    (ok true)
  )
)

(define-public (set-kyc-registry (new-registry principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set kyc-registry new-registry)
    (ok true)
  )
)
