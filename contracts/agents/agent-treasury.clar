;; agent-treasury.clar
;; "The CFO" - Autonomous Treasury Management
;; Implements Office Worker trait to rebalance funds automatically.

(impl-trait .automation-traits.office-job-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

(define-data-var last-slow-check uint u0)
;; State
(define-data-var rebalance-threshold uint u1000000) ;; 1M uSTX

;; PID Controller State
(define-data-var last-error int 0)
(define-data-var integral int 0)

;; PID Constants (scaled by 10000 for precision)
(define-constant KP 500) ;; 0.05
(define-constant KI 10)  ;; 0.001
(define-constant KD 100) ;; 0.01

;; Authorization

(define-public (apply-fiscal-dam)
  (let ((gcr (unwrap-panic (contract-call? .agent-risk get-gcr))))
    (begin
      (if (< gcr u110)
        (try! (contract-call? .cxd-treasury rebalance u0 u0 u10000))
        (if (< gcr u150)
          (try! (contract-call? .cxd-treasury rebalance u6000 u2000 u2000))
          (try! (contract-call? .cxd-treasury rebalance u8000 u1000 u1000))
        )
      )
      (var-set last-slow-check burn-block-height)
      (ok true)
    )
  )
)

(define-public (check-work-needed)
  (let (
      (risk-score (contract-call? .agent-risk assess-system-risk))
    )
    ;; Work needed if risk is above threshold OR balance is high
    (if (or (> risk-score u1000) (> (stx-get-balance (as-contract tx-sender)) (var-get rebalance-threshold)))
      (ok true)
      (ok false)
    )
  )
)

;; Fuzzy Logic: Maps risk state to target staking share
(define-private (get-fuzzy-setpoint (risk-state (string-ascii 20)))
  (if (is-eq risk-state "DEFENSIVE")
    500 ;; 5%
    (if (is-eq risk-state "PREEMPTIVE")
      4750 ;; 47.5%
      6000 ;; 60%
    )
  )
)

;; PID Math: Calculates the adjustment for the staking share
(define-private (calculate-pid-adjustment (setpoint int) (current int))
  (let (
    (error (- setpoint current))
    (raw-integral (+ (var-get integral) error))
    ;; Integral Windup Protection (Clamping integral between -2000 and 2000 bps)
    (new-integral (if (> raw-integral 2000) 2000 (if (< raw-integral -2000) -2000 raw-integral)))
    (derivative (- error (var-get last-error)))
    ;; Adjustment = (KP*e + KI*int + KD*der) / 10000
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

    ;; New Staking Share (apply adjustment, max 1% shift per block as per Fuzzy State Transition requirement)
    (clamped-adj (if (> adjustment 100) 100 (if (< adjustment -100) -100 adjustment)))
    (new-staking-int (+ current-staking clamped-adj))

    ;; Ensure it stays within absolute bounds 0-60%
    (final-staking (if (> new-staking-int 6000) u6000 (if (< new-staking-int 0) u0 (get-uint new-staking-int))))
    
    ;; Rebalance other shares (Dev stays 20%, Insurance takes the remainder)
    (new-dev u2000)
    (new-insurance (- u8000 final-staking))
  )
    (begin
      ;; Execute Rebalance
      (try! (contract-call? .cxd-treasury rebalance final-staking new-dev new-insurance))

      (print {
        event: "agent-treasury-rebalance-executed",
        risk-state: risk-state,
        new-staking: final-staking,
        adjustment: clamped-adj
      })

      ;; Request Payout (5 uSTX) - optional, don't fail if payroll empty
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

(define-private (get-uint (i int))
  (to-uint i)
)
