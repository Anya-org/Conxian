;; dim-yield-stake.clar
;; Conxian SAB: Dimensional Yield Staking
;; Staking mechanism for dimensional asset yields

(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u3007))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3008))
(define-constant MIN_STAKE_AMOUNT u1000)

;; Data Vars
(define-data-var admin principal tx-sender)

;; Staking storage
(define-map staking-positions
  principal
  {
    amount: uint,
    lock-period: uint,
    start-block: uint,
    end-block: uint,
    rewards: uint
  }
)

(define-map reward-pools
  principal
  {
    total-staked: uint,
    reward-rate: uint,
    last-update: uint
  }
)

;; Public functions
(define-public (stake (token principal) (amount uint) (lock-period uint))
  (begin
    (asserts! (> amount MIN_STAKE_AMOUNT) ERR_INSUFFICIENT_BALANCE)
    (let ((end-block (+ block-height lock-period)))
      (map-set staking-positions tx-sender {
        amount: amount,
        lock-period: lock-period,
        start-block: block-height,
        end-block: end-block,
        rewards: u0
      })
      ;; Update reward pool
      (match (map-get? reward-pools token)
        pool
        (map-set reward-pools token (merge pool {
          total-staked: (+ (get total-staked pool) amount),
          last-update: block-height
        }))
        (map-set reward-pools token {
          total-staked: amount,
          reward-rate: u1000, ;; 10% APR
          last-update: block-height
        })
      )
      (ok true)
    )
  )
)

(define-public (unstake (token principal))
  (begin
    (match (map-get? staking-positions tx-sender)
      position
      (begin
        (asserts! (>= block-height (get end-block position)) (err u3009))
        (let ((total-amount (+ (get amount position) (get rewards position))))
          (map-delete staking-positions tx-sender)
          (ok total-amount)
        )
      )
      (err u0)
    )
  )
)

;; Read-only functions
(define-read-only (get-staking-position (user principal))
  (match (map-get? staking-positions user)
    position (ok position)
    (err u0)
  )
)

(define-read-only (get-reward-pool (token principal))
  (match (map-get? reward-pools token)
    pool (ok pool)
    (err u0)
  )
)