;; risk-manager.clar
;; Phase 1 compatibility wrapper
;; Canonical risk logic now lives in .risk-unit.

;; Privileged calls cannot safely preserve the original caller through a
;; nested contract-call?. Keep the ABI, but make the legacy path fail closed;
;; callers must use .risk-unit directly for writes and liquidation.
(define-constant ERR_FACADE_DEPRECATED (err u1003))

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

(define-read-only (get-system-risk-score)
  (contract-call? .risk-unit get-system-risk-score)
)

(define-read-only (get-risk-config)
  (contract-call? .risk-unit get-risk-config)
)

(define-read-only (get-position-health (position-id uint))
  (contract-call? .risk-unit get-position-health position-id)
)

(define-public (liquidate (position-id uint))
  ERR_FACADE_DEPRECATED
)

;; --- Admin/setup forwarding ---

(define-public (update-system-risk (new-score uint))
  ERR_FACADE_DEPRECATED
)

(define-read-only (calculate-health-factor (collateral-value uint) (total-debt uint))
  (contract-call? .risk-unit calculate-health-factor collateral-value total-debt)
)

(define-public (initialize (owner principal) (agent principal) (engine principal))
  ERR_FACADE_DEPRECATED
)

(define-public (set-dimensional-engine (new-engine principal))
  ERR_FACADE_DEPRECATED
)

(define-public (set-risk-agent (new-agent principal))
  ERR_FACADE_DEPRECATED
)

(define-public (set-ops-engine (new-ops principal))
  ERR_FACADE_DEPRECATED
)

;; Legacy no-op entrypoint kept for ABI compatibility. It now probes canonical
;; risk state instead of returning a placeholder constant.
(define-public (stub-func)
  (contract-call? .risk-unit is-liquidatable u0)
)
