;; ops-engine.clar
;; "The Executive Branch" - Coordinating the Sovereign Autonomous Business (SAB)
;; Fully Optimized Dual-Clock Standard - Nakamoto Aligned

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_EXECUTION_FAILED u6001)
(define-constant ERR_NO_WORK_NEEDED u101)

;; State (using block-height for Tenure-Clock precision)
(define-data-var last-action-time uint u0)
(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

;; Public Functions

;; @desc Processes a governance signal by executing a proposal contract.
;; @param proposal-id uint - The ID of the proposal.
;; @param proposal-contract <proposal-trait> - The proposal contract to execute.
;; @returns (response bool uint)
(define-public (process-signal (proposal-id uint) (proposal-contract <proposal-trait>))
  (begin
    (asserts! (is-eq (contract-call? .admin-facade is-authorized u4) (ok true)) (err ERR_UNAUTHORIZED)) ;; ROLE_OPERATOR
    (var-set last-action-time block-height)
    (contract-call? proposal-contract execute tx-sender)
  )
)

;; @desc Triggers a protocol-wide emergency pause.
;; @returns (response bool uint)
(define-public (trigger-emergency-pause)
  (begin
    (asserts! (is-eq (contract-call? .admin-facade is-authorized u4) (ok true)) (err ERR_UNAUTHORIZED))
    (try! (contract-call? .conxian-protocol pause))
    (print { event: "emergency-pause-triggered", caller: tx-sender, timestamp: block-height })
    (ok true)
  )
)

;; @desc Returns the timestamp of the last executive action.
;; @returns (response uint uint)
(define-read-only (get-last-action)
  (ok (var-get last-action-time))
)

;; @desc Trigger the Dual-Clock epoch update.
;; Fast Gear: Reflexes (DEX Fees) via block-height (target ~1 block).
;; Slow Gear: Strategy (Fiscal Dam) via block-height (target ~10 blocks).
(define-public (trigger-epoch-update)
  (let (
    (current-time block-height)
    (work-done-fast (>= (- current-time (var-get last-fast-check)) u60))
    (work-done-slow (>= (- current-time (var-get last-slow-check)) u600))
  )
    (begin
      ;; Ensure at least one gear needs updating
      (asserts! (or work-done-fast work-done-slow) (err ERR_NO_WORK_NEEDED))

      ;; 1. FAST PATH CHECK (DEX Protection)
      (if work-done-fast
        (begin
          (try! (contract-call? .swap-router update-volatility-fees))
          (var-set last-fast-check current-time)
        )
        false
      )

      ;; 2. SLOW PATH CHECK (Treasury/Risk)
      (if work-done-slow
        (begin
          (try! (contract-call? .agent-treasury run-fiscal-strategy))
          (try! (contract-call? .agent-risk update-pid-rates))
          (var-set last-slow-check current-time)
        )
        false
      )

      ;; 3. PAY KEEPER (5 CXD) - Incentive for triggering automation
      (try! (contract-call? .cxd-token mint u500000000 tx-sender))

      (print {
        event: "epoch-updated",
        keeper: tx-sender,
        timestamp: current-time
      })
      (ok true)
    )
  )
)

;; Compliance

;; @desc Returns the current operational status of the heartbeat engine.
;; @returns (response {fast-gear: uint, slow-gear: uint, active: bool} uint)
(define-read-only (get-engine-status)
  (ok {
    fast-gear: (var-get last-fast-check),
    slow-gear: (var-get last-slow-check),
    active: true
  })
)
