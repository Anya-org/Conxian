;; agent-risk.clar
;; Cybernetic Risk Agent
;; Responsible for calculating protocol-wide risk scores and stability fees based on grounded telemetry.

(use-trait finance-metrics-trait .security-monitoring.finance-metrics-trait)
(use-trait risk-signal-publisher-trait .core-traits.risk-signal-publisher-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_RISK_SCORE (err u1001))
(define-constant ERR_NOT_INITIALIZED (err u1002))

;; The legacy agent API remains on a 0..1000 compatibility scale. Explicit
;; publication normalizes it by ten to risk-unit's canonical 0..10000 scale.
(define-constant MAX_AGENT_RISK_SCORE u1000)
(define-constant SYSTEM_SCORE_MULTIPLIER u10)

;; --- Data Variables ---
(define-data-var current-risk-score uint u500)
(define-data-var stability-fee uint u500)
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)
(define-data-var risk-unit-contract (optional principal) none)

;; --- Read-Only Functions ---

;; @desc Returns the current system-wide risk score.
;; @return (ok uint)
(define-read-only (get-risk-score)
  (ok (var-get current-risk-score))
)

;; @desc Returns the current status and version of the risk agent.
;; @return (ok { compliant: bool, version: (string-ascii 20) })
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.2.0" })
)

;; @desc Returns the current administrator of the risk agent.
;; @return (ok principal)
(define-read-only (get-contract-owner)
  (ok (var-get admin))
)

;; --- Public Functions ---

;; @desc Calculates and returns the Global Collateral Ratio (GCR) from finance metrics.
;; @param m <finance-metrics-trait>
;; @return (ok uint)
(define-public (get-gcr (m <finance-metrics-trait>))
  (contract-call? m get-protocol-gcr)
)

(define-private (score-for-gcr (gcr uint))
  ;; High risk is a larger score. Each result is within 0..1000.
  (if (<= gcr u100)
    u900
    (if (>= gcr u150) u100 u500)
  )
)

;; @desc Evaluates protocol health via GCR and updates the system risk score.
;; @param m <finance-metrics-trait>
;; @return (ok uint)
(define-public (assess-system-risk (m <finance-metrics-trait>))
  (match (contract-call? m get-protocol-gcr)
    gcr (let ((score (score-for-gcr gcr)))
      (begin
        (var-set current-risk-score score)
        (ok score)
      )
    )
    error (err error)
  )
)

;; @desc Aggregates cybernetic intelligence including fees, GCR, and risk score.
;; @param m <finance-metrics-trait>
;; @return (ok { operational-fee: uint, financial-gcr: uint, risk-score: uint })
(define-public (get-cybernetic-intel (m <finance-metrics-trait>))
  (match (contract-call? m get-protocol-gcr)
    gcr (let ((score (score-for-gcr gcr)))
      (begin
        (var-set current-risk-score score)
        (ok {
          operational-fee: (var-get stability-fee),
          financial-gcr: gcr,
          risk-score: score
        })
      )
    )
    error (err error)
  )
)

;; @desc Updates the PID stability fee.
;; @param f uint
;; @return (ok bool)
(define-public (set-stability-fee (f uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set stability-fee f)
    (ok true)
  )
)

;; @desc Manually overrides the system risk score.
;; @param s uint
;; @return (ok bool)
(define-public (set-risk-score (s uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= s MAX_AGENT_RISK_SCORE) ERR_INVALID_RISK_SCORE)
    (var-set current-risk-score s)
    (ok true)
  )
)

;; @desc Publishes a trusted, normalized risk score to the canonical risk unit.
;; The admin gate prevents an arbitrary metrics trait from controlling system
;; liquidation thresholds. risk-unit separately authenticates this contract's
;; contract-caller, so no circuit-breaker privilege is implied here.
(define-public (publish-system-risk (m <finance-metrics-trait>) (risk-module <risk-signal-publisher-trait>))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (some (contract-of risk-module)) (var-get risk-unit-contract)) ERR_UNAUTHORIZED)
    (match (contract-call? m get-protocol-gcr)
      gcr (let (
        (score (score-for-gcr gcr))
        (published-score (* score SYSTEM_SCORE_MULTIPLIER))
      )
        (begin
          (var-set current-risk-score score)
          (try! (contract-call? risk-module update-system-risk published-score))
          (print {
            event: "system-risk-published",
            source: (contract-of m),
            agent-score: score,
            system-score: published-score
          })
          (ok published-score)
        )
      )
      error (err error)
    )
  )
)

(define-public (set-risk-unit (new-risk-unit principal))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set risk-unit-contract (some new-risk-unit))
    (ok true)
  )
)

(define-read-only (get-risk-unit)
  (ok (var-get risk-unit-contract))
)

(define-read-only (get-published-risk-score)
  (ok (* (var-get current-risk-score) SYSTEM_SCORE_MULTIPLIER))
)

;; @desc Initializes the risk agent with a new administrator.
;; @param a principal
;; @return (ok bool)
(define-public (initialize (a principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin a)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Compatibility stub for GCR updates.
(define-public (set-mock-gcr (g uint)) (ok true))

;; @desc Compatibility stub for TVL updates.
(define-public (set-tvl (c uint) (p uint) (b uint)) (ok true))

;; @desc Compatibility stub for PID rate updates.
(define-public (update-pid-rates) (ok true))
