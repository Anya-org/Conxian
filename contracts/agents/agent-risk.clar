;; agent-risk.clar
;; Agent-Risk 2.0: Predictive Perception & PID Stability Controller
;; Fully Exploited Cybernetic Logic - Nakamoto Aligned

(use-trait office-job-trait .automation-traits.office-job-trait)
(use-trait risk-manager-trait .core-traits.risk-manager-trait)
(use-trait oracle-trait .defi-traits.oracle-trait)

(impl-trait .core-traits.risk-manager-trait)
(impl-trait .automation-traits.office-job-trait)

(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_INVALID_PARAMETERS u1005)
(define-constant ERR_ORACLE_FAILURE u1006)

(define-data-var contract-owner principal tx-sender)
(define-data-var max-leverage uint u2000)
(define-data-var maintenance-margin uint u500)
(define-data-var liquidation-threshold uint u8000)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)

;; Performance Metrics (CXIP-013)
(define-data-var total-value-locked uint u1000000000)
(define-data-var last-month-tvl uint u900000000)
(define-data-var bounty-completion-rate uint u9600)
(define-data-var mock-gcr uint u0)

;; Predictive Perception State
(define-data-var liquidity-depth uint u10000)
(define-data-var hash-rate-volatility uint u0)
(define-data-var mempool-congestion uint u0)

;; PID Stability State
(define-data-var last-price-error int 0)
(define-data-var price-integral int 0)
(define-data-var stability-fee uint u500)

(define-constant PRICE_TARGET u100000000) ;; 1.0 USD (8 decimals)
(define-constant KP_STABILITY u5)
(define-constant KI_STABILITY u1)
(define-constant KD_STABILITY u10)

(define-data-var last-checked-id-agent uint u0)

;; --- Risk Assessment ---

(define-public (set-predictive-params (new-depth uint) (new-vol uint) (new-cong uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set liquidity-depth new-depth)
    (var-set hash-rate-volatility new-vol)
    (var-set mempool-congestion new-cong)
    (ok true)
  )
)

(define-read-only (assess-system-risk)
  (let (
    (l-risk (if (> u10000 (var-get liquidity-depth)) (- u10000 (var-get liquidity-depth)) u0))
    (h-risk (var-get hash-rate-volatility))
    (m-risk (var-get mempool-congestion))
  )
    (/ (+ (+ l-risk h-risk) m-risk) u3)
  )
)

(define-read-only (get-current-risk-state)
  (let ((score (assess-system-risk)))
    (if (>= score u5000) "CRISIS" (if (>= score u2000) "DEFENSIVE" "EQUILIBRIUM"))
  )
)

;; @desc Calculates Global Collateral Ratio (GCR)
;; GCR = (Total Collateral / Total Debt) * 100
;; Factor in Predictive Perception for early warning.
(define-read-only (get-gcr-internal)
  (let (
    (score (assess-system-risk))
    (cxd-reserve (default-to { total-deposits: u0, total-borrows: u0, total-reserves: u0, last-updated: u0 }
                  (contract-call? .lending-manager get-reserve-data .cxd-token)))
    (total-deposits (get total-deposits cxd-reserve))
    (total-borrows (get total-borrows cxd-reserve))
    (metric-gcr (if (> (var-get mock-gcr) u0) (var-get mock-gcr) (if (is-eq total-borrows u0) u10000 (/ (* total-deposits u100) total-borrows))))
  )
    (if (>= score u5000)
      u105 ;; Force Crisis state for high risk scores (e.g. market crash)
      metric-gcr
    )
  )
)

;; --- PID Stability Controller ---

(define-public (update-pid-rates)
  (begin
    (asserts! (or (is-eq contract-caller .ops-engine) (is-eq tx-sender (var-get contract-owner))) (err ERR_UNAUTHORIZED))
    (let (
      (current-price (try! (contract-call? .oracle-aggregator get-price .cxd-token)))
      (target-price PRICE_TARGET)
      (error (- (to-int target-price) (to-int current-price)))
      (prev-error (var-get last-price-error))
      ;; Integral windup protection: clamp integral to prevent excessive accumulation
      (raw-integral (+ (var-get price-integral) error))
      (integral (if (> raw-integral 10000000) 10000000 (if (< raw-integral -10000000) -10000000 raw-integral)))
      (derivative (- error prev-error))
      ;; PID Formula: Output = (Kp*E + Ki*I + Kd*D)
      (pid-output (+ (+ (* (to-int KP_STABILITY) error) (* (to-int KI_STABILITY) integral)) (* (to-int KD_STABILITY) derivative)))
      ;; Convert output to a positive uint fee (basis points)
      (new-fee (if (< pid-output 0) u0 (to-uint pid-output)))
    )
      (begin
        (var-set last-price-error error)
        (var-set price-integral integral)
        ;; Stability Fee clamped between 0 and 2000 bps (20%)
        (var-set stability-fee (if (> new-fee u2000) u2000 new-fee))
        (print { event: "pid-updated", error: error, fee: (var-get stability-fee), timestamp: burn-block-height })
        (ok true)
      )
    )
  )
)

(define-read-only (get-stability-fee)
  (ok (var-get stability-fee))
)

;; --- Position Management & Liquidation ---

(define-public (assess-position-risk (position-id uint))
  (contract-call? .risk-manager get-health-factor position-id)
)

(define-read-only (is-liquidatable (position-id uint))
  (contract-call? .risk-manager is-liquidatable position-id)
)

(define-public (liquidate (position-id uint))
  (contract-call? .risk-manager liquidate position-id)
)

(define-public (liquidate-position (position-id uint) (liquidator principal))
  ;; Delegate to core risk manager
  (let ((result (try! (contract-call? .risk-manager liquidate position-id))))
    (ok { liquidated: result, reward: u0, repaid: u0 })
  )
)

;; --- Automation Interface (Office Job) ---

(define-public (check-work-needed)
  ;; Check if PID needs update (e.g., every 100 blocks) or if there are liquidatable positions
  (ok false)
)

(define-public (do-work (job-data (buff 2048)))
  ;; Placeholder for autonomous liquidation loops
  (ok true)
)


;; --- Cybernetic Intelligence ---

;; @desc Consolidated system intelligence for the Fiscal Dam.
;; Returns health (risk score), financial (GCR), and operational (PID) metrics.
(define-read-only (get-cybernetic-intel)
  (let (
    (risk-score (assess-system-risk))
    (gcr (get-gcr-internal))
    (pid-fee (var-get stability-fee))
  )
    {
      health-score: risk-score,
      financial-gcr: gcr,
      operational-fee: pid-fee,
      timestamp: burn-block-height
    }
  )
)

(define-public (get-health-factor (position-id uint))
  (contract-call? .risk-manager get-health-factor position-id)
)

;; --- Enhanced Risk Controls ---

(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)
    (ok true)
  )
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    (ok true)
  )
)

(define-read-only (calculate-liquidation-price (position {entry-price: uint, leverage: uint, is-long: bool}))
  (let (
    (entry-price (get entry-price position))
    (leverage (get leverage position))
    (is-long (get is-long position))
    (mm (var-get maintenance-margin))
  )
    (if is-long
      (ok (/ (* entry-price (- u10000 (/ u10000 leverage))) u10000))
      (ok (/ (* entry-price (+ u10000 (/ u10000 leverage))) u10000))
    )
  )
)

;; --- Performance Metrics (CXIP-013) ---

(define-public (set-performance-metrics (new-tvl uint) (new-last-tvl uint) (new-bounty-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set total-value-locked new-tvl)
    (var-set last-month-tvl new-last-tvl)
    (var-set bounty-completion-rate new-bounty-rate)
    (ok true)
  )
)

(define-read-only (get-performance-metrics)
  {
    tvl: (var-get total-value-locked),
    last-month-tvl: (var-get last-month-tvl),
    bounty-completion-rate: (var-get bounty-completion-rate),
    tvl-growth-bps: (if (is-eq (var-get last-month-tvl) u0) u0 (if (>= (var-get total-value-locked) (var-get last-month-tvl)) (/ (* (- (var-get total-value-locked) (var-get last-month-tvl)) u10000) (var-get last-month-tvl)) u0))
  }
)

(define-public (set-mock-gcr (new-gcr uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set mock-gcr new-gcr)
    (ok true)
  )
)

(define-read-only (get-gcr)
  (ok (get-gcr-internal))
)
