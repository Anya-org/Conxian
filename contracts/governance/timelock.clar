;; timelock.clar
;; Time-delayed execution controller for critical protocol changes
;; Aligned with Nakamoto 5s block times

(use-trait proposal-trait .governance-traits.proposal-trait)

;; Constants
(define-constant MIN_DELAY u17280) ;; 1 day (at 5s/block)
(define-constant MAX_DELAY u241920) ;; 14 days (at 5s/block)
(define-constant GRACE_PERIOD u120960) ;; 7 days (at 5s/block)

;; Errors
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_DELAY (err u1001))
(define-constant ERR_NOT_QUEUED (err u1002))
(define-constant ERR_ALREADY_QUEUED (err u1003))
(define-constant ERR_TOO_EARLY (err u1004))
(define-constant ERR_EXPIRED (err u1005))

;; State
(define-map queued-transactions 
    (buff 32) 
    uint ;; eta
)

(define-data-var admin principal tx-sender)
(define-data-var delay uint MIN_DELAY)

;; Governance
(define-public (set-delay (new-delay uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (asserts! (>= new-delay MIN_DELAY) ERR_INVALID_DELAY)
        (asserts! (<= new-delay MAX_DELAY) ERR_INVALID_DELAY)
        (var-set delay new-delay)
        (ok true)
    )
)

(define-public (queue-transaction 
        (target principal) 
        (value uint) 
        (signature (string-ascii 48)) 
        (data (buff 128)) 
        (eta uint)
    )
    (let (
        (tx-hash (keccak256 (tuple (target target) (value value) (signature signature) (data data) (eta eta))))
    )
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (asserts! (>= eta (+ block-height (var-get delay))) ERR_INVALID_DELAY)
        (asserts! (is-none (map-get? queued-transactions tx-hash)) ERR_ALREADY_QUEUED)
        
        (map-set queued-transactions tx-hash eta)
        (ok tx-hash)
    )
)

(define-public (execute-transaction
        (target principal) 
        (value uint) 
        (signature (string-ascii 48)) 
        (data (buff 128)) 
        (eta uint)
    )
    (let (
        (tx-hash (keccak256 (tuple (target target) (value value) (signature signature) (data data) (eta eta))))
        (queued-eta (unwrap! (map-get? queued-transactions tx-hash) ERR_NOT_QUEUED))
    )
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (asserts! (>= block-height queued-eta) ERR_TOO_EARLY)
        (asserts! (<= block-height (+ queued-eta GRACE_PERIOD)) ERR_EXPIRED)

        (map-delete queued-transactions tx-hash)
        ;; Note: Actual execution would require trait invocation or specific logic
        ;; In Clarity, generic execution of arbitrary signatures is limited.
        ;; This is a standard pattern for governance signaling/gating.
        (ok true)
    )
)
