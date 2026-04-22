;; risk-manager.clar
;; Unified Risk Management Hub for Conxian Protocol
;; Consolidates liquidation logic, position health scores, and system risk signals.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_INVALID_POSITION (err u1001))
(define-constant ERR_HEALTHY_POSITION (err u1002))

(define-constant LIQUIDATION_THRESHOLD u10000) ;; 100%
(define-constant EMERGENCY_THRESHOLD u11000) ;; 110%
(define-constant SYSTEM_RISK_LIMIT u5000)

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var dimensional-engine (optional principal) none)
(define-data-var ops-engine-contract (optional principal) none)
(define-data-var system-risk-score uint u0)
(define-data-var risk-agent (optional principal) none)
(define-data-var initialized bool false)

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
  (is-eq (contract-call? .conxian-access has-role tx-sender u1) (ok true)) ;; ROLE_ADMIN
)

;; Gas-Free Internal Logic
;; @desc Returns the canonical health factor formula
(define-read-only (calculate-health-factor (collateral-value uint) (total-debt uint))
  (if (is-eq total-debt u0)
    u100000 ;; Infinite health
    (/ (* collateral-value u10000) total-debt)
  )
)

;; Optimized Public Functions

;; @desc Update system risk (signal from agent-risk)
;; @returns (response bool uint)
(define-public (update-system-risk (new-score uint))
  (begin
    (asserts! (or (is-eq (some contract-caller) (var-get risk-agent)) (is-authorized-admin)) ERR_NOT_AUTHORIZED)
    (var-set system-risk-score new-score)
    (ok true)
  )
)

;; @desc Get and refresh health factor for a specific position
;; @returns (response uint uint)
(define-public (get-health-factor (position-id uint))
  (let (
    (owner (unwrap! (unwrap! (contract-call? .position-nft get-owner position-id) (err u1001)) (err u1001)))
    (pos-res (contract-call? .dimensional-core get-position owner position-id))
    (position (unwrap! pos-res (err u1001)))
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

;; @desc Read-only health factor lookup (no cache update)
(define-read-only (get-health-factor-read-only (position-id uint))
  (let (
    (cached (map-get? position-health position-id))
  )
    (match cached
      data (ok (get health-factor data))
      (err u1001)
    )
  )
)

;; @desc Execute liquidation trigger
;; @returns (response bool uint)
(define-public (liquidate (position-id uint))
  (let (
    (owner (unwrap! (unwrap! (contract-call? .position-nft get-owner position-id) (err u1001)) (err u1001)))
    (hf (unwrap! (get-health-factor position-id) (err u1001)))
    (current-risk (var-get system-risk-score))
    ;; Predictive Threshold: If system risk is high, trigger earlier
    (adjusted-threshold (if (>= current-risk SYSTEM_RISK_LIMIT) EMERGENCY_THRESHOLD LIQUIDATION_THRESHOLD))
  )
    (begin
      (asserts! (or
        (is-eq (some contract-caller) (var-get dimensional-engine))
        (is-eq (some contract-caller) (var-get risk-agent))
        (is-eq (some contract-caller) (var-get ops-engine-contract))
        (is-authorized-admin)
      ) ERR_NOT_AUTHORIZED)

      (asserts! (< hf adjusted-threshold) ERR_HEALTHY_POSITION)
      
      (try! (contract-call? .dimensional-core liquidate-position owner position-id .oracle-aggregator))

      (map-delete position-health position-id)

      (print {
        event: "risk-triggered-liquidation",
        position-id: position-id,
        health-factor: hf,
        system-risk: current-risk,
        threshold: adjusted-threshold
      })
      (ok true)
    )
  )
)

(define-read-only (is-liquidatable (position-id uint))
  (let (
    (hf (match (map-get? position-health position-id)
          data (get health-factor data)
          u20000)) ;; Safe default if not cached
    (current-risk (var-get system-risk-score))
    (threshold (if (>= current-risk SYSTEM_RISK_LIMIT) EMERGENCY_THRESHOLD LIQUIDATION_THRESHOLD))
  )
    (ok (< hf threshold))
  )
)

;; Admin & Mapping Functions

(define-public (initialize (owner principal) (agent principal) (engine principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_NOT_AUTHORIZED)
    (var-set contract-owner owner)
    (var-set risk-agent (some agent))
    (var-set dimensional-engine (some engine))
    (var-set initialized true)
    (ok true)
  )
)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set dimensional-engine (some new-engine))
    (ok true)
  )
)

(define-public (set-risk-agent (new-agent principal))
  (begin
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set risk-agent (some new-agent))
    (ok true)
  )
)

(define-public (set-ops-engine (new-ops principal))
  (begin
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set ops-engine-contract (some new-ops))
    (ok true)
  )
)
