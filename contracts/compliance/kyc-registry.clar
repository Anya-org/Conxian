;; kyc-registry.clar
;; Repaired KYC Registry

(define-map user-kyc principal { tier: uint, sanctioned: bool })
(define-data-var contract-owner principal tx-sender)

(define-public (set-identity-status (user principal) (tier uint) (sanctioned bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1000))
    (map-set user-kyc user { tier: tier, sanctioned: sanctioned })
    (ok true)
  )
)

(define-read-only (get-kyc-tier (user principal))
  (ok (default-to u0 (get tier (map-get? user-kyc user))))
)

(define-read-only (is-sanctioned (user principal))
  (default-to false (get sanctioned (map-get? user-kyc user)))
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1000))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
