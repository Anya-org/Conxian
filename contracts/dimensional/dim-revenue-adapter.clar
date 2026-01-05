;; dim-revenue-adapter.clar
;; Conxian SAB: Dimensional Revenue Adapter
;; Adapts and distributes revenue from dimensional trading

(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u3006))
(define-constant REVENUE_SHARE_DENOMINATOR u10000)

;; Data Vars
(define-data-var admin principal tx-sender)

;; Revenue tracking
(define-map revenue-pools
  principal
  {
    total-revenue: uint,
    last-distribution: uint,
    share-percentage: uint
  }
)

(define-map user-revenue-shares
  principal
  uint
)

;; Public functions
(define-public (create-revenue-pool (token principal) (share-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= share-percentage REVENUE_SHARE_DENOMINATOR) (err u3007))
    (map-set revenue-pools token {
      total-revenue: u0,
      last-distribution: u0,
      share-percentage: share-percentage
    })
    (ok true)
  )
)

(define-public (distribute-revenue (token principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? revenue-pools token)
      pool
      (begin
        (let ((share-amount (/ (* amount (get share-percentage pool)) REVENUE_SHARE_DENOMINATOR)))
          (map-set revenue-pools token (merge pool {
            total-revenue: (+ (get total-revenue pool) amount),
            last-distribution: block-height
          }))
          (ok share-amount)
        )
      )
      (err u0)
    )
  )
)

;; Read-only functions
(define-read-only (get-revenue-pool (token principal))
  (match (map-get? revenue-pools token)
    pool (ok pool)
    (err u0)
  )
)

(define-read-only (get-user-share (user principal))
  (match (map-get? user-revenue-shares user)
    share (ok share)
    (ok u0)
  )
)