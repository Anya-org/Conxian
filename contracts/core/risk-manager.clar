;; risk-manager.clar
;; Assesses position health and manages liquidations
;; Gas-Optimized Core Backend Contract - Centralized Risk Logic

(impl-trait .core-traits.risk-manager-trait)
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_HEALTHY_POSITION u6000)
(define-constant ERR_INVALID_POSITION u6001)
(define-constant HEALTH_FACTOR_BASE u10000)
(define-constant LIQUIDATION_THRESHOLD u8000) ;; 0.8 threshold

;; Data Vars
(define-data-var ops-engine-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var dimensional-engine principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var system-risk-score uint u0)
(define-data-var risk-agent principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Efficient Storage - O(1) cache
(define-map position-health
  uint
  {
    health-factor: uint,
    last-update: uint,
  }
)

;; Authorization
(define-private (is-authorized-admin)
  (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1))
)

;; Gas-Free Internal Logic
(define-private (calculate-health-factor (collateral-value uint) (maintenance-margin uint))
  (if (is-eq maintenance-margin u0)
    u100000
    (/ (* collateral-value u10000) maintenance-margin)
  )
)

;; Optimized Public Functions

(define-public (update-system-risk (new-score uint))
  (begin
    (asserts! (or (is-eq contract-caller (var-get risk-agent)) (is-authorized-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set system-risk-score new-score)
    (ok true)
  )
)

(define-public (get-health-factor (position-id uint))
  (let (
    (owner (unwrap! (unwrap-panic (contract-call? .position-nft get-owner position-id)) (err ERR_INVALID_POSITION)))
    (position (unwrap! (contract-call? .dimensional-core get-position owner position-id) (err ERR_INVALID_POSITION)))
    (collateral-value (get collateral position))
    (maintenance-margin (get maintenance-margin position))
    (hf (calculate-health-factor collateral-value maintenance-margin))
  )
    (begin
      (map-set position-health position-id {
        health-factor: hf,
        last-update: burn-block-height
      })
      (ok hf)
    )
  )
)

(define-public (liquidate (position-id uint))
  (let (
    (owner (unwrap! (unwrap-panic (contract-call? .position-nft get-owner position-id)) (err ERR_INVALID_POSITION)))
    (hf (unwrap! (get-health-factor position-id) (err ERR_INVALID_POSITION)))
    (current-risk (var-get system-risk-score))
    (adjusted-threshold (if (>= current-risk u5000) u11000 u10000))
  )
    (begin
      (asserts! (or
        (is-eq tx-sender (var-get dimensional-engine))
        (is-eq contract-caller (var-get risk-agent))
        (is-eq contract-caller (var-get ops-engine-contract))
      ) (err ERR_NOT_AUTHORIZED))

      (asserts! (< hf adjusted-threshold) (err ERR_HEALTHY_POSITION))
      
      (try! (contract-call? .dimensional-core liquidate-position owner position-id .oracle-aggregator))

      (map-delete position-health position-id)

      (print {
        event: "risk-triggered-liquidation",
        position-id: position-id,
        health-factor: hf,
        system-risk: current-risk
      })
      (ok true)
    )
  )
)

(define-read-only (is-liquidatable (position-id uint))
  (let (
    (hf (match (map-get? position-health position-id)
          data (get health-factor data)
          u20000))
    (current-risk (var-get system-risk-score))
    (threshold (if (>= current-risk u5000) u11000 u10000))
  )
    (ok (< hf threshold))
  )
)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (is-authorized-admin) (err ERR_NOT_AUTHORIZED))
    (var-set dimensional-engine new-engine)
    (ok true)
  )
)

(define-public (set-risk-agent (new-agent principal))
  (begin
    (asserts! (is-authorized-admin) (err ERR_NOT_AUTHORIZED))
    (var-set risk-agent new-agent)
    (ok true)
  )
)

(define-public (set-ops-engine (new-ops principal))
  (begin
    (asserts! (is-authorized-admin) (err ERR_NOT_AUTHORIZED))
    (var-set ops-engine-contract new-ops)
    (ok true)
  )
)
