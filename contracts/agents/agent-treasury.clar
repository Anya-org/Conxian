;; agent-treasury.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Upgraded for Sovereign BME Orchestration

(define-data-var admin principal tx-sender)

;; @desc Run the fiscal strategy - Orchestrates BME epoch and buy-backs
(define-public (run-fiscal-strategy (pools-to-reward (list 50 principal)))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) (err u2001)))
    (risk-score (get risk-score intel))
  )
    (begin
      ;; 1. Collect protocol fees from core modules
      (try! (contract-call? .concentrated-liquidity-pool collect-protocol-fees .cxd-token))

      ;; 2. Trigger BME epoch minting
      (match (contract-call? .bme-engine execute-epoch-minting pools-to-reward)
        res (print { event: "bme-epoch-minted", success: true })
        err-val (print { event: "bme-epoch-skipped", reason: err-val })
      )

      (ok true)
    )
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))
    (var-set admin new-admin)
    (ok true)
  )
)
