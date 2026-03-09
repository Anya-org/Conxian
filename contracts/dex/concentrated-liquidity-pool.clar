;; concentrated-liquidity-pool.clar
;; Concentrated Liquidity Logic for Conxian Protocol
;; Upgraded for BME (Burn-Mint Equilibrium)

;; Traits
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INVALID_TICK u2000)
(define-constant PROTOCOL_FEE_SHARE u1666) ;; ~1/6th of the swap fee

;; Storage
(define-map pools
  uint
  {
    token0: principal,
    token1: principal,
    fee: uint,
    sqrt-price: uint,
    liquidity: uint,
    tick: int
  }
)

(define-map positions
    { pool-id: uint, owner: principal, tick-lower: int, tick-upper: int }
    {
        liquidity: uint,
        fee-growth-inside-0: uint,
        fee-growth-inside-1: uint
    }
)

(define-map total-revenue principal uint)

(define-data-var pool-nonce uint u0)

;; Public Functions

;; @desc Create pool
(define-public (create-pool (token0 principal) (token1 principal) (fee uint) (sqrt-price uint) (tick int))
  (let ((pool-id (+ (var-get pool-nonce) u1)))
    (begin
      (map-set pools pool-id {
          token0: token0,
          token1: token1,
          fee: fee,
          sqrt-price: sqrt-price,
          liquidity: u0,
          tick: tick
      })
      (var-set pool-nonce pool-id)
      (ok pool-id)
    )
  )
)

;; @desc Swap - Router pulls input tokens, pool executes swap and sends output
(define-public (swap (pool-id uint) (zero-for-one bool) (amount-in uint) (token0-trait <sip-010-ft-trait>) (token1-trait <sip-010-ft-trait>))
  (let ((pool (unwrap! (map-get? pools pool-id) (err ERR_INSUFFICIENT_LIQUIDITY))))
    (begin
      (asserts! (> amount-in u0) (err u1003))
      (let (
        (total-fee (/ (* amount-in (get fee pool)) u1000000))
        (protocol-fee (/ (* total-fee PROTOCOL_FEE_SHARE) u10000))
        (lp-fee (- total-fee protocol-fee))
        (amount-out (- amount-in total-fee))
        (token-in (if zero-for-one (get token0 pool) (get token1 pool)))
        (recipient contract-caller)
      )
        ;; Track protocol revenue
        (let ((current-revenue (default-to u0 (map-get? total-revenue token-in))))
          (map-set total-revenue token-in (+ current-revenue protocol-fee))
        )

        ;; BME Activity Tracking
        (match (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) protocol-fee)
          res true
          err-val (print { event: "bme-report-failed", error: err-val })
        )

        ;; Update pool liquidity
        (map-set pools pool-id (merge pool { liquidity: (+ (get liquidity pool) lp-fee) }))
        
        ;; Send output tokens to recipient
        (if zero-for-one
          (try! (as-contract (contract-call? token1-trait transfer amount-out tx-sender recipient none)))
          (try! (as-contract (contract-call? token0-trait transfer amount-out tx-sender recipient none)))
        )
        
        (ok amount-out)
      )
    )
  )
)

;; @desc Collect protocol fees and send to revenue distributor
(define-public (collect-protocol-fees (token-trait <sip-010-ft-trait>))
  (let (
    (token (contract-of token-trait))
    (amount (default-to u0 (map-get? total-revenue token)))
  )
    (begin
      (asserts! (> amount u0) (ok true))
      (try! (as-contract (contract-call? token-trait transfer amount (as-contract tx-sender) .revenue-distributor none)))
      (map-set total-revenue token u0)
      (ok true)
    )
  )
)

(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-public (mint (pool-id uint) (tick-lower int) (tick-upper int) (amount uint))
  (let ((pool (unwrap! (map-get? pools pool-id) (err ERR_INSUFFICIENT_LIQUIDITY)))
        (position-key { pool-id: pool-id, owner: tx-sender, tick-lower: tick-lower, tick-upper: tick-upper }))
    (begin
      (asserts! (> amount u0) (err u1003))
      (let ((current-pos (default-to { liquidity: u0, fee-growth-inside-0: u0, fee-growth-inside-1: u0 } (map-get? positions position-key))))
        (map-set positions position-key (merge current-pos { liquidity: (+ (get liquidity current-pos) amount) }))
      )
      (map-set pools pool-id (merge pool { liquidity: (+ (get liquidity pool) amount) }))
      (ok true)
    )
  )
)
