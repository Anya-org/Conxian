;; lending-manager.clar
;; Conxian Protocol Standard Contract - Upgraded for BME

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))

(define-constant COLLATERAL_FACTOR u7500)
(define-constant RESERVE_FACTOR u1000)

(define-map reserve-data
  principal
  {
    total-deposits: uint
    total-borrows: uint
    total-reserves: uint
    last-updated: uint
  }
)

(define-map deposits { asset: principal user: principal } uint)
(define-map borrows { asset: principal user: principal } uint)

(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

;; @desc Deposit assets for lending or collateral.
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (default-to { total-deposits: u0 total-borrows: u0 total-reserves: u0 last-updated: burn-block-height } (map-get? reserve-data asset)))
  )
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

      (map-set deposits { asset: asset user: tx-sender } (+ (default-to u0 (map-get? deposits { asset: asset user: tx-sender })) amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (+ (get total-deposits reserve) amount) }))
      (ok true)
    )
  )
)

;; @desc Borrow assets.
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
  )
    (begin
      (asserts! (<= amount (get total-deposits reserve)) ERR_INSUFFICIENT_LIQUIDITY)
      (map-set borrows { asset: asset user: tx-sender } (+ (default-to u0 (map-get? borrows { asset: asset user: tx-sender })) amount))
      (map-set reserve-data asset (merge reserve { total-borrows: (+ (get total-borrows reserve) amount) }))

      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) tx-sender none)))
      (ok true)
    )
  )
)

;; @desc Repay and collect interest (fees)
(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
    (interest-portion (/ (* amount RESERVE_FACTOR) u10000))
  )
    (begin
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      
      (match (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) interest-portion)
        res true
        err-val (begin (print { event: "bme-report-failed" error: err-val }) false)
      )
      
      (map-set reserve-data asset (merge reserve {
        total-borrows: (- (get total-borrows reserve) (- amount interest-portion))
        total-reserves: (+ (get total-reserves reserve) interest-portion)
      }))
      (ok true)
    )
  )
)

(define-public (collect-reserves (asset-trait <sip-010-ft-trait>))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
    (amount (get total-reserves reserve))
  )
    (begin
      (asserts! (> amount u0) (ok true))
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) .revenue-distributor none)))
      (map-set reserve-data asset (merge reserve { total-reserves: u0 }))
      (ok true)
    )
  )
)

(define-read-only (get-reserve-data (asset principal))
  (map-get? reserve-data asset)
)

(define-read-only (get-user-supply-balance (user principal) (asset principal))
  (map-get? deposits { asset: asset user: user })
)

;; @desc Withdraw previously deposited assets.
(define-public (withdraw (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (user-deposit (default-to u0 (map-get? deposits { asset: asset user: tx-sender })))
    (reserve (default-to { total-deposits: u0 total-borrows: u0 total-reserves: u0 last-updated: burn-block-height } (map-get? reserve-data asset)))
  )
    (begin
      (asserts! (>= user-deposit amount) ERR_INSUFFICIENT_LIQUIDITY)
      (map-set deposits { asset: asset user: tx-sender } (- user-deposit amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (if (>= (get total-deposits reserve) amount) (- (get total-deposits reserve) amount) u0) }))
      (ok true)
    )
  )
)
