;; =============================================================================
;; FEE TIER MANAGER - Phase 3 Enhanced Fee Management
;; Implements multi-tier fee system with dynamic adjustments and governance
;; Supports 0.05%, 0.3%, 1%, 3%, 5% fee tiers with volume-based optimization
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Error codes (u6100+ reserved for fee tier manager)
(define-constant ERR_UNAUTHORIZED (err u6100))
(define-constant ERR_INVALID_FEE_TIER (err u6101))
(define-constant ERR_INVALID_POOL (err u6102))
(define-constant ERR_FEE_TOO_HIGH (err u6103))
(define-constant ERR_INVALID_PARAMETERS (err u6104))
(define-constant ERR_TIER_NOT_FOUND (err u6105))
(define-constant ERR_POOL_NOT_REGISTERED (err u6106))

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision
(define-constant MAX_FEE_BPS u1000) ;; 10% maximum fee
(define-constant MIN_FEE_BPS u1) ;; 0.01% minimum fee

;; Fee tier constants (in basis points)
(define-constant FEE_TIER_005 u5)    ;; 0.05%
(define-constant FEE_TIER_03 u30)    ;; 0.3%
(define-constant FEE_TIER_1 u100)    ;; 1%
(define-constant FEE_TIER_3 u300)    ;; 3%
(define-constant FEE_TIER_5 u500)    ;; 5%

;; Volume thresholds for tier eligibility
(define-constant VOLUME_TIER_1 u1000000)    ;; 1M for 0.3%
(define-constant VOLUME_TIER_2 u10000000)   ;; 10M for 0.05%
(define-constant VOLUME_TIER_3 u100000000)  ;; 100M for premium features

;; Data variables
(define-data-var protocol-fee-bps uint u30) ;; Default 0.3%
(define-data-var governance-fee-bps uint u10) ;; Governance fee
(define-data-var fee-collector principal tx-sender)
(define-data-var total-pools uint u0)

;; Pool fee tier registry
(define-map pool-fee-tiers
  { pool: principal }
  {
    fee-tier: uint,
    volume-24h: uint,
    last-updated: uint,
    tier-locked: bool
  }
)

;; Fee tier definitions
(define-map fee-tier-config
  { tier-id: uint }
  {
    fee-bps: uint,
    min-volume: uint,
    max-volume: uint,
    active: bool,
    description: (string-ascii 50)
  }
)

;; User volume tracking for tier eligibility
(define-map user-volume-stats
  { user: principal }
  {
    volume-24h: uint,
    volume-7d: uint,
    volume-30d: uint,
    last-trade: uint,
    tier-eligible: uint
  }
)

;; Protocol revenue tracking
(define-map revenue-stats
  { period: uint }
  {
    total-fees: uint,
    governance-fees: uint,
    protocol-fees: uint,
    pools-active: uint
  }
)

;; Admin functions
(define-public (set-fee-collector (new-collector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set fee-collector new-collector)
    (ok true)
  )
)

(define-public (set-protocol-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps MAX_FEE_BPS) ERR_FEE_TOO_HIGH)
    (asserts! (>= new-fee-bps MIN_FEE_BPS) ERR_INVALID_PARAMETERS)
    (var-set protocol-fee-bps new-fee-bps)
    (ok true)
  )
)

;; Fee tier management
(define-public (register-pool (pool principal) (initial-tier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-fee-tier initial-tier) ERR_INVALID_FEE_TIER)
    
    (map-set pool-fee-tiers
      { pool: pool }
      {
        fee-tier: initial-tier,
        volume-24h: u0,
        last-updated: block-height,
        tier-locked: false
      }
    )
    (var-set total-pools (+ (var-get total-pools) u1))
    (ok true)
  )
)

(define-public (update-pool-tier (pool principal) (new-tier uint))
  (let ((pool-info (unwrap! (map-get? pool-fee-tiers { pool: pool }) ERR_POOL_NOT_REGISTERED)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-fee-tier new-tier) ERR_INVALID_FEE_TIER)
    (asserts! (not (get tier-locked pool-info)) ERR_INVALID_PARAMETERS)
    
    (map-set pool-fee-tiers
      { pool: pool }
      (merge pool-info { fee-tier: new-tier, last-updated: block-height })
    )
    (ok true)
  )
)

;; Volume tracking and tier updates
(define-public (update-volume-stats (user principal) (pool principal) (volume uint))
  (let (
    (current-stats (default-to 
      { volume-24h: u0, volume-7d: u0, volume-30d: u0, last-trade: u0, tier-eligible: FEE_TIER_1 }
      (map-get? user-volume-stats { user: user })
    ))
    (pool-info (unwrap! (map-get? pool-fee-tiers { pool: pool }) ERR_POOL_NOT_REGISTERED))
  )
    ;; Update user volume stats
    (map-set user-volume-stats
      { user: user }
      {
        volume-24h: (+ (get volume-24h current-stats) volume),
        volume-7d: (+ (get volume-7d current-stats) volume),
        volume-30d: (+ (get volume-30d current-stats) volume),
        last-trade: block-height,
        tier-eligible: (calculate-tier-eligibility (+ (get volume-24h current-stats) volume))
      }
    )
    
    ;; Update pool volume stats
    (map-set pool-fee-tiers
      { pool: pool }
      (merge pool-info { 
        volume-24h: (+ (get volume-24h pool-info) volume),
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Fee calculation functions
(define-public (calculate-fee (pool principal) (amount uint) (user principal))
  (let (
    (pool-info (unwrap! (map-get? pool-fee-tiers { pool: pool }) ERR_POOL_NOT_REGISTERED))
    (user-stats (map-get? user-volume-stats { user: user }))
    (base-fee-bps (get fee-tier pool-info))
    (user-tier (match user-stats
      some-stats (get tier-eligible some-stats)
      FEE_TIER_1
    ))
  )
    (ok {
      total-fee: (/ (* amount (min base-fee-bps user-tier)) u10000),
      protocol-fee: (/ (* amount (var-get protocol-fee-bps)) u10000),
      governance-fee: (/ (* amount (var-get governance-fee-bps)) u10000)
    })
  )
)

;; Helper functions
(define-private (is-valid-fee-tier (tier uint))
  (or 
    (is-eq tier FEE_TIER_005)
    (is-eq tier FEE_TIER_03)
    (is-eq tier FEE_TIER_1)
    (is-eq tier FEE_TIER_3)
    (is-eq tier FEE_TIER_5)
  )
)

(define-private (calculate-tier-eligibility (volume uint))
  (if (>= volume VOLUME_TIER_3)
    FEE_TIER_005
    (if (>= volume VOLUME_TIER_2)
      FEE_TIER_03
      (if (>= volume VOLUME_TIER_1)
        FEE_TIER_1
        FEE_TIER_3
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-pool-fee-tier (pool principal))
  (map-get? pool-fee-tiers { pool: pool })
)

(define-read-only (get-user-volume-stats (user principal))
  (map-get? user-volume-stats { user: user })
)

(define-read-only (get-protocol-fee)
  (var-get protocol-fee-bps)
)

(define-read-only (get-governance-fee)
  (var-get governance-fee-bps)
)

(define-read-only (get-fee-collector)
  (var-get fee-collector)
)

(define-read-only (get-total-pools)
  (var-get total-pools)
)

(define-read-only (get-tier-info (tier-id uint))
  (map-get? fee-tier-config { tier-id: tier-id })
)

;; Initialize default fee tiers
(map-set fee-tier-config { tier-id: u1 } {
  fee-bps: FEE_TIER_005,
  min-volume: VOLUME_TIER_3,
  max-volume: u0,
  active: true,
  description: "Premium 0.05% tier"
})

(map-set fee-tier-config { tier-id: u2 } {
  fee-bps: FEE_TIER_03,
  min-volume: VOLUME_TIER_2,
  max-volume: VOLUME_TIER_3,
  active: true,
  description: "Standard 0.3% tier"
})

(map-set fee-tier-config { tier-id: u3 } {
  fee-bps: FEE_TIER_1,
  min-volume: VOLUME_TIER_1,
  max-volume: VOLUME_TIER_2,
  active: true,
  description: "Basic 1% tier"
})

(map-set fee-tier-config { tier-id: u4 } {
  fee-bps: FEE_TIER_3,
  min-volume: u0,
  max-volume: VOLUME_TIER_1,
  active: true,
  description: "Entry 3% tier"
})

(map-set fee-tier-config { tier-id: u5 } {
  fee-bps: FEE_TIER_5,
  min-volume: u0,
  max-volume: u0,
  active: false,
  description: "High volatility 5% tier"
})
