;; ops-engine.clar
;; "The Executive Branch" - Coordinating the Sovereign Autonomous Business (SAB)
;; Clarity 4 Standard - Nakamoto-aligned with stacks-block-time

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)

(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

;; State
(define-data-var last-action-time uint u0)

;; Public Functions

(define-public (process-signal (proposal-id uint) (proposal-contract <proposal-trait>))
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u4)) (err ERR_UNAUTHORIZED)) ;; ROLE_OPERATOR
    (var-set last-action-time stacks-block-time)
    (contract-call? proposal-contract execute tx-sender)
  )
)

(define-read-only (get-last-action)
  (var-get last-action-time)
)

(define-public (trigger-epoch-update)
  (let (
    (current-time stacks-block-time)
    (current-stx-height stacks-block-height)
  )
    (begin
      ;; 1. FAST PATH CHECK (DEX Protection) - Updated every ~1 minute (60s)
      (if (> (- current-time (var-get last-fast-check)) u60)
        (begin
          (unwrap-panic (contract-call? .swap-router update-volatility-fees))
          (var-set last-fast-check current-time)
        )
        false
      )

      ;; 2. SLOW PATH CHECK (Treasury/Risk) - Updated every ~10 minutes (600s)
      (if (> (- current-time (var-get last-slow-check)) u600)
        (begin
          (unwrap-panic (contract-call? .agent-treasury apply-fiscal-dam))
          (unwrap-panic (contract-call? .agent-risk update-pid-rates))
          (var-set last-slow-check current-time)
        )
        false
      )

      ;; 3. PAY KEEPER
      (contract-call? .cxd-token mint u5000000 tx-sender)
    )
  )
)
