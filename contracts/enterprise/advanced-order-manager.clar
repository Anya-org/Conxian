;; advanced-order-manager.clar
;; Advanced order management system for complex trading strategies

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ORDER (err u1001))

(define-map orders
  uint
  {
    owner: principal,
    order-type: (string-ascii 10),
    amount: uint,
    price: uint,
    status: (string-ascii 10),
    created-at: uint,
  }
)

(define-data-var order-nonce uint u0)

(define-public (create-order
    (order-type (string-ascii 10))
    (amount uint)
    (price uint)
  )
  (begin
    (let ((order-id (+ (var-get order-nonce) u1)))
      (map-set orders order-id {
        owner: tx-sender,
        order-type: order-type,
        amount: amount,
        price: price,
        status: "pending",
        created-at: block-height,
      })
      (var-set order-nonce order-id)
      (ok order-id)
    )
  )
)

(define-read-only (get-order (order-id uint))
  (match (map-get? orders order-id)
    order (ok order)
    (err ERR_INVALID_ORDER)
  )
)
