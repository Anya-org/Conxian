;; yield-optimizer.clar
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait vault-trait .vault-trait.vault-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_STRATEGY_NOT_FOUND (err u1001))
(define-constant ERR_RISK_TOO_HIGH (err u1002))

(define-data-var admin principal tx-sender)
(define-data-var max-risk-threshold uint u500)

(define-map strategies
  principal
  {
    risk-score: uint, active: bool
  }
)

(define-public (autonomous-rebalance (vault-from <vault-trait>) (vault-to <vault-trait>) (amount uint) (token <sip-010-ft-trait>))
  (let (
    (system-risk (unwrap-panic (contract-call? .agent-risk get-gcr)))
    (target-strat (unwrap! (map-get? strategies (contract-of vault-to)) (err ERR_STRATEGY_NOT_FOUND)))
  )
    (begin
      (asserts! (or
        (> system-risk u150)
        (<= (get risk-score target-strat) (var-get max-risk-threshold))
      ) (err ERR_RISK_TOO_HIGH))
      (ok true)
    )
  )
)

(define-public (set-strategy (vault principal) (risk uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set strategies vault { risk-score: risk, active: true })
    (ok true)
  )
)
