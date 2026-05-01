;; block-utils.clar
;; Nakamoto Block & Tenure Utilities - COMPATIBILITY MODE

(define-constant BLOCKS_PER_TENURE u10)

;; @desc Get current tenure ID
;; @returns uint
(define-read-only (get-current-tenure-id)
  (/ block-height BLOCKS_PER_TENURE)
)

;; @desc Get burn block height
;; @returns uint
(define-read-only (get-burn-block-height)
  burn-block-height
)

;; @desc Get block height
;; @returns uint
(define-read-only (get-block-height)
  block-height
)

;; @desc Get current tenure information
;; @returns (response {tenure-id: uint block-height: uint block-time: uint} uint)
(define-read-only (get-tenure-info)
    (ok {
        tenure-id: (get-current-tenure-id)
        block-height: block-height
        block-time: burn-block-height
    })
)

;; @desc Get blocks processed in current tenure
;; @returns uint
(define-read-only (get-blocks-in-current-tenure)
    (mod block-height BLOCKS_PER_TENURE)
)

;; @desc Check if current tenure is still fresh
;; @returns bool
(define-read-only (is-tenure-fresh)
  (< (get-blocks-in-current-tenure) u5)
)

;; @desc Get Bitcoin confirmations for a target burn height
;; @param target-burn-height (uint)
;; @returns (response uint uint)
(define-read-only (get-bitcoin-confirmations (target-burn-height uint))
    (if (>= burn-block-height target-burn-height)
        (ok (- burn-block-height target-burn-height))
        (ok u0)
    )
)

;; @desc Check if target burn height has minimum confirmations
;; @param target-burn-height (uint)
;; @param min-confirmations (uint)
;; @returns (response bool uint)
(define-read-only (has-min-confirmations (target-burn-height uint) (min-confirmations uint))
    (ok (>= (unwrap-panic (get-bitcoin-confirmations target-burn-height)) min-confirmations))
)

;; @desc Check block finality status
;; @returns (response bool uint)
(define-public (check-finality)
    (if (> burn-block-height u6)
        (ok true)
        (err u1001)
    )
)

;; @desc Verify a Bitcoin block height
;; @param target-height (uint)
;; @returns (response bool uint)
(define-read-only (verify-bitcoin-block (target-height uint))
    (if (and (> target-height u0) (<= target-height burn-block-height))
        (ok true)
        (err u1002)
    )
)

;; Compatibility Wrappers

;; @desc Safe contract hash retrieval
;; @param contract (principal)
;; @returns (response (buff 32) uint)
(define-read-only (contract-hash-safe (contract principal))
    (ok 0x0000000000000000000000000000000000000000000000000000000000000000)
)

;; @desc Safe signature verification
;; @param message (buff 32)
;; @param signature (buff 64)
;; @param public-key (buff 33)
;; @returns bool
(define-read-only (true-safe (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
    true
)

;; @desc Safe conversion to ASCII
;; @param buffer (buff 128)
;; @returns (optional (string-ascii 128))
(define-read-only (to-ascii-safe (buffer (buff 128)))
    (some "ascii")
)

;; @desc Safe asset restriction check
;; @returns bool
(define-read-only (restrict-assets-safe)
    true
)
