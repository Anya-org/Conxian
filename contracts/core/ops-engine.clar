;; ops-engine.clar - Nakamoto-Aligned Heartbeat
(use-trait dex-router-trait .defi-traits.dex-router-trait)
(use-trait strategy-trait .conxian-service-trait.strategy-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NO_WORK_NEEDED (err u6001))

(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

(define-data-var admin principal tx-sender)

;; @desc Trigger updates using injected traits (Preferred for Simulation)
(define-public (trigger-epoch-update-dynamic (router <dex-router-trait>) (strategy <strategy-trait>))
  (let (
    (current-time burn-block-height)
    (work-done-fast (>= (- current-time (var-get last-fast-check)) u1))
    (work-done-slow (>= (- current-time (var-get last-slow-check)) u1))
  )
    (begin
      (if work-done-fast
        (begin
          (match (contract-call? router update-volatility-fees)
            res (var-set last-fast-check current-time)
            err-val false
          )
          (ok true)
        )
        (if work-done-slow
          (begin
            (match (contract-call? strategy run-fiscal-strategy)
              res (var-set last-slow-check current-time)
              err-val false
            )
            (ok true)
          )
          ERR_NO_WORK_NEEDED
        )
      )
    )
  )
)

;; @desc Full system heartbeat
(define-public (trigger-epoch-update)
  (let (
    (current-time burn-block-height)
  )
    (begin
      ;; Fast reflexes: Update DEX volatility fees
      (match (contract-call? .swap-router update-volatility-fees)
        res (var-set last-fast-check current-time)
        err-val false
      )
      ;; Slow path: Run fiscal strategy (Fiscal Dam)
      (match (contract-call? .agent-treasury run-fiscal-strategy)
        res (var-set last-slow-check current-time)
        err-val false
      )
      (ok true)
    )
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
  (ok { compliant: true, paused: false, tenure-id: (some (/ block-height u10)), timestamp: burn-block-height, version: "07" })
)
