;; enterprise-subscription-trait.clar
;; Stable subscription entitlement and usage interface for audited consumers.
;; Payment IDs are global across the subscription route; usage replay scope is
;; period-specific in the implementation.

(define-trait enterprise-subscription-trait
  (
    (subscribe
      (uint uint uint uint uint)
      (response bool uint))
    (renew
      (uint uint uint uint uint)
      (response bool uint))
    (cancel
      ()
      (response bool uint))
    (get-subscription
      (principal)
      (response (optional {
        tier-id: uint,
        plan-version: uint,
        billing-period: uint,
        paid-from: uint,
        paid-through: uint,
        active: bool,
        cancelled: bool,
        usage-period-start: uint
      }) uint))
    (is-entitled
      (principal (string-ascii 32))
      (response bool uint))
    (get-entitlement
      (principal (string-ascii 32))
      (response (optional {
        entitled: bool,
        limit: uint,
        used: uint,
        remaining: uint,
        paid-through: uint,
        tier-id: uint,
        plan-version: uint
      }) uint))
    (record-usage
      (principal (string-ascii 32) (buff 32) uint)
      (response uint uint))
  )
)
