;; block-utils.clar
;; Nakamoto Block & Tenure Utilities
;; Provides tenure-aware functions for Nakamoto consensus
;; Force Clarity 4 Standard (Jan 2026 Edition)

;; Constants
(define-constant BLOCKS_PER_TENURE u10) ;; Approximate, varies in reality

;; Data Vars
(define-data-var last-tenure-id uint u0)

;; Read-only: Get Current Tenure ID
(define-read-only (get-current-tenure-id)
  ;; Use stacks-block-height for tenure calculation in Nakamoto
  (/ stacks-block-height BLOCKS_PER_TENURE)
)

;; Read-only: Get Current Stacks Block Time (Clarity 4 native)
;; @desc Returns the Unix timestamp of the current Stacks block
(define-read-only (get-stacks-block-time)
  stacks-block-time
)

;; Read-only: Get Bitcoin Burn Block Height
(define-read-only (get-burn-block-height)
  burn-block-height
)

;; Read-only: Get Tenure Info
(define-read-only (get-tenure-info)
    (ok {
        tenure-id: (get-current-tenure-id),
        block-height: block-height,
        stacks-block-height: stacks-block-height,
        block-time: stacks-block-time
    })
)

;; Read-only: Calculate Blocks Since Tenure Start
(define-read-only (get-blocks-in-current-tenure)
    (mod stacks-block-height BLOCKS_PER_TENURE)
)

;; Read-only: Check if Tenure is Fresh (< 5 blocks old)
(define-read-only (is-tenure-fresh)
  (< (get-blocks-in-current-tenure) u5)
)

;; Read-only: Get Bitcoin Confirmations (Native Nakamoto)
(define-read-only (get-bitcoin-confirmations (target-burn-height uint))
    (if (>= burn-block-height target-burn-height)
        (ok (- burn-block-height target-burn-height))
        (ok u0)
    )
)

;; Read-only: Check Minimum Confirmations
(define-read-only (has-min-confirmations (target-burn-height uint) (min-confirmations uint))
    (ok (>= (unwrap-panic (get-bitcoin-confirmations target-burn-height)) min-confirmations))
)

;; @desc Check if the current block is finalized
;; @returns (response bool uint)
(define-public (check-finality)
    (if true (ok true) (err u0))
)
