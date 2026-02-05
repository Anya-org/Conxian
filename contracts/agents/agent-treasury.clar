;; agent-treasury.clar
;; "The CFO" - Autonomous Treasury Management
;; Implements Office Worker trait to rebalance funds automatically.

(impl-trait .automation-traits.office-job-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

(define-data-var last-fiscal-height uint u0)
;; State
(define-data-var rebalance-threshold uint u1000000) ;; 1M uSTX

;; PID Controller State
(define-data-var last-error int 0)
(define-data-var integral int 0)

;; PID Constants (scaled by 10000 for precision)
(define-constant KP 500) ;; 0.05
(define-constant KI 10)  ;; 0.001
(define-constant KD 100) ;; 0.01

;; @desc Rebalance revenue flows based on Global Collateral Ratio (GCR).
(define-public (run-fiscal-strategy)
  (let ((btc-height burn-block-height))
    (if (<= btc-height (var-get last-fiscal-height))
      (ok false)
      (let ((gcr (unwrap-panic (contract-call? .agent-risk get-gcr))))
        (begin
          (if (< gcr u110)
            ;; EMERGENCY: 100% to Insurance Fund
            (try! (contract-call? .cxd-treasury rebalance u0 u0 u10000))
            (if (< gcr u150)
              ;; STABILITY: 60% Stakers, 20% Ops, 20% Insurance
              (try! (contract-call? .cxd-treasury rebalance u6000 u2000 u2000))
              ;; ABUNDANCE: 80% Stakers, 10% Ops, 10% Insurance
              (try! (contract-call? .cxd-treasury rebalance u8000 u1000 u1000))
            )
          )
          (var-set last-fiscal-height btc-height)
          (ok true)
        )
      )
    )
  )
)

(define-public (apply-fiscal-dam)
  (run-fiscal-strategy)
)

(define-public (check-work-needed)
  (let (
      (risk-score (contract-call? .agent-risk assess-system-risk))
    )
    (if (or (> risk-score u1000) (> (stx-get-balance (as-contract tx-sender)) (var-get rebalance-threshold)))
      (ok true)
      (ok false)
    )
  )
)

(define-private (get-fuzzy-setpoint (risk-state (string-ascii 20)))
  (if (is-eq risk-state "DEFENSIVE")
    500
    (if (is-eq risk-state "CRISIS")
      0
      6000
    )
  )
)

(define-private (calculate-pid-adjustment (setpoint int) (current int))
  (let (
    (error (- setpoint current))
    (raw-integral (+ (var-get integral) error))
    (new-integral (if (> raw-integral 2000) 2000 (if (< raw-integral -2000) -2000 raw-integral)))
    (derivative (- error (var-get last-error)))
    (adjustment (/ (+ (+ (* KP error) (* KI new-integral)) (* KD derivative)) 10000))
  )
    (begin
      (var-set integral new-integral)
      (var-set last-error error)
      adjustment
    )
  )
)

(define-public (do-work (job-data (buff 2048)))
  (let (
    (risk-state (contract-call? .agent-risk get-current-risk-state))
    (current-shares (unwrap-panic (contract-call? .cxd-treasury get-allocation-percentages)))
    (current-staking (to-int (get staking current-shares)))
    (target-setpoint (get-fuzzy-setpoint risk-state))
    (adjustment (calculate-pid-adjustment target-setpoint current-staking))

    (clamped-adj (if (> adjustment 100) 100 (if (< adjustment -100) -100 adjustment)))
    (new-staking-int (+ current-staking clamped-adj))

    (final-staking (if (> new-staking-int 6000) u6000 (if (< new-staking-int 0) u0 (to-uint new-staking-int))))
    
    (new-dev u2000)
    (new-insurance (- u8000 final-staking))
  )
    (begin
      (try! (contract-call? .cxd-treasury rebalance final-staking new-dev new-insurance))

      (print {
        event: "agent-treasury-rebalance-executed",
        risk-state: risk-state,
        new-staking: final-staking,
        adjustment: clamped-adj
      })

      (match (contract-call? .office-manager payout tx-sender u5)
        success (ok true)
        error (begin
          (print { msg: "payout-failed", err: error })
          (ok true)
        )
      )
    )
  )
)
