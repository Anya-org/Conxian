;; fiscal-orchestrator.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Canonical treasury-control implementation (Phase 1)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait finance-metrics-trait .security-monitoring.finance-metrics-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_RISK_SIGNAL_UNAVAILABLE (err u2001))
(define-constant ERR_FISCAL_EXECUTION_FAILED (err u2002))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)

;; --- Internal Policy Helpers ---

(define-private (resolve-cybernetic-policy (gcr uint))
  (if (< gcr u110)
    ;; CRISIS Mode
    {
      treasury: u0,
      bounty: u0,
      lp: u0,
      grant: u0,
      buyback: u0,
      insurance: u10000
    }
    (if (< gcr u150)
      ;; STABILITY Mode
      {
        treasury: u4500,
        bounty: u3000,
        lp: u1500,
        grant: u500,
        buyback: u500,
        insurance: u0
      }
      ;; ABUNDANCE Mode
      {
        treasury: u1000,
        bounty: u0,
        lp: u8000,
        grant: u0,
        buyback: u0,
        insurance: u1000
      }
    )
  )
)

;; --- Public Functions ---

;; @desc Run the fiscal strategy - Orchestrates fee collection and BME epoch routing.
;; @param pools-to-reward (list 50 principal)
;; @param cxd-token-trait <sip-010-ft-trait>
;; @param metrics-ref <finance-metrics-trait>
;; @return (ok bool)
(define-public (run-fiscal-strategy (pools-to-reward (list 50 principal)) (cxd-token-trait <sip-010-ft-trait>) (metrics-ref <finance-metrics-trait>))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel metrics-ref) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    (begin
      ;; 1. Collect protocol fees from core modules
      (unwrap! (contract-call? .concentrated-liquidity-pool collect-protocol-fees cxd-token-trait) ERR_FISCAL_EXECUTION_FAILED)

      ;; 2. Trigger BME epoch minting
      (match (contract-call? .bme-engine execute-epoch-minting pools-to-reward)
        res (begin
          (print {
            event: "bme-epoch-minted",
            success: true,
            risk-score: (get risk-score intel),
            gcr: (get financial-gcr intel)
          })
          true
        )
        err-val (begin
          (print {
            event: "bme-epoch-skipped",
            reason: err-val,
            risk-score: (get risk-score intel),
            gcr: (get financial-gcr intel)
          })
          false
        )
      )

      (ok true)
    )
  )
)

;; @desc Calculates performance-based adjustment for bounty (CXIP-013).
;; @param metrics-ref <finance-metrics-trait>
;; @return (ok uint)
(define-public (calculate-performance-adjustment (metrics-ref <finance-metrics-trait>))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel metrics-ref) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    (ok (if (< (get risk-score intel) u1000) u500 u0))
  )
)

;; @desc Calculates dynamic allocation policy based on GCR (CXIP-013).
;; @param metrics-ref <finance-metrics-trait>
;; @return (ok { treasury: uint, bounty: uint, lp: uint, grant: uint, buyback: uint, insurance: uint })
(define-public (calculate-cybernetic-policy (metrics-ref <finance-metrics-trait>))
  (let (
    (gcr (unwrap! (contract-call? .agent-risk get-gcr metrics-ref) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    (ok (resolve-cybernetic-policy gcr))
  )
)

;; @desc Initializes the fiscal orchestrator with an administrator.
;; @param new-admin principal
;; @return (ok bool)
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (not (var-get initialized))) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Updates the administrator principal.
;; @param new-admin principal
;; @return (ok bool)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Returns the current status and version of the fiscal orchestrator.
;; @return (ok { compliant: bool, version: (string-ascii 20) })
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex" })
)

;; @desc Returns whether the sender is the current administrator.
;; @return bool
(define-read-only (is-authorized-admin)
  (or (is-eq tx-sender (var-get admin)) (not (var-get initialized)))
)
