;; Fully Exploited Fiscal Dam Logic - Nakamoto Aligned

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)

;; State
(define-data-var last-fiscal-height uint u0)
(define-data-var current-fiscal-state uint u1) ;; 0=CRISIS, 1=STABILITY, 2=ABUNDANCE
(define-data-var contract-owner principal tx-sender)

;; CXIP-013 Equilibrium Baseline (bps)
(define-constant BASELINE_TREASURY u4500)
(define-constant BASELINE_BOUNTY   u3000)
(define-constant BASELINE_LP       u1500)
(define-constant BASELINE_GRANT    u500)
(define-constant BASELINE_BUYBACK  u500)

;; --- Performance Adjustment Logic ---

(define-read-only (calculate-performance-adjustment)
  (let (
    (metrics (contract-call? .agent-risk get-performance-metrics))
    (tvl-growth (get tvl-growth-bps metrics))
    (bounty-rate (get bounty-completion-rate metrics))
  )
    (if (or (> tvl-growth u1200) (> bounty-rate u9500))
      u500 ;; +5% shift from Treasury to Bounty
      u0
    )
  )
)

;; --- Cybernetic Revenue Allocation ---

(define-read-only (calculate-cybernetic-policy)
  (let (
    (intel (contract-call? .agent-risk get-cybernetic-intel))
    (gcr (get financial-gcr intel))
    (risk-score (get health-score intel))
    (perf-adj (calculate-performance-adjustment))

    ;; Adjusted Baseline for Stability
    (adj-treasury (- BASELINE_TREASURY perf-adj))
    (adj-bounty   (+ BASELINE_BOUNTY   perf-adj))
  )
    (if (or (< gcr u110) (>= risk-score u5000))
      ;; CRISIS: 100% Insurance
      { treasury: u0, bounty: u0, lp: u0, grant: u0, buyback: u0, insurance: u10000 }
      (if (>= gcr u150)
        ;; ABUNDANCE: 80% LP, 10% Treasury, 10% Insurance (Others scaled to 0 or minimal)
        { treasury: u1000, bounty: u0, lp: u8000, grant: u0, buyback: u0, insurance: u1000 }
        (if (>= gcr u130)
          ;; STABILITY: Use CXIP-013 Performance-Adjusted Baseline
          {
            treasury: adj-treasury,
            bounty: adj-bounty,
            lp: BASELINE_LP,
            grant: BASELINE_GRANT,
            buyback: BASELINE_BUYBACK,
            insurance: u0
          }
          ;; CRISIS TO STABILITY (110-130) - Interpolate between 100% Ins and Stability Baseline
          (let (
            (delta (- gcr u110)) ;; 0 to 20
            (share-multiplier delta) ;; 0 to 20
            ;; Each part gets (Multiplier/20) of its stability target
            (t-share (/ (* adj-treasury share-multiplier) u20))
            (b-share (/ (* adj-bounty share-multiplier) u20))
            (l-share (/ (* BASELINE_LP share-multiplier) u20))
            (g-share (/ (* BASELINE_GRANT share-multiplier) u20))
            (bb-share (/ (* BASELINE_BUYBACK share-multiplier) u20))
            (total-shares (+ (+ (+ (+ t-share b-share) l-share) g-share) bb-share))
          )
            {
              treasury: t-share,
              bounty: b-share,
              lp: l-share,
              grant: g-share,
              buyback: bb-share,
              insurance: (- u10000 total-shares)
            }
          )
        )
      )
    )
  )
)

;; @desc Run the fiscal strategy based on system risk (The Fiscal Dam).
(define-public (run-fiscal-strategy)
  (let ((btc-height burn-block-height))
    ;; Only run once per Bitcoin block
    (if (<= btc-height (var-get last-fiscal-height))
      (ok false)
      (let (
        (policy (calculate-cybernetic-policy))
      )
        (begin
          (try! (contract-call? .cxd-treasury rebalance
            (get treasury policy)
            (get bounty policy)
            (get lp policy)
            (get grant policy)
            (get buyback policy)
            (get insurance policy)
          ))
          (var-set last-fiscal-height btc-height)
          ;; Update current-fiscal-state
          (var-set current-fiscal-state (if (is-eq (get lp policy) u0) u0 (if (>= (get lp policy) u8000) u2 u1)))
          (print {
            event: "fiscal-strategy-executed",
            policy: policy,
            height: btc-height
          })
          (ok true)
        )
      )
    )
  )
)

(define-public (apply-fiscal-dam)
  (run-fiscal-strategy)
)

;; Admin Functions

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Compliance & Audit

(define-read-only (get-fiscal-status)
  (ok {
    last-run: (var-get last-fiscal-height),
    strategy: "FISCAL-DAM-CXIP-013",
    compliant: true
  })
)

;; --- Strategic Enhancement: IaaS Monetization ---

(define-public (deposit-service-fee (token <sip-010-ft-trait>) (amount uint))
  (begin
    ;; Transfer tokens from sender to distributor via this agent
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (try! (as-contract (contract-call? .revenue-distributor distribute-token token amount)))
    (print { event: "service-fee-deposited", amount: amount, token: (contract-of token) })
    (ok true)
  )
)

(define-public (deposit-service-fee-stx (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (as-contract (contract-call? .revenue-distributor distribute-stx amount)))
    (print { event: "service-fee-stx-deposited", amount: amount })
    (ok true)
  )
)
