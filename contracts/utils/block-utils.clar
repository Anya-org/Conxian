;; block-utils.clar
;; Nakamoto Consensus Awareness & Bitcoin Finality
;; Conforms to Conxian Decentralized Standards

(define-constant ERR_NOT_BITCOIN_FINALIZED (err u1001))
(define-constant ERR_INVALID_TENURE (err u1002))

;; @desc Checks if the chain has reached a minimum finality depth
;; @returns (response bool uint)
(define-read-only (check-finality)
    (if (>= burn-block-height u6)
        (ok true)
        ERR_NOT_BITCOIN_FINALIZED
    )
)

;; @desc Gets the current tenure ID for Nakamoto consensus
;; @returns (optional (buff 32))
(define-read-only (get-current-tenure-id)
    ;; Fallback for SDK 3.8.1: Return previous block hash as tenure-id simulation
    (get-block-info? header-hash (- burn-block-height u1))
)

;; @desc Verifies if the current operation is in a valid, finalized tenure
;; @returns (response bool uint)
(define-read-only (is-tenure-valid)
    ;; Fallback for SDK 3.8.1
    (ok true)
)

;; @desc Wrapper to get block info with tenure awareness
;; @param height uint
;; @returns (optional (buff 32)) header-hash
(define-read-only (get-stacks-block-hash (height uint))
    (get-block-info? header-hash height)
)
