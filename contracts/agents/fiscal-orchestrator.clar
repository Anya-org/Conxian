;; fiscal-orchestrator.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Canonical treasury-control implementation (Phase 1)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_RISK_SIGNAL_UNAVAILABLE (err u2001))
(define-constant ERR_FISCAL_EXECUTION_FAILED (err u2002))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)

;; --- Authorization ---

(define-read-only (is-authorized-admin)
  (or (is-eq tx-sender (var-get admin)) (not (var-get initialized)))
)

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

(define-private (compute-performance-adjustment)
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    ;; Compatibility-first logic: grant uplift while risk score remains below stress band.
    (ok (if (< (get risk-score intel) u1000) u500 u0))
  )
)

(define-private (compute-cybernetic-policy)
  (let (
    (gcr (unwrap! (contract-call? .agent-risk get-gcr) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    (ok (resolve-cybernetic-policy gcr))
  )
)

;; --- Public Functions ---

;; @desc Run the fiscal strategy - Orchestrates fee collection and BME epoch routing.
;; @param metrics-ref: retained for compatibility-first ABI stability.
(define-public (run-fiscal-strategy (pools-to-reward (list 50 principal)) (cxd-token-trait <sip-010-ft-trait>) (metrics-ref principal))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) ERR_RISK_SIGNAL_UNAVAILABLE))
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
            gcr: (get financial-gcr intel),
            metrics-ref: metrics-ref
          })
          true
        )
        err-val (begin
          (print {
            event: "bme-epoch-skipped",
            reason: err-val,
            risk-score: (get risk-score intel),
            gcr: (get financial-gcr intel),
            metrics-ref: metrics-ref
          })
          false
        )
      )

      (ok true)
    )
  )
)

;; @desc Calculates performance-based adjustment for bounty (CXIP-013)
;; @param metrics-ref: retained for compatibility-first ABI stability.
(define-public (calculate-performance-adjustment (metrics-ref principal))
  (compute-performance-adjustment)
)

;; @desc Read-only compatibility endpoint for wrappers that cannot call public fns.
(define-read-only (calculate-performance-adjustment-read-only (metrics-ref principal))
  (compute-performance-adjustment)
)

;; @desc Calculates dynamic allocation policy based on GCR (CXIP-013)
;; @param metrics-ref: retained for compatibility-first ABI stability.
(define-public (calculate-cybernetic-policy (metrics-ref principal))
  (compute-cybernetic-policy)
)

;; @desc Read-only compatibility endpoint for wrappers that cannot call public fns.
(define-read-only (calculate-cybernetic-policy-read-only (metrics-ref principal))
  (compute-cybernetic-policy)
)

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex" })
)
