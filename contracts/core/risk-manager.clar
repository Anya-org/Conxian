;; risk-manager.clar
;; Phase 1 compatibility wrapper
;; Canonical risk logic now lives in .risk-unit.

;; --- Core compatibility surface ---

(define-public (get-health-factor (position-id uint))
  (contract-call? .risk-unit get-health-factor position-id)
)

(define-read-only (get-health-factor-read-only (position-id uint))
  (contract-call? .risk-unit get-health-factor-read-only position-id)
)

(define-read-only (is-liquidatable (position-id uint))
  (contract-call? .risk-unit is-liquidatable position-id)
)

(define-public (liquidate (position-id uint))
  (contract-call? .risk-unit liquidate position-id)
)

;; --- Admin/setup forwarding ---

(define-public (update-system-risk (new-score uint))
  (contract-call? .risk-unit update-system-risk new-score)
)

(define-read-only (calculate-health-factor (collateral-value uint) (total-debt uint))
  (contract-call? .risk-unit calculate-health-factor collateral-value total-debt)
)

(define-public (initialize (owner principal) (agent principal) (engine principal))
  (contract-call? .risk-unit initialize owner agent engine)
)

(define-public (set-dimensional-engine (new-engine principal))
  (contract-call? .risk-unit set-dimensional-engine new-engine)
)

(define-public (set-risk-agent (new-agent principal))
  (contract-call? .risk-unit set-risk-agent new-agent)
)

(define-public (set-ops-engine (new-ops principal))
  (contract-call? .risk-unit set-ops-engine new-ops)
)

;; Legacy no-op entrypoint kept for ABI compatibility.
;; It now probes canonical risk state instead of returning a placeholder constant.
(define-public (stub-func)
  (contract-call? .risk-unit is-liquidatable u0)
)
