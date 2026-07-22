;; enterprise-plan-registry.clar
;; Owner-published, versioned enterprise plans.
;;
;; A tier identifier is the plan identity. Only the four protocol tiers are
;; accepted, and every version is immutable after publication except for the
;; explicit active-for-sale flag. Prices are configuration, not protocol
;; constants; this contract deliberately publishes no production prices.

(impl-trait .enterprise-plan-trait.enterprise-plan-trait)

(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_PLAN (err u5001))
(define-constant ERR_PLAN_EXISTS (err u5002))
(define-constant ERR_PLAN_NOT_FOUND (err u5003))
(define-constant ERR_FEATURE_EXISTS (err u5004))
(define-constant ERR_FEATURE_NOT_FOUND (err u5005))
(define-constant ERR_INVALID_TIER (err u5006))
(define-constant ERR_INVALID_KYC_TIER (err u5007))
(define-constant ERR_PLAN_ACTIVE (err u5008))

(define-constant TIER_BRONZE u1)
(define-constant TIER_SILVER u2)
(define-constant TIER_GOLD u3)
(define-constant TIER_PLATINUM u4)

(define-data-var owner principal tx-sender)

(define-map plans
  { tier-id: uint, version: uint }
  {
    tier-id: uint,
    version: uint,
    monthly-price: uint,
    annual-price: uint,
    required-kyc-tier: uint,
    active: bool
  }
)

(define-map plan-features
  { tier-id: uint, version: uint, feature-id: (string-ascii 32) }
  { enabled: bool, limit: uint }
)

;; Activation is a one-way publication boundary for feature records. The
;; active sale flag may be turned off, but a version that was ever activated
;; cannot be extended with new features afterward.
(define-map activated-plan-versions
  { tier-id: uint, version: uint }
  bool
)

(define-private (is-owner)
  (is-eq tx-sender (var-get owner))
)

(define-private (is-valid-tier (tier-id uint))
  (and (>= tier-id TIER_BRONZE) (<= tier-id TIER_PLATINUM))
)

(define-private (is-valid-kyc-tier (required-kyc-tier uint))
  (and (> required-kyc-tier u0) (<= required-kyc-tier u255))
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

;; Publication is inactive by default. Governance must explicitly activate a
;; fully configured version after prices and product terms are approved.
(define-public (publish-plan
    (tier-id uint)
    (version uint)
    (monthly-price uint)
    (annual-price uint)
    (required-kyc-tier uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (> version u0) ERR_INVALID_PLAN)
    (asserts! (is-valid-tier tier-id) ERR_INVALID_TIER)
    (asserts! (> monthly-price u0) ERR_INVALID_PLAN)
    (asserts! (> annual-price u0) ERR_INVALID_PLAN)
    (asserts! (is-valid-kyc-tier required-kyc-tier) ERR_INVALID_KYC_TIER)
    (asserts! (is-none (map-get? plans { tier-id: tier-id, version: version })) ERR_PLAN_EXISTS)
    (map-set plans { tier-id: tier-id, version: version } {
      tier-id: tier-id,
      version: version,
      monthly-price: monthly-price,
      annual-price: annual-price,
      required-kyc-tier: required-kyc-tier,
      active: false
    })
    (ok true)
  )
)

;; Features and limits are immutable per plan version. Product-specific
;; mappings stay off-chain; only generic feature identifiers are stored. A
;; feature cannot be published after the plan version has ever been active.
(define-public (publish-feature
    (tier-id uint)
    (version uint)
    (feature-id (string-ascii 32))
    (enabled bool)
    (limit uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-tier tier-id) ERR_INVALID_TIER)
    (asserts! (> version u0) ERR_INVALID_PLAN)
    (let ((plan (unwrap! (map-get? plans { tier-id: tier-id, version: version }) ERR_PLAN_NOT_FOUND)))
      (begin
        (asserts! (not (get active plan)) ERR_PLAN_ACTIVE)
        (asserts!
          (not (default-to false (map-get? activated-plan-versions {
            tier-id: tier-id,
            version: version
          })))
          ERR_PLAN_ACTIVE)
        (asserts!
          (is-none (map-get? plan-features {
            tier-id: tier-id,
            version: version,
            feature-id: feature-id
          }))
          ERR_FEATURE_EXISTS)
        (map-set plan-features {
          tier-id: tier-id,
          version: version,
          feature-id: feature-id
        } { enabled: enabled, limit: limit })
        (ok true)
      )
    )
  )
)

;; Activation is intentionally separate from publication and is the only
;; mutable field on a published plan record.
(define-public (set-plan-active (tier-id uint) (version uint) (active bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-tier tier-id) ERR_INVALID_TIER)
    (asserts! (> version u0) ERR_INVALID_PLAN)
    (let ((plan (unwrap! (map-get? plans { tier-id: tier-id, version: version }) ERR_PLAN_NOT_FOUND)))
      (begin
        (map-set plans { tier-id: tier-id, version: version } (merge plan { active: active }))
        (if active
          (map-set activated-plan-versions { tier-id: tier-id, version: version } true)
          true)
        (ok active)
      )
    )
  )
)

(define-read-only (get-owner)
  (var-get owner)
)

(define-read-only (get-plan (tier-id uint) (version uint))
  (ok (map-get? plans { tier-id: tier-id, version: version }))
)

(define-read-only (get-plan-feature
    (tier-id uint)
    (version uint)
    (feature-id (string-ascii 32)))
  (ok (map-get? plan-features {
    tier-id: tier-id,
    version: version,
    feature-id: feature-id
  }))
)

(define-read-only (is-plan-active (tier-id uint) (version uint))
  (ok (match (map-get? plans { tier-id: tier-id, version: version })
    plan (get active plan)
    false))
)
