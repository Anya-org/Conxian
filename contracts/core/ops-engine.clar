;; ops-engine.clar
;; "The Executive Branch" - Coordinating the Sovereign Autonomous Business (SAB)
;; Clarity 3 Standard - Nakamoto-aligned

(use-trait proposal-trait .governance-traits.proposal-trait)
(use-trait ops-agent .automation-traits.ops-agent-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)

;; State
(define-data-var last-action-time uint u0)
(define-data-var last-fast-check uint u0)
(define-data-var last-slow-check uint u0)

;; Public Functions

(define-public (process-signal (proposal-id uint) (proposal-contract <proposal-trait>))
  (begin
    (asserts! (unwrap-panic (contract-call? .admin-facade is-authorized u4)) (err ERR_UNAUTHORIZED))
    (var-set last-action-time (contract-call? .block-utils get-burn-block-height))
    (contract-call? proposal-contract execute tx-sender)
  )
)

;; @desc Trigger the Dual-Clock epoch update.
(define-public (trigger-epoch-update (router <ops-agent>) (treasury <ops-agent>) (risk <ops-agent>))
  (let (
    (current-time (contract-call? .block-utils get-burn-block-height))
  )
    (begin
      ;; 1. FAST PATH CHECK - Updated every ~1 minute (60s)
      (if (> (- current-time (var-get last-fast-check)) u60)
        (begin
          (try! (contract-call? router update-volatility-fees))
          (var-set last-fast-check current-time)
        )
        false
      )

      ;; 2. SLOW PATH CHECK - Updated every ~10 minutes (600s)
      (if (> (- current-time (var-get last-slow-check)) u600)
        (begin
          (try! (contract-call? treasury run-fiscal-strategy))
          (try! (contract-call? risk update-pid-rates))
          (var-set last-slow-check current-time)
        )
        false
      )

      ;; 3. PAY KEEPER (5 CXD)
      (try! (contract-call? .cxd-token mint u500000000 tx-sender))
      (ok true)
    )
  )
)
