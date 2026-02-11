;; ops-engine.clar
;; "The Executive Branch" - Coordinating the Sovereign Autonomous Business (SAB)
;; Clarity 2 Standard - Nakamoto-aligned

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)

;; State
(define-data-var last-action-time uint u0)
(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

;; Public Functions

(define-public (process-signal (proposal-id uint) (proposal-contract <proposal-trait>))
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u4)) (err ERR_UNAUTHORIZED)) ;; ROLE_OPERATOR
    (var-set last-action-time block-height)
    (contract-call? proposal-contract execute tx-sender)
  )
)

(define-public (trigger-emergency-pause)
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u4)) (err ERR_UNAUTHORIZED))
    (try! (contract-call? .conxian-protocol pause))
    (print { event: "emergency-pause-triggered", caller: tx-sender, block: burn-block-height })
    (ok true)
  )
)

(define-read-only (get-last-action)
  (var-get last-action-time)
)

;; @desc Trigger the Dual-Clock epoch update.
;; Fast Gear: Reflexes (DEX Fees) via Stacks block-height.
;; Slow Gear: Strategy (Fiscal Dam) via Bitcoin burn-block-height.
(define-public (trigger-epoch-update)
  (let (
    (current-stx-height block-height)
    (current-btc-height burn-block-height)
  )
    (begin
      ;; 1. FAST PATH CHECK (DEX Protection) - Updated every Stacks block
      (if (> current-stx-height (var-get last-fast-check))
        (begin
          (unwrap-panic (contract-call? .swap-router update-volatility-fees))
          (var-set last-fast-check current-stx-height)
        )
        false
      )

      ;; 2. SLOW PATH CHECK (Treasury/Risk) - Updated every Bitcoin block
      (if (> current-btc-height (var-get last-slow-check))
        (begin
          (unwrap-panic (contract-call? .agent-treasury run-fiscal-strategy))
          (unwrap-panic (contract-call? .agent-risk update-pid-rates))
          (var-set last-slow-check current-btc-height)
        )
        false
      )

      ;; 3. PAY KEEPER (5 CXD)
      (try! (contract-call? .cxd-token mint u500000000 tx-sender))

      (print {
        event: "epoch-updated",
        keeper: tx-sender,
        stx-height: current-stx-height,
        btc-height: current-btc-height
      })
      (ok true)
    )
  )
)
