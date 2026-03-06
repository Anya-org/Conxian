;; ops-engine.clar - Refined for Type Safety
(define-constant ERR_NO_WORK_NEEDED (err u6001))

(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

(define-public (trigger-epoch-update)
  (let (
    (current-time burn-block-height)
    (work-done-fast (>= (- current-time (var-get last-fast-check)) u60))
    (work-done-slow (>= (- current-time (var-get last-slow-check)) u144))
  )
    (begin
      ;; Type-explicit response handling
      (if work-done-fast
        (begin
          (match (contract-call? .swap-router update-volatility-fees)
            res (var-set last-fast-check current-time)
            err-val false
          )
          (ok true)
        )
        (if work-done-slow
          (begin
            (match (contract-call? .agent-treasury run-fiscal-strategy)
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
