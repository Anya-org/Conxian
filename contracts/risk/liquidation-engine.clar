;; liquidation-engine.clar
;; Liquidation engine for handling forced liquidations

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_LIQUIDATABLE (err u1001))

(define-map liquidations
  uint
  {
    position-id: uint,
    liquidator: principal,
    amount: uint,
    timestamp: uint,
    status: (string-ascii 10)
  }
)

(define-data-var liquidation-nonce uint u0)

(define-public (liquidate-position
    (position-id uint)
    (amount uint)
)
  (begin
    (let ((liquidation-id (+ (var-get liquidation-nonce) u1)))
      (map-set liquidations liquidation-id {
        position-id: position-id,
        liquidator: tx-sender,
        amount: amount,
        timestamp: block-height,
        status: "pending"
      })
      (var-set liquidation-nonce liquidation-id)
      (ok liquidation-id)
    )
  )
)

(define-read-only (get-liquidation (liquidation-id uint))
  (match (map-get? liquidations liquidation-id)
    liquidation (ok liquidation)
    (err ERR_NOT_LIQUIDATABLE)
  )
)
