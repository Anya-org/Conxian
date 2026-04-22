;; risk-manager.clar
;; Unified Risk Management Hub for Conxian Protocol
;; Consolidates liquidation logic, position health scores, and system risk signals.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(impl-trait .core-traits.risk-manager-trait)
(impl-trait .core-traits.risk-unit-trait)

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_INVALID_POSITION (err u1001))
(define-constant ERR_HEALTHY_POSITION (err u1002))

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var dimensional-engine-contract (optional principal) none)
(define-data-var ops-engine-contract (optional principal) none)
(define-data-var system-risk-score uint u0)
(define-data-var risk-agent-contract (optional principal) none)

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
(define-private (calculate-health-factor (collateral-value uint) (maintenance-margin uint))
  (if (is-eq maintenance-margin u0)
    u100000 ;; Infinite health
    (/ (* collateral-value u10000) maintenance-margin)
  )
)

;; Optimized Public Functions

;; @desc Update system risk (signal from agent-risk)
;; @returns (response bool uint)
(define-public (update-system-risk (new-score uint))
  (begin
    (asserts! (or (is-eq (some contract-caller) (var-get risk-agent-contract)) (is-authorized-admin)) ERR_NOT_AUTHORIZED)
    (var-set system-risk-score new-score)
    (ok true)
  )
)

;; @desc Get and refresh health factor for a specific position
;; @returns (response uint uint)
(define-public (get-health-factor (position-id uint))
  (let (
    (owner-res (contract-call? .position-nft get-owner position-id))
    (owner (unwrap! (unwrap! owner-res ERR_INVALID_POSITION) ERR_INVALID_POSITION))
    (pos-res (contract-call? .dimensional-core get-position owner position-id))
    (position (unwrap! pos-res ERR_INVALID_POSITION))
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
    (owner-res (contract-call? .position-nft get-owner position-id))
    (owner (unwrap! (unwrap! owner-res ERR_INVALID_POSITION) ERR_INVALID_POSITION))
    (hf (unwrap! (get-health-factor position-id) ERR_INVALID_POSITION))
    (current-risk (var-get system-risk-score))
    ;; Predictive Threshold: If system risk is high (> 5000), trigger earlier (110% vs 100%)
    (adjusted-threshold (if (>= current-risk u5000) u11000 u10000))
  )
    (begin
      (asserts! (or
        (is-eq (some tx-sender) (var-get dimensional-engine-contract))
        (is-eq (some contract-caller) (var-get risk-agent-contract))
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

(define-public (is-liquidatable (position-id uint))
  (let (
    (hf (match (map-get? position-health position-id)
          data (get health-factor data)
          u20000)) ;; Safe default if not cached
    (current-risk (var-get system-risk-score))
    (threshold (if (>= current-risk u5000) u11000 u10000))
  )
    (ok (< hf threshold))
  )
)

;; Admin & Mapping Functions

(define-public (initialize (owner-addr principal) (agent principal) (engine principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) ERR_NOT_AUTHORIZED)
    (var-set contract-owner owner-addr)
    (var-set risk-agent-contract (some agent))
    (var-set dimensional-engine-contract (some engine))
    (ok true)
  )
)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set dimensional-engine-contract (some new-engine))
    (ok true)
  )
)

(define-public (set-risk-agent (new-agent principal))
  (begin
    (asserts! (is-authorized-admin) ERR_NOT_AUTHORIZED)
    (var-set risk-agent-contract (some new-agent))
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
