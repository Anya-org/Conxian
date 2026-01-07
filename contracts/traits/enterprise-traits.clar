;; enterprise-traits.clar
;; Trait definitions for Conxian Enterprise features

(define-trait kyc-registry-trait (
  (get-kyc-tier
    (principal)
    (response uint uint)
  )
  (is-whitelisted
    (principal)
    (response bool uint)
  )
))
