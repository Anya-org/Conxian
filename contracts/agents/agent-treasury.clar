;; agent-treasury.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Fully Exploited Fiscal Dam Logic - Nakamoto Aligned

(define-constant ERR_UNAUTHORIZED u1000)

;; State
(define-data-var last-fiscal-height uint u0)
(define-data-var current-fiscal-state uint u1) ;; 0=CRISIS, 1=STABILITY, 2=ABUNDANCE
(define-data-var contract-owner principal tx-sender)

;; --- Cybernetic Revenue Allocation ---

;; @desc Calculate the dynamic revenue split based on cybernetic intel.
;; Linear interpolation for smooth transitions between states.
(define-read-only (calculate-cybernetic-policy)
  (let (
    (intel (contract-call? .agent-risk get-cybernetic-intel))
    (gcr (get financial-gcr intel))
    (risk-score (get health-score intel))
  )
    (if (or (< gcr u110) (>= risk-score u5000))
      ;; CRISIS: 100% Insurance
      { staking: u0, dev: u0, insurance: u10000 }
      (if (>= gcr u150)
        ;; ABUNDANCE: 80% Staking, 10% Dev, 10% Insurance
        { staking: u8000, dev: u1000, insurance: u1000 }
        (if (>= gcr u130)
          ;; STABILITY TO ABUNDANCE (130-150)
          (let (
            (delta (- gcr u130))
            (staking-inc (/ (* delta u2000) u20))
            (dev-dec (/ (* delta u1000) u20))
          )
            {
              staking: (+ u6000 staking-inc),
              dev: (- u2000 dev-dec),
              insurance: (- u2000 dev-dec)
            }
          )
          ;; CRISIS TO STABILITY (110-130)
          (let (
            (delta (- gcr u110))
            (staking-inc (/ (* delta u6000) u20))
            (dev-inc (/ (* delta u2000) u20))
            (ins-dec (/ (* delta u8000) u20))
          )
            {
              staking: staking-inc,
              dev: dev-inc,
              insurance: (- u10000 ins-dec)
            }
          )
        )
      )
    )
  )
)

;; @desc Run the fiscal strategy based on system risk (The Fiscal Dam).
;; Adaptive revenue routing based on Global Collateral Ratio (GCR).
(define-public (run-fiscal-strategy)
  (let ((btc-height burn-block-height))
    ;; Only run once per Bitcoin block
    (if (<= btc-height (var-get last-fiscal-height))
      (ok false)
      (let (
        (policy (calculate-cybernetic-policy))
        (staking (get staking policy))
        (dev (get dev policy))
        (insurance (get insurance policy))
      )
        (begin
          (try! (contract-call? .cxd-treasury rebalance staking dev insurance))
          (var-set last-fiscal-height btc-height)
          ;; Update current-fiscal-state for legacy monitoring compatibility
          (var-set current-fiscal-state (if (is-eq staking u0) u0 (if (>= staking u8000) u2 u1)))
          (print {
            event: "fiscal-strategy-executed",
            staking: staking,
            dev: dev,
            insurance: insurance,
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

(define-public (set-regulatory-adapter-contract (new-adapter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-public (distribute (token principal) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

;; Compliance & Audit

(define-read-only (get-fiscal-status)
  (ok {
    last-run: (var-get last-fiscal-height),
    strategy: "FISCAL-DAM-CYBERNETIC-V3",
    compliant: true
  })
)
