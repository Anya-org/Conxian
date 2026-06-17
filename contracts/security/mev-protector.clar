;; mev-protector.clar
;; Conxian Security: MEV Protector
;; Implements commit-reveal scheme to prevent front-running.

;; Constants
(define-constant ERR_UNAUTHORIZED u7000)
(define-constant ERR_ORDER_EXPIRED u7001)
(define-constant ERR_ORDER_TOO_NEW u7002)

(define-constant MIN_COMMIT_AGE u1) ;; Must be at least 1 block old
(define-constant MAX_COMMIT_AGE u10) ;; Must be executed within 10 blocks

;; Map: OrderHash -> CommitHeight
(define-map committed-orders (buff 32) uint)

;; Public Functions

;; @desc Commit to an order hash before execution
;; @param order-hash: The 32-byte hash of the order to protect.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (commit-order (order-hash (buff 32)))
  (begin
    (map-set committed-orders order-hash burn-block-height)
    (ok true)
  )
)

;; @desc Verify if an order is valid for execution
;; @param order-hash: The 32-byte hash of the order to verify and consume.
;; @return (response bool uint) - Returns ok(true) if valid, or an error.
(define-public (verify-and-consume (order-hash (buff 32)))
  (let (
    (commit-height (unwrap! (map-get? committed-orders order-hash) (err ERR_UNAUTHORIZED)))
    (age (- burn-block-height commit-height))
  )
    (asserts! (>= age MIN_COMMIT_AGE) (err ERR_ORDER_TOO_NEW))
    (asserts! (<= age MAX_COMMIT_AGE) (err ERR_ORDER_EXPIRED))
    (map-delete committed-orders order-hash)
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (is-order-protected (order-hash (buff 32)))
  (is-some (map-get? committed-orders order-hash))
)
