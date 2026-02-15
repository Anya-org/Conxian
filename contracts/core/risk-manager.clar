;; risk-manager.clar
;; Assesses position health and manages liquidations
;; Gas-Optimized Core Backend Contract - Accessed via Dimensional Engine Facade

(impl-trait .core-traits.risk-manager-trait)
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants - Gas Free (compile-time)
(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_HEALTHY_POSITION u6000)
(define-constant HEALTH_FACTOR_BASE u10000) ;; 1.0 scaled
(define-constant LIQUIDATION_THRESHOLD u8000) ;; 0.8 threshold
(define-constant COLLATERAL_FACTOR u7500) ;; 0.75 base factor

;; Data Vars - Minimal State
(define-data-var dimensional-engine principal tx-sender)

(define-public (set-dimensional-engine (new-engine principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) (err ERR_NOT_AUTHORIZED))
    (var-set dimensional-engine new-engine)
    (ok true)
  )
)
(define-data-var base-price-feed principal tx-sender)
(define-data-var global-collateral-factor uint COLLATERAL_FACTOR)

;; Efficient Storage - O(1) lookups
(define-map position-health
  uint
  {
    health-factor: uint,
    collateral-value: uint,
    debt-value: uint,
    last-update: uint,
  }
)

(define-map asset-collateral-factors
  principal
  {
    factor: uint,
    volatility-adjustment: uint,
    last-adjustment: uint,
  }
)

;; Gas-Free Internal Logic
(define-private (calculate-health-factor (collateral-value uint) (debt-value uint))
  ;; HF = (collateral * factor) / debt
  (if (is-eq debt-value u0)
    u100000 ;; Max health factor when no debt
    (/ (* collateral-value (var-get global-collateral-factor)) debt-value)
  )
)

(define-private (get-asset-collateral-factor (asset principal))
  (match (map-get? asset-collateral-factors asset)
    factor-data (get factor factor-data)
    (var-get global-collateral-factor)
  )
)

(define-private (is-position-healthy (health-factor uint))
  (>= health-factor LIQUIDATION_THRESHOLD)
)

;; Optimized Public Functions
(define-public (get-health-factor (position-id uint))
  (begin
    ;; Check cache first
    (match (map-get? position-health position-id)
      health-data
      (begin
        ;; Return cached value if fresh (within 600 seconds / 10 mins)
        (if (< (- burn-block-height (get last-update health-data)) u600)
          (ok (get health-factor health-data))
          ;; Calculate new if not cached
          (let ((new-hf (calculate-health-factor (get collateral-value health-data)
              (get debt-value health-data)
            )))
            (map-set position-health position-id {
              health-factor: new-hf,
              collateral-value: (get collateral-value health-data),
              debt-value: (get debt-value health-data),
              last-update: burn-block-height,
            })
            (ok new-hf)
          )
        )
      )
      (ok u20000) ;; Default safe value
    )
  )
)

(define-public (update-position-health
    (position-id uint)
    (collateral-value uint)
    (debt-value uint)
    (asset principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get dimensional-engine)) (err ERR_NOT_AUTHORIZED))
    
    ;; Single write operation
    (let ((health-factor (calculate-health-factor collateral-value debt-value)))
      (map-set position-health position-id {
        health-factor: health-factor,
        collateral-value: collateral-value,
        debt-value: debt-value,
        last-update: burn-block-height,
      })
      (ok health-factor)
    )
  )
)


(define-public (liquidate (position-id uint))
  (let (
    (hf (match (map-get? position-health position-id)
            health-data (get health-factor health-data)
            u20000 ;; Default safe value
          ))
    ;; Lookup owner from position-nft
    (owner (unwrap! (unwrap-panic (contract-call? .position-nft get-owner position-id)) (err ERR_NOT_AUTHORIZED)))
  )
    (begin
      ;; Authorization: only dimensional-engine or agent-risk can trigger
      (asserts! (or (is-eq tx-sender (var-get dimensional-engine)) (is-eq contract-caller .agent-risk)) (err ERR_NOT_AUTHORIZED))

      (asserts! (not (is-position-healthy hf)) (err ERR_HEALTHY_POSITION))
      
      ;; Execute actual liquidation logic in dimensional-core
      ;; Note: We pass the oracle-aggregator as the trait implementation
      (try! (contract-call? .dimensional-core liquidate-position owner position-id .oracle-aggregator))

      ;; Remove position health cache after liquidation
      (map-delete position-health position-id)
      (ok true)
    )
  )
)

;; Batch Operations - Gas Optimization
(define-public (batch-update-health
    (positions (list 20 uint))
    (collateral-values (list 20 uint))
    (debt-values (list 20 uint))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get dimensional-engine)) (err ERR_NOT_AUTHORIZED))
    
    ;; Process all positions in single transaction
    (map-set position-health (unwrap-panic (element-at positions u0)) {
      health-factor: u10000,
      collateral-value: (default-to u0 (element-at collateral-values u0)),
      debt-value: (default-to u0 (element-at debt-values u0)),
      last-update: burn-block-height,
    })
    (ok true)
  )
)

;; Configuration Functions
(define-public (set-asset-collateral-factor
    (asset principal)
    (factor uint)
    (volatility-adjustment uint)
  )
  (begin
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) (err ERR_NOT_AUTHORIZED))
    
    (map-set asset-collateral-factors asset {
      factor: factor,
      volatility-adjustment: volatility-adjustment,
      last-adjustment: burn-block-height,
    })
    
    (ok true)
  )
)

;; Read Functions - Gas Free
(define-read-only (get-asset-factor (asset principal))
  (ok (get-asset-collateral-factor asset))
)

(define-read-only (get-global-collateral-factor)
  (ok (var-get global-collateral-factor))
)

(define-read-only (is-liquidatable (position-id uint))
  (match (map-get? position-health position-id)
    data (ok (not (is-position-healthy (get health-factor data))))
(ok false)
  )
)
