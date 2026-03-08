;; agent-treasury.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

;; Baseline allocations (basis points, sum = 10000)
(define-constant BASELINE_LP u1500)
(define-constant BASELINE_TREASURY u4500)
(define-constant BASELINE_BOUNTY u3000)
(define-constant BASELINE_GRANT u500)
(define-constant BASELINE_BUYBACK u500)

;; Risk adjustment constants
(define-constant RISK_THRESHOLD_LOW u100)    ;; Healthy
(define-constant RISK_THRESHOLD_MEDIUM u500) ;; Warning
(define-constant RISK_THRESHOLD_HIGH u900)   ;; Crisis

;; Data vars for dynamic adjustment
(define-data-var admin principal tx-sender)

;; @desc Run the fiscal strategy - responsive to risk conditions
(define-public (run-fiscal-strategy)
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) (err u2001)))
    (gcr (get financial-gcr intel))
    (risk-score (get risk-score intel))
    (adjusted-allocations (adjust-allocations-for-risk risk-score))
  )
    (begin
      ;; Rebalance treasury with risk-adjusted allocations
      (try! (contract-call? .cxd-treasury rebalance
        (get treasury adjusted-allocations)
        (get bounty adjusted-allocations)
        (get lp adjusted-allocations)
        (get grant adjusted-allocations)
        (get buyback adjusted-allocations)
        u0
      ))
      
      (print {
        event: "fiscal-strategy-executed",
        risk-score: risk-score,
        gcr: gcr,
        allocations: adjusted-allocations,
        timestamp: burn-block-height
      })
      (ok adjusted-allocations)
    )
  )
)

;; @desc Adjust allocations based on risk score
(define-private (adjust-allocations-for-risk (risk-score uint))
  (if (< risk-score RISK_THRESHOLD_LOW)
    ;; Healthy: Use baseline
    {
      treasury: BASELINE_TREASURY,
      bounty: BASELINE_BOUNTY,
      lp: BASELINE_LP,
      grant: BASELINE_GRANT,
      buyback: BASELINE_BUYBACK
    }
    (if (< risk-score RISK_THRESHOLD_MEDIUM)
      ;; Warning: Increase treasury buffer, reduce grants
      {
        treasury: (+ BASELINE_TREASURY u500),  ;; +5% to treasury
        bounty: BASELINE_BOUNTY,
        lp: BASELINE_LP,
        grant: (- BASELINE_GRANT u300),        ;; -3% from grants
        buyback: (- BASELINE_BUYBACK u200)    ;; -2% from buyback
      }
      ;; Crisis/High Risk: Maximize treasury, minimize discretionary
      {
        treasury: (+ BASELINE_TREASURY u1000), ;; +10% to treasury
        bounty: (- BASELINE_BOUNTY u500),      ;; -5% from bounty
        lp: (- BASELINE_LP u300),              ;; -3% from LP
        grant: u0,                             ;; 0 grants
        buyback: u0                            ;; 0 buyback
      }
    )
  )
)

;; @desc Admin function to set admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, paused: false, tenure-id: (some (/ block-height u10)), timestamp: burn-block-height, version: "08" })
)
