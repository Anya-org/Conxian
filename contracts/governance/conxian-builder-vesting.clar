;; conxian-builder-vesting.clar
;;
;; This contract manages the vesting schedules for Conxian Protocol builders.
;; It ensures that builder incentives are aligned with the long-term health
;; of the protocol by enforcing a split on vested tokens: 50% are sent to the
;; builder's wallet, and 50% are automatically reinvested into the protocol's
;; primary liquidity pool.

(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NO_VESTING_SCHEDULE (err u9001))
(define-constant ERR_NO_TOKENS_TO_CLAIM (err u9002))
(define-constant ERR_PROTOCOL_NOT_HEALTHY (err u9003))

(define-data-var contract-owner principal tx-sender)
(define-data-var operations-engine-contract principal .conxian-operations-engine)
(define-data-var liquidity-pool-contract principal .dex-factory) ;; Placeholder for the main LP contract
(define-data-var cxd-token-contract principal .cxd-token)

(define-map vesting-schedules
  principal
  {
    total-vested: uint,
    claimed-amount: uint,
    start-block: uint,
    cliff-blocks: uint,
    duration-blocks: uint
  }
)

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (add-vesting-schedule
    (builder principal)
    (total-amount uint)
    (start-block uint)
    (cliff-blocks uint)
    (duration-blocks uint)
  )
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set vesting-schedules builder {
      total-vested: total-amount,
      claimed-amount: u0,
      start-block: start-block,
      cliff-blocks: cliff-blocks,
      duration-blocks: duration-blocks
    })
    (ok true)
  )
)

(define-read-only (get-vesting-schedule (builder principal))
  (ok (map-get? vesting-schedules builder))
)

(define-read-only (get-claimable-amount (builder principal))
  (match (map-get? vesting-schedules builder)
    schedule
    (let
      (
        (start (get start-block schedule))
        (cliff (get cliff-blocks schedule))
        (duration (get duration-blocks schedule))
        (total-amount (get total-vested schedule))
        (claimed (get claimed-amount schedule))
        (current-block block-height)
      )
      (if (< current-block (+ start cliff))
        (ok u0)
        (if (>= current-block (+ start duration))
          (ok (- total-amount claimed))
          (let
            (
              (vested-so-far (/ (* total-amount (- current-block start)) duration))
            )
            (ok (- vested-so-far claimed))
          )
        )
      )
    )
    (err ERR_NO_VESTING_SCHEDULE)
  )
)

(define-public (claim-vested-tokens)
  (let
    (
      (builder tx-sender)
      (claimable (unwrap! (get-claimable-amount builder) (err ERR_NO_TOKENS_TO_CLAIM)))
      (health-status (unwrap-panic (contract-call? (var-get operations-engine-contract) get-operations-status)))
    )
    (asserts! (> claimable u0) (err ERR_NO_TOKENS_TO_CLAIM))
    (asserts! (not (get is-paused health-status)) (err ERR_PROTOCOL_NOT_HEALTHY))

    (let
      (
        (to-wallet (/ claimable u2))
        (to-lp (- claimable to-wallet))
        (schedule (unwrap! (map-get? vesting-schedules builder) (err ERR_NO_VESTING_SCHEDULE)))
      )
      ;; Transfer 50% to the builder's wallet
      (try! (contract-call? (var-get cxd-token-contract) transfer to-wallet (as-contract tx-sender) builder (some 0x)))
      ;; Transfer 50% to the liquidity pool (placeholder for actual LP logic)
      (try! (contract-call? (var-get cxd-token-contract) transfer to-lp (as-contract tx-sender) (var-get liquidity-pool-contract) (some 0x)))

      (map-set vesting-schedules builder
        (merge schedule { claimed-amount: (+ (get claimed-amount schedule) claimable) })
      )
      (ok claimable)
    )
  )
)
