;; nakamoto-constants.clar
;; Standardized time constants for Stacks Nakamoto (5s blocks)
;; Used across the Conxian ecosystem for unified time calculation

(define-constant BLOCK_TIME_SECONDS u5)
(define-constant BLOCKS_PER_MINUTE u12)
(define-constant BLOCKS_PER_HOUR u720)
(define-constant BLOCKS_PER_DAY u17280)
(define-constant BLOCKS_PER_WEEK u120960)
(define-constant BLOCKS_PER_MONTH u518400) ;; 30 days
(define-constant BLOCKS_PER_YEAR u6307200) ;; 365 days

;; Protocol Specific Time Windows
(define-constant EPOCH_LENGTH u518400) ;; 30 days (1 Month)
(define-constant VESTING_CLIFF u518400) ;; 1 Month
(define-constant TIMELOCK_DELAY u241920) ;; 2 Weeks
(define-constant EMERGENCY_TIMELOCK u17280) ;; 1 Day
(define-constant STAKING_CYCLE u24192) ;; ~2 weeks (aligned with PoX cycle approx)

(define-read-only (get-blocks-per-year)
    BLOCKS_PER_YEAR
)

(define-read-only (get-epoch-length)
    EPOCH_LENGTH
)
