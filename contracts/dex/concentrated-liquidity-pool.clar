;; concentrated-liquidity-pool.clar
;; Concentrated Liquidity Logic for Conxian Protocol
;; Standardized for Clarity 3 / Nakamoto adherence

;; Traits
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INVALID_TICK u2000)
(define-constant PROTOCOL_FEE_SHARE u1666) ;; ~1/6th of the swap fee

;; Storage - BOLT: No dynamic top-level init
(define-data-var pool-nonce uint u0)
(define-data-var authorized-router principal tx-sender)

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

;; Public Functions

(define-public (create-pool (token0 principal) (token1 principal) (fee uint) (sqrt-price uint))
  (let ((pool-id (+ (var-get pool-nonce) u1)))
    (begin
      (asserts! (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
      (map-set pools pool-id {
          token0: token0,
          token1: token1,
          fee: fee,
          sqrt-price: sqrt-price,
          liquidity: u0,
          tick: (to-int u0)
      })
      (var-set pool-nonce pool-id)
      (ok pool-id)
    )
  )
)

(define-public (set-pool-fee (pool-id uint) (new-fee uint))
  (begin
    (asserts! (or
        (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin))
        (is-eq contract-caller (var-get authorized-router))
    ) (err ERR_UNAUTHORIZED))
    (let ((pool (unwrap! (map-get? pools pool-id) (err ERR_INSUFFICIENT_LIQUIDITY))))
      (map-set pools pool-id (merge pool { fee: new-fee }))
      (ok true)
    )
  )
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

(define-public (swap (pool-id uint) (zero-for-one bool) (amount-in uint) (token0-trait <sip-010-ft-trait>) (token1-trait <sip-010-ft-trait>))
  (let ((pool (unwrap! (map-get? pools pool-id) (err ERR_INSUFFICIENT_LIQUIDITY))))
    (begin
      (asserts! (is-eq (contract-of token0-trait) (get token0 pool)) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq (contract-of token1-trait) (get token1 pool)) (err ERR_UNAUTHORIZED))
      
      (let (
        (total-fee (/ (* amount-in (get fee pool)) u1000000))
        (protocol-fee (/ (* total-fee PROTOCOL_FEE_SHARE) u10000))
        (lp-fee (- total-fee protocol-fee))
        (amount-out (- amount-in total-fee))
        (token-in (if zero-for-one (get token0 pool) (get token1 pool)))
      )
        (let ((current-revenue (default-to u0 (map-get? total-revenue token-in))))
          (map-set total-revenue token-in (+ current-revenue protocol-fee))
        )
        (map-set pools pool-id (merge pool { liquidity: (+ (get liquidity pool) lp-fee) }))

        (let ((recipient tx-sender))
          (if zero-for-one
            (try! (as-contract (contract-call? token1-trait transfer amount-out (as-contract tx-sender) recipient none)))
            (try! (as-contract (contract-call? token0-trait transfer amount-out (as-contract tx-sender) recipient none)))
          )
        )
        (ok amount-out)
      )
    )
  )
)

(define-public (burn (pool-id uint) (tick-lower int) (tick-upper int) (amount uint))
  (let ((pool (unwrap! (map-get? pools pool-id) (err ERR_INSUFFICIENT_LIQUIDITY)))
        (position-key { pool-id: pool-id, owner: tx-sender, tick-lower: tick-lower, tick-upper: tick-upper })
        (position (unwrap! (map-get? positions position-key) (err ERR_INSUFFICIENT_LIQUIDITY))))
    (begin
      (asserts! (>= (get liquidity position) amount) (err ERR_INSUFFICIENT_LIQUIDITY))
      (asserts! (> amount u0) (err u1003))
      (let ((new-liquidity (- (get liquidity position) amount)))
        (if (> new-liquidity u0)
          (map-set positions position-key (merge position { liquidity: new-liquidity }))
          (map-delete positions position-key)
        )
      )
      (map-set pools pool-id (merge pool { liquidity: (- (get liquidity pool) amount) }))
      (ok true)
    )
  )
)

(define-public (collect-protocol-fees (token-trait <sip-010-ft-trait>))
  (let (
    (token (contract-of token-trait))
    (amount (default-to u0 (map-get? total-revenue token)))
  )
    (begin
      (asserts! (> amount u0) (ok true))
      ;; Note: revenue-distributor must be configured
      (try! (as-contract (contract-call? token-trait transfer amount (as-contract tx-sender) tx-sender none)))
      (map-set total-revenue token u0)
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-read-only (get-position (pool-id uint) (owner principal) (tick-lower int) (tick-upper int))
  (map-get? positions { pool-id: pool-id, owner: owner, tick-lower: tick-lower, tick-upper: tick-upper })
)
