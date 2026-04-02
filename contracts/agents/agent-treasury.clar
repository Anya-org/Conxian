;; agent-treasury.clar
;; Compatibility shim: forward legacy `agent-treasury` entrypoints to
;; `fiscal-orchestrator`.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-public (run-fiscal-strategy (pools-to-reward (list 50 principal)) (cxd-token-trait <sip-010-trait>))
  (contract-call? .fiscal-orchestrator run-fiscal-strategy pools-to-reward cxd-token-trait)
)

(define-read-only (calculate-performance-adjustment)
  (contract-call? .fiscal-orchestrator calculate-performance-adjustment)
)

(define-read-only (calculate-cybernetic-policy)
  (contract-call? .fiscal-orchestrator calculate-cybernetic-policy)
)

(define-public (initialize (new-admin principal))
  (contract-call? .fiscal-orchestrator initialize new-admin)
)

(define-public (set-admin (new-admin principal))
  (contract-call? .fiscal-orchestrator set-admin new-admin)
)

(define-read-only (get-protocol-status)
  (contract-call? .fiscal-orchestrator get-protocol-status)
)
