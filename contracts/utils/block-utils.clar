;; block-utils.clar
;; Block & Tenure Utilities
;; Provides abstraction for temporal logic to support both current SDK and Nakamoto

;; Constants
(define-constant BLOCKS_PER_TENURE u10)

;; Read-only: Get Current Tenure ID
(define-read-only (get-current-tenure-id)
  (/ block-height BLOCKS_PER_TENURE)
)

;; Read-only: Get Current Stacks Block Height
(define-read-only (get-stacks-block-height)
  block-height
)

;; Read-only: Get Current Stacks Block Time
(define-read-only (get-stacks-block-time)
  burn-block-height
)

;; Read-only: Get Bitcoin Burn Block Height
(define-read-only (get-burn-block-height)
  burn-block-height
)

;; Read-only: Get Tenure Info
(define-read-only (get-tenure-info)
    (ok {
        tenure-id: (get-current-tenure-id),
        stacks-height: block-height,
        burn-height: burn-block-height
    })
)

;; @desc Check if the current block is finalized
(define-public (check-finality)
    (if (> burn-block-height u6)
        (ok true)
        (err u1001)
    )
)
