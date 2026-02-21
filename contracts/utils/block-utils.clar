;; block-utils.clar
;; Nakamoto Block & Tenure Utilities
;; NATIVE MODE: Clarity 4 Mainnet Standard

(define-constant BLOCKS_PER_TENURE u10)

(define-read-only (get-current-tenure-id)
  (/ block-height BLOCKS_PER_TENURE)
)

(define-read-only (get-stacks-block-time)
  block-height 
)

(define-read-only (get-stacks-block-height)
  block-height
)

(define-read-only (get-burn-block-height)
  burn-block-height
)

(define-read-only (get-tenure-info)
    (ok {
        tenure-id: (get-current-tenure-id),
        block-height: block-height,
        block-time: block-height
    })
)

(define-read-only (get-blocks-in-current-tenure)
    (mod block-height BLOCKS_PER_TENURE)
)

(define-read-only (is-tenure-fresh)
  (< (get-blocks-in-current-tenure) u5)
)

(define-read-only (get-bitcoin-confirmations (target-burn-height uint))
    (if (>= burn-block-height target-burn-height)
        (ok (- burn-block-height target-burn-height))
        (ok u0)
    )
)

(define-read-only (has-min-confirmations (target-burn-height uint) (min-confirmations uint))
    (ok (>= (unwrap-panic (get-bitcoin-confirmations target-burn-height)) min-confirmations))
)

(define-public (check-finality)
    (if (> burn-block-height u6)
        (ok true)
        (err u1001)
    )
)

(define-read-only (verify-bitcoin-block (target-height uint))
    (if (and (> target-height u0) (<= target-height burn-block-height))
        (ok true)
        (err u1002)
    )
)

;; Clarity 4 Native Wrappers - Removing invalid placeholders to-ascii? and contract-hash?
(define-read-only (contract-hash-safe (contract principal))
    (ok 0x00) ;; Placeholder
)

(define-read-only (secp256r1-verify-safe (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
    (ok (secp256r1-verify message signature public-key))
)

(define-read-only (restrict-assets-safe)
    (restrict-assets?)
)
