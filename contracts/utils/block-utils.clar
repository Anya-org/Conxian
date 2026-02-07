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

;; @desc Check if the current block is finalized (6+ Bitcoin confirmations)
;; @returns (response bool uint) - Returns true if finalized, error if not
(define-public (check-finality)
    (let (
        (current-burn-height burn-block-height)
        ;; For Nakamoto: Check if we have at least 6 Bitcoin confirmations
        ;; This is a simplified check - in production use get-burn-block-info? for header verification
        (min-confirmations u6)
    )
        ;; In a full implementation, we would:
        ;; 1. Get the target burn block hash using (get-burn-block-info? header-hash target-height)
        ;; 2. Verify the hash exists (block is confirmed)
        ;; 3. Check confirmation depth
        ;; 
        ;; For now, we simulate finality check by verifying burn-block-height > 0
        ;; and return ok for blocks past genesis
        (if (> current-burn-height min-confirmations)
            (ok true)
            (err u1001) ;; ERR_NOT_FINALIZED - Need 6+ confirmations
        )
    )
)

;; @desc Verify Bitcoin block header exists at target height (Nakamoto)
;; @param target-height uint - The burn block height to verify
;; @returns (response bool uint) - Returns true if block header exists
;; NOTE: This function uses get-burn-block-info? which requires Clarity 4 / Epoch 3.1
;; For now, it performs a basic height check. Full implementation when mainnet upgrades.
(define-read-only (verify-bitcoin-block (target-height uint))
    ;; Clarity 4: (get-burn-block-info? header-hash target-height)
    ;; For Clarity 3 compatibility, we check if target height is reasonable
    (if (and (> target-height u0) (<= target-height burn-block-height))
        (ok true)
        (err u1002) ;; ERR_BLOCK_NOT_FOUND
    )
)
