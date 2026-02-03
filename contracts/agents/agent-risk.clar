;; agent-risk.clar
;; Agent-Risk 2.0: Predictive Perception & PID Stability Controller
;; Implements the AYE (Automated Yield Engine) PID logic for CXD peg stability.

(use-trait office-job-trait .automation-traits.office-job-trait)
(use-trait risk-manager-trait .core-traits.risk-manager-trait)

(impl-trait .core-traits.risk-manager-trait)
(impl-trait .automation-traits.office-job-trait)

(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_INVALID_PARAMETERS u1005)
(define-constant ERR_NOT_CONFIGURED u1006)
(define-constant MIN_LEVERAGE u100)

(define-data-var contract-owner principal tx-sender)
(define-data-var max-leverage uint u2000)
(define-data-var maintenance-margin uint u500)
(define-data-var liquidation-threshold uint u8000)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)
(define-data-var last-checked-id uint u0)

;; Agent-Risk 2.0: Predictive Perception State
(define-data-var liquidity-depth uint u10000) ;; 10000 = 100% (Target depth)
(define-data-var hash-rate-volatility uint u0) ;; 0 = stable, 10000 = extreme
(define-data-var mempool-congestion uint u0) ;; 0 = empty, 10000 = full

;; Governance bounds for states
(define-constant RISK_THRESHOLD_PREEMPTIVE u2000)
(define-constant RISK_THRESHOLD_DEFENSIVE u5000)

;; PID Stability Controller State
(define-data-var last-price-error int 0)
(define-data-var price-integral int 0)
(define-data-var stability-fee uint u500) ;; 5% default (bps)

;; PID Constants (Refined for 8-decimal price error)
;; KP=5: 1% error (10^6) -> 5*10^6 / 10^4 = 500 bps (5%) adjustment
(define-constant KP_STABILITY u5)
(define-constant KI_STABILITY u1)
(define-constant KD_STABILITY u10)
(define-constant PRICE_TARGET u100000000) ;; $1.00 (8 decimals)
(define-constant INTEGRAL_LIMIT (to-int u10000000)) ;; 10% cumulative limit
(define-constant DEADBAND (to-int u50000)) ;; 5 bps deadband

(define-public (set-predictive-params
    (new-liquidity-depth uint)
    (new-hash-rate-volatility uint)
    (new-mempool-congestion uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts! (<= new-liquidity-depth u10000) (err ERR_INVALID_PARAMETERS))
    (asserts! (<= new-hash-rate-volatility u10000) (err ERR_INVALID_PARAMETERS))
    (asserts! (<= new-mempool-congestion u10000) (err ERR_INVALID_PARAMETERS))
    (var-set liquidity-depth new-liquidity-depth)
    (var-set hash-rate-volatility new-hash-rate-volatility)
    (var-set mempool-congestion new-mempool-congestion)
    (ok true)
  )
)

(define-read-only (assess-system-risk)
  (let (
    ;; Liquidity risk increases as depth decreases
    (l-risk (if (> u10000 (var-get liquidity-depth)) (- u10000 (var-get liquidity-depth)) u0))
    (h-risk (var-get hash-rate-volatility))
    (m-risk (var-get mempool-congestion))
    ;; Simple weighted average for composite score
    (composite-score (/ (+ (+ l-risk h-risk) m-risk) u3))
  )
    composite-score
  )
)

(define-read-only (get-current-risk-state)
  (let (
    (score (assess-system-risk))
  )
    (if (>= score RISK_THRESHOLD_DEFENSIVE)
      "DEFENSIVE"
      (if (>= score RISK_THRESHOLD_PREEMPTIVE)
        "PREEMPTIVE"
        "EQUILIBRIUM"
      )
    )
  )
)

(define-read-only (get-gcr)
  (let ((score (assess-system-risk)))
    (if (> score u5000)
      (ok u105) ;; Crisis
      (if (> score u2000)
        (ok u130) ;; Stability
        (ok u160) ;; Abundance
      )
    )
  )
)

(define-public (update-pid-rates)
  (let (
    (price (unwrap-panic (contract-call? .oracle-aggregator get-price .cxd-token)))
    (raw-error (- (to-int PRICE_TARGET) (to-int price)))
    ;; Apply Deadband
    (error (if (and (> raw-error (- 0 DEADBAND)) (< raw-error DEADBAND)) (to-int u0) raw-error))

    (raw-integral (+ (var-get price-integral) error))
    ;; Integral Clamping (Windup Protection)
    (new-integral (if (> raw-integral INTEGRAL_LIMIT) INTEGRAL_LIMIT (if (< raw-integral (- 0 INTEGRAL_LIMIT)) (- 0 INTEGRAL_LIMIT) raw-integral)))

    (derivative (- error (var-get last-price-error)))
    (term-p (* (to-int KP_STABILITY) error))
    (term-i (* (to-int KI_STABILITY) new-integral))
    (term-d (* (to-int KD_STABILITY) derivative))
    (numerator (+ (+ term-p term-i) term-d))
    (adjustment (/ numerator (to-int u10000)))
    (current-fee (to-int (var-get stability-fee)))
    (new-fee-int (+ current-fee adjustment))
    ;; Final Fee Clamping: 0% to 20%
    (final-fee (if (> new-fee-int (to-int u2000)) u2000 (if (< new-fee-int (to-int u0)) u0 (to-uint new-fee-int))))
  )
    (begin
      (var-set price-integral new-integral)
      (var-set last-price-error error)
      (var-set stability-fee final-fee)
      (print { event: "stability-fee-updated", new-fee: final-fee, error: error, integral: new-integral })
      (ok true)
    )
  )
)

(define-public (set-risk-parameters
    (new-max-leverage uint)
    (new-maintenance-margin uint)
    (new-liquidation-threshold uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and (>= new-max-leverage MIN_LEVERAGE) (<= new-max-leverage u5000))
      (err ERR_INVALID_PARAMETERS)
    )
    (asserts!
      (and (> new-maintenance-margin u0) (< new-maintenance-margin u10000))
      (err ERR_INVALID_PARAMETERS)
    )
    (asserts!
      (and (> new-liquidation-threshold new-maintenance-margin) (<= new-liquidation-threshold u10000))
      (err ERR_INVALID_PARAMETERS)
    )
    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)
    (ok true)
  )
)

(define-public (set-liquidation-rewards
    (min-reward uint)
    (max-reward uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and
        (> min-reward u0)
        (<= min-reward max-reward)
        (<= max-reward u5000)
      )
      (err ERR_INVALID_PARAMETERS)
    )
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    (ok true)
  )
)

(define-public (liquidate (position-id uint))
  (let (
    (liquidator tx-sender)
  )
    (begin
      ;; 1. Check if position is liquidatable
      (asserts! (unwrap-panic (is-liquidatable position-id)) (err u1002))
      
      ;; 2. Get position details
      (let ((position-risk (unwrap! (assess-position-risk position-id) (err ERR_INVALID_PARAMETERS))))
        
        ;; 3. Calculate liquidation reward (5% of collateral, clamped to min/max)
        (let (
          (collateral (get collateral (unwrap! (contract-call? .position-manager get-position position-id) (err u404))))
          (reward-bps (var-get liquidation-threshold))
          (raw-reward (/ (* collateral reward-bps) u10000))
          (reward (if (< raw-reward (var-get min-liquidation-reward)) 
                   (var-get min-liquidation-reward)
                   (if (> raw-reward (var-get max-liquidation-reward))
                     (var-get max-liquidation-reward)
                     raw-reward)))
        )
          ;; 4. Call dimensional-core to execute liquidation
          (try! (contract-call? .dimensional-core liquidate-position 
            (get owner (unwrap! (contract-call? .position-manager get-position position-id) (err u404)))
            position-id 
            .oracle-aggregator))
          
          ;; 5. Transfer reward to liquidator (from insurance fund or protocol reserves)
          ;; Note: In production, this would transfer actual assets. For now, we log the event.
          (print { 
            event: "liquidation-executed", 
            position-id: position-id, 
            liquidator: liquidator,
            reward: reward,
            timestamp: burn-block-height
          })
          
          (ok true)
        )
      )
    )
  )
)

(define-read-only (get-health-factor (position-id uint))
  (begin
    ;; Simplified health factor calculation
    (ok u15000) ;; 150% health factor
  )
)

(define-public (update-position-health (position-id uint) (new-health uint) (collateral-value uint) (strategy principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Update logic would go here
    (ok new-health)
  )
)

(define-public (set-asset-collateral-factor (asset principal) (factor uint) (risk-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Set factor logic would go here
    (ok true)
  )
)

(define-read-only (get-asset-factor (asset principal))
  (begin
    ;; Return default collateral factor
    (ok u8000) ;; 80%
  )
)

(define-read-only (get-global-collateral-factor)
  (begin
    ;; Return global collateral factor
    (ok u8000) ;; 80%
  )
)

(define-read-only (is-liquidatable (position-id uint))
  (match (assess-position-risk position-id)
    risk-data (ok (< (get health-factor risk-data) u10000))
    error (err u404)
  )
)

(define-public (liquidate-position
    (position-id uint)
    (liquidator principal)
  )
  (let (
    (caller tx-sender)
  )
    (begin
      ;; 1. Verify caller is authorized (this contract or admin)
      (asserts! (or (is-eq caller (var-get contract-owner)) (is-eq caller (as-contract tx-sender))) (err ERR_UNAUTHORIZED))
      
      ;; 2. Check if position is liquidatable
      (asserts! (unwrap-panic (is-liquidatable position-id)) (err u1003))
      
      ;; 3. Execute liquidation through dimensional-core
      (let (
        (position (unwrap! (contract-call? .position-manager get-position position-id) (err u404)))
        (owner (get owner position))
        (collateral (get collateral position))
        ;; Calculate 5% liquidation penalty
        (penalty (/ (* collateral u500) u10000))
        (reward (- collateral penalty))
      )
        ;; Call dimensional-core to liquidate
        (try! (contract-call? .dimensional-core liquidate-position owner position-id .oracle-aggregator))
        
        ;; Seize collateral from lending-manager if applicable
        (try! (contract-call? .lending-manager seize-collateral .cxd-token owner liquidator collateral))
        
        ;; Transfer reward to liquidator
        ;; In production, transfer actual tokens. For now, log the event.
        (print {
          event: "liquidate-position",
          position-id: position-id,
          owner: owner,
          liquidator: liquidator,
          collateral-seized: collateral,
          liquidation-penalty: penalty,
          liquidator-reward: reward,
          timestamp: burn-block-height
        })
        
        (ok {
          liquidated: true,
          reward: reward,
          repaid: collateral,
        })
      )
    )
  )
)

(define-public (set-insurance-fund (fund principal))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (var-set insurance-fund fund)
    (ok true)
  )
)

(define-read-only (calculate-liquidation-price (position {
  entry-price: uint,
  leverage: uint,
  is-long: bool,
}))
  (let (
      (m-margin (var-get maintenance-margin))
      (entry-price (get entry-price position))
      (leverage (get leverage position))
      (is-long (get is-long position))
    )
    (if is-long
      (ok (* entry-price
        (/ (+ (- (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
      (ok (* entry-price
        (/ (- (+ (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
    )
  )
)

(define-private (check-role (role (string-ascii 32)))
  (if (or (is-eq tx-sender (var-get contract-owner)) (is-eq contract-caller .conxian-access))
    (ok true)
    (err ERR_UNAUTHORIZED)
  )
)

(define-read-only (assess-position-risk (position-id uint))
  (let (
      (position (unwrap! (contract-call? .position-manager get-position position-id)
        (err ERR_INVALID_PARAMETERS)
      ))
      (collateral (get collateral position))
      (size (get size position))
      (entry-price (get entry-price position))
      (threshold (var-get liquidation-threshold))
      (health-factor (if (is-eq size u0)
        u1000000
        (/ (* collateral threshold) size)
      ))
      (liquidation-price (unwrap!
        (calculate-liquidation-price {
          entry-price: entry-price,
          leverage: (get leverage position),
          is-long: (get is-long position),
        })
        (err ERR_INVALID_PARAMETERS)
      ))
    )
    (ok {
      health-factor: health-factor,
      liquidation-price: liquidation-price,
      risk-level: (if (> health-factor u15000)
        "LOW"
        (if (> health-factor u11000)
          "MEDIUM"
          "HIGH"
        )
      ),
    })
  )
)

(define-data-var cxvg-seat-nft-id uint u0)

(define-public (vote-on-solvency)
  (ok true)
)

;; --- Office Worker Implementation ---

;; @desc Autonomous check to see if any position needs liquidation.
(define-public (check-work-needed)
  (let (
    (next-id (+ (var-get last-checked-id) u1))
  )
    (match (contract-call? .dimensional-core get-position tx-sender next-id)
      pos (ok (unwrap-panic (is-liquidatable next-id)))
      (begin
        (var-set last-checked-id u0) ;; Reset loop
        (ok false)
      )
    )
  )
)

;; @desc Executes the liquidation and rewards the worker.
(define-public (do-work (job-data (buff 2048)))
  (let (
    (position-id (var-get last-checked-id))
  )
    (begin
      (try! (contract-call? .dimensional-core liquidate-position tx-sender position-id .oracle-aggregator))
      (var-set last-checked-id (+ position-id u1))
      (try! (contract-call? .office-manager payout tx-sender u5))
      (ok true)
    )
  )
)
