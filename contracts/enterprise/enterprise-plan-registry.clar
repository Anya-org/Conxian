;; enterprise-plan-registry.clar
;; Owner-published, versioned enterprise plans.
;;
;; Plan prices are deliberately configuration, not protocol constants. A plan
;; is published inactive and can only become active through the explicit
;; activation function. Once published, all plan fields and feature records
;; are immutable; activation is the only mutable plan property.

(impl-trait .enterprise-plan-trait.enterprise-plan-trait)

(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_PLAN (err u5001))
(define-constant ERR_PLAN_EXISTS (err u5002))
(define-constant ERR_PLAN_NOT_FOUND (err u5003))
(define-constant ERR_FEATURE_EXISTS (err u5004))
(define-constant ERR_FEATURE_NOT_FOUND (err u5005))
(define-constant ERR_INVALID_TIER (err u5006))
(define-constant ERR_INVALID_KYC_TIER (err u5007))

(define-constant TIER_BRONZE u1)
(define-constant TIER_SILVER u2)
(define-constant TIER_GOLD u3)
(define-constant TIER_PLATINUM u4)

(define-data-var owner principal tx-sender)

(define-map plans
  { plan-id: uint, version: uint }
  {
    plan-id: uint,
    version: uint,
    tier-id: uint,
    monthly-price: uint,
    annual-price: uint,
    required-kyc-tier: uint,
    active: bool
  }
)

(define-map plan-features
  { plan-id: uint, version: uint, feature-id: (string-ascii 32) }
  { enabled: bool, limit: uint }
)

(define-private (is-owner)
  (is-eq tx-sender (var-get owner))
)

(define-private (is-valid-tier (tier-id uint))
  (and (>= tier-id TIER_BRONZE) (<= tier-id TIER_PLATINUM))
)

(define-public (initialize (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  )
)

;; Prices are supplied by the owner and are not hardcoded by this contract.
(define-public (publish-plan
    (plan-id uint)
    (version uint)
    (tier-id uint)
    (monthly-price uint)
    (annual-price uint)
    (required-kyc-tier uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (and (> plan-id u0) (> version u0)) ERR_INVALID_PLAN)
    (asserts! (is-valid-tier tier-id) ERR_INVALID_TIER)
    (asserts! (<= required-kyc-tier u255) ERR_INVALID_KYC_TIER)
    (asserts! (is-none (map-get? plans { plan-id: plan-id, version: version })) ERR_PLAN_EXISTS)
    (map-set plans { plan-id: plan-id, version: version } {
      plan-id: plan-id,
      version: version,
      tier-id: tier-id,
      monthly-price: monthly-price,
      annual-price: annual-price,
      required-kyc-tier: required-kyc-tier,
      active: false
    })
    (ok true)
  )
)

;; Features and limits are immutable per plan version. Product-specific
;; mappings stay off-chain; only generic feature identifiers are stored.
(define-public (publish-feature
    (plan-id uint)
    (version uint)
    (feature-id (string-ascii 32))
    (enabled bool)
    (limit uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? plans { plan-id: plan-id, version: version })) ERR_PLAN_NOT_FOUND)
    (asserts!
      (is-none (map-get? plan-features {
        plan-id: plan-id,
        version: version,
        feature-id: feature-id
      }))
      ERR_FEATURE_EXISTS)
    (map-set plan-features {
      plan-id: plan-id,
      version: version,
      feature-id: feature-id
    } { enabled: enabled, limit: limit })
    (ok true)
  )
)

;; Activation is intentionally separate from publication and is the only
;; mutable field on a published plan record.
(define-public (set-plan-active (plan-id uint) (version uint) (active bool))
  (let ((plan (unwrap! (map-get? plans { plan-id: plan-id, version: version }) ERR_PLAN_NOT_FOUND)))
    (begin
      (asserts! (is-owner) ERR_UNAUTHORIZED)
      (map-set plans { plan-id: plan-id, version: version } (merge plan { active: active }))
      (ok active)
    )
  )
)

(define-read-only (get-owner)
  (var-get owner)
)

(define-read-only (get-plan (plan-id uint) (version uint))
  (ok (map-get? plans { plan-id: plan-id, version: version }))
)

(define-read-only (get-plan-feature
    (plan-id uint)
    (version uint)
    (feature-id (string-ascii 32)))
  (ok (map-get? plan-features {
      plan-id: plan-id,
      version: version,
      feature-id: feature-id
    }))
)

(define-read-only (is-plan-active (plan-id uint) (version uint))
  (ok (match (map-get? plans { plan-id: plan-id, version: version })
    plan (get active plan)
    false))
)
