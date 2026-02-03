;; ops-engine.clar
;; "The Executive Branch" - Coordinating the Sovereign Autonomous Business (SAB)
;; Nakamoto-aligned with burn-block-height

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)

(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

;; State
(define-data-var last-action-block uint u0)

;; Public Functions

(define-public (process-signal (proposal-id uint) (proposal-contract <proposal-trait>))
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u4)) (err ERR_UNAUTHORIZED)) ;; ROLE_OPERATOR
    (var-set last-action-block burn-block-height)
    (contract-call? proposal-contract execute tx-sender)
  )
)

(define-read-only (get-last-action)
  (var-get last-action-block)
)

(define-public (trigger-epoch-update)
  (let (
    (current-stx-height block-height)
    (current-btc-height burn-block-height)
  )
    (begin
      ;; 1. FAST PATH CHECK (DEX Protection)
      (if (> (- current-stx-height (var-get last-fast-check)) u10)
        (begin
          (unwrap-panic (contract-call? .swap-router update-volatility-fees))
          (var-set last-fast-check current-stx-height)
        )
        false
      )

      ;; 2. SLOW PATH CHECK (Treasury/Risk)
      (if (> current-btc-height (var-get last-slow-check))
        (begin
          (unwrap-panic (contract-call? .agent-treasury apply-fiscal-dam))
          (unwrap-panic (contract-call? .agent-risk update-pid-rates))
          (var-set last-slow-check current-btc-height)
        )
        false
      )

      ;; 3. PAY KEEPER
      (contract-call? .cxd-token mint u5000000 tx-sender)
    )
  )
)
