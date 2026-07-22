;; enterprise-plan-trait.clar
;; Stable read interface for immutable {tier-id, version} enterprise plans.

(define-trait enterprise-plan-trait
  (
    (get-plan
      (uint uint)
      (response (optional {
        tier-id: uint,
        version: uint,
        monthly-price: uint,
        annual-price: uint,
        required-kyc-tier: uint,
        active: bool
      }) uint))
    (get-plan-feature
      (uint uint (string-ascii 32))
      (response (optional { enabled: bool, limit: uint }) uint))
    (is-plan-active
      (uint uint)
      (response bool uint))
  )
)
