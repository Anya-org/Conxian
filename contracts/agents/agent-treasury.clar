;; agent-treasury.clar
;; Compatibility treasury controller for legacy callers.
;; Mirrors canonical fiscal-orchestrator policy logic (Phase 1 cutover).

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait csf-trait .conxian-csf-trait.trait-csf-liquidity-v1)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_RISK_SIGNAL_UNAVAILABLE (err u2001))
(define-constant ERR_FISCAL_EXECUTION_FAILED (err u2002))

(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)

(define-private (is-authorized-admin)
  (or (is-eq tx-sender (var-get admin)) (not (var-get initialized)))
)

(define-private (resolve-cybernetic-policy (gcr uint))
  (if (< gcr u110)
    {
      treasury: u0,
      bounty: u0,
      lp: u0,
      grant: u0,
      buyback: u0,
      insurance: u10000
    }
    (if (< gcr u150)
      {
        treasury: u4500,
        bounty: u3000,
        lp: u1500,
        grant: u500,
        buyback: u500,
        insurance: u0
      }
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

;; @desc Executes the compatibility fiscal strategy across designated pools.
;; @param pool-trait retained for backward compatibility with legacy callers.
(define-public (run-fiscal-strategy (pool-trait <csf-trait>) (pools-to-reward (list 50 principal)) (cxd-token-trait <sip-010-ft-trait>))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) ERR_RISK_SIGNAL_UNAVAILABLE))
  )
    (begin
      (unwrap! (contract-call? .concentrated-liquidity-pool collect-protocol-fees cxd-token-trait) ERR_FISCAL_EXECUTION_FAILED)

      (match (contract-call? .bme-engine execute-epoch-minting pools-to-reward)
        res (begin
          (print {
            event: "compat-fiscal-epoch-minted",
            success: true,
            risk-score: (get risk-score intel),
            gcr: (get financial-gcr intel)
          })
          true
        )
        err-val (begin
          (print {
            event: "compat-fiscal-epoch-skipped",
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

;; @desc Calculates the performance-based adjustment for fiscal policy.
(define-read-only (calculate-performance-adjustment)
  (compute-performance-adjustment)
)

;; @desc Calculates the cybernetic fiscal policy based on current system state.
(define-read-only (calculate-cybernetic-policy)
  (compute-cybernetic-policy)
)

;; @desc Initializes the treasury compatibility controller with an administrator.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Updates the administrator principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Returns the current status and version of the treasury compatibility controller.
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex-Compat" })
)
