;; halving.clar
;; @desc Bitcoin-Style Halving mechanism for Conxian fee contracts.
;; Halves the reward every 210,000 blocks (approximately every 4 years at 10 minutes per block).
;; @constant HALVING_INTERVAL The number of blocks between each halving event.
;; @constant INITIAL_REWARD The initial reward amount before any halving.
;; @constant MIN_REWARD_FLOOR The minimum reward amount (floor) to prevent reward from going to zero.
;; @constant ERR_UNAUTHORIZED Error code for unauthorized access.

(define-constant HALVING_INTERVAL u210000)
(define-constant INITIAL_REWARD u1000000)
(define-constant MIN_REWARD_FLOOR u100)
(define-constant ERR_UNAUTHORIZED u8000)

(define-data-var admin principal tx-sender)

(define-private (is-admin) (is-eq tx-sender (var-get admin)))

(define-read-only (get-current-epoch (block_height uint))
    (/ block_height HALVING_INTERVAL)
)

(define-read-only (calculate-reward (block_height uint))
    (let
        (
            (epoch (get-current-epoch block_height))
            (divisor (pow u2 epoch))
            (raw_reward (/ INITIAL_REWARD divisor))
        )
        (if (< raw_reward MIN_REWARD_FLOOR)
            MIN_REWARD_FLOOR
            raw_reward
        )
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set admin new-admin)
        (ok true)
    )
)
