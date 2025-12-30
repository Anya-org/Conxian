;; Nakamoto Constants
;; Core constants for Nakamoto upgrade and network parameters

;; Network Configuration
(define-constant NAKAMOTO_ACTIVATION_HEIGHT u840000)
(define-constant BLOCK_TIME_SECONDS u600) ;; 10 minutes
(define-constant EPOCH_LENGTH u2016) ;; ~2 weeks of blocks

;; Consensus Parameters
(define-constant MAX_BLOCK_SIZE u2097152) ;; 2MB
(define-constant TENURE_COST_LIMIT u10000000) ;; 10M
(define-constant SIGNER_THRESHOLD u70) ;; 70% threshold

;; Transaction Limits
(define-constant MAX_TX_SIZE u262144) ;; 256KB
(define-constant MIN_TX_FEE u1000)
(define-constant MAX_TX_FEE u100000000)

;; Stacking Parameters
(define-constant MIN_STACKING_AMOUNT u100000000) ;; 100 STX
(define-constant REWARD_CYCLE_LENGTH u2100)
(define-constant POX_PREPARE_LENGTH u100)

;; Read-only functions for accessing constants
(define-read-only (get-nakamoto-activation-height)
  NAKAMOTO_ACTIVATION_HEIGHT
)

(define-read-only (is-nakamoto-active (height uint))
  (>= height NAKAMOTO_ACTIVATION_HEIGHT)
)

(define-read-only (get-block-time)
  BLOCK_TIME_SECONDS
)

(define-read-only (get-epoch-length)
  EPOCH_LENGTH
)
