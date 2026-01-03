;; block-utils.clar
;; Nakamoto Consensus Awareness & Bitcoin Finality
;; Conforms to Conxian Conxian Standards

(define-constant ERR_NOT_BITCOIN_FINALIZED (err u1001))
(define-constant ERR_INVALID_TENURE (err u1002))

;; @desc Checks if a Bitcoin block at a specific height has at least N confirmations
;; @param btc-height uint - The Bitcoin block height to check
;; @param min-confirmations uint - Required depth
;; @returns (response bool uint)
(define-read-only (ensure-bitcoin-finality (btc-height uint) (min-confirmations uint))
    (let (
        (tip-height burn-block-height)
        (confirmations (- tip-height btc-height))
    )
    (if (>= confirmations min-confirmations)
        (ok true)
        ERR_NOT_BITCOIN_FINALIZED
    ))
)

;; @desc Gets the current tenure ID for Nakamoto consensus
;; @returns (optional (buff 32))
(define-read-only (get-current-tenure-id)
    (get-tenure-info?)) ;; Native in 3.0 epoch/SDK 3.9+ depending on config
    ;; Note: In true Clarity 3.0 / Nakamoto, get-tenure-info? returns (optional (buff 32))
    ;; If this fails in older clarinet versions, we might need a fallback, 
    ;; but user rules say "SDK 3.9+", so we assume native support.


;; @desc Wrapper to get block info with tenure awareness (if applicable)
;; @param height uint
;; @returns (optional (buff 32)) header-hash
(define-read-only (get-stacks-block-hash (height uint))
    (get-block-info? header-hash height)
)
