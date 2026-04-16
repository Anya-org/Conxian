;; lending-manager.clar
;; Conxian Protocol Standard Contract - Upgraded for BME
;; Standardized for Mainnet (March 2026)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_NOT_FOUND (err u404))

(define-constant COLLATERAL_FACTOR u7500)
(define-constant RESERVE_FACTOR u1000)

;; --- Storage ---
(define-map reserve-data
  principal
  {
    total-deposits: uint,
    total-borrows: uint,
    total-reserves: uint,
    decimals: uint,
    last-updated: uint
  }
)

(define-map deposits { asset: principal, user: principal } uint)
(define-map borrows { asset: principal, user: principal } uint)

(define-data-var admin principal tx-sender)

;; --- Public Functions ---

;; @desc Deposit assets for lending or collateral.
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (match (map-get? reserve-data asset)
               res res
               {
                 total-deposits: u0,
                 total-borrows: u0,
                 total-reserves: u0,
                 decimals: (unwrap-panic (contract-call? asset-trait get-decimals)),
                 last-updated: burn-block-height
               }))
  )
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

      (map-set deposits { asset: asset, user: tx-sender } (+ (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })) amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (+ (get total-deposits reserve) amount) }))
      (ok true)
    )
  )
)

;; @desc Borrow assets.
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (caller tx-sender)
    (reserve (unwrap! (map-get? reserve-data asset) ERR_NOT_FOUND))
  )
    (begin
      (asserts! (<= amount (get total-deposits reserve)) ERR_INSUFFICIENT_LIQUIDITY)
      (map-set borrows { asset: asset, user: caller } (+ (default-to u0 (map-get? borrows { asset: asset, user: caller })) amount))
      (map-set reserve-data asset (merge reserve { total-borrows: (+ (get total-borrows reserve) amount) }))

      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) caller none)))
      (ok true)
    )
  )
)

;; @desc Repay and collect interest (fees)
(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) ERR_NOT_FOUND))
    (interest-portion (/ (* amount RESERVE_FACTOR) u10000))
    (principal-portion (if (>= amount interest-portion) (- amount interest-portion) u0))
    (current-borrows (get total-borrows reserve))
  )
    (begin
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      
      ;; Automatically collect protocol fee via revenue-automation (CON-60)
      (match (contract-call? .revenue-automation collect-revenue asset-trait amount tx-sender)
        res (print { event: "lending-fee-automated", amount: res })
        err-val (print { event: "lending-fee-failed", error: err-val })
      )

      (match (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) interest-portion)
        res true
        err-val (begin (print { event: "bme-report-failed", error: err-val }) false)
      )
      
      (map-set reserve-data asset (merge reserve {
        total-borrows: (if (>= current-borrows principal-portion) (- current-borrows principal-portion) u0),
        total-reserves: (+ (get total-reserves reserve) interest-portion)
      }))
      (ok true)
    )
  )
)

;; @desc Withdraw previously deposited assets.
(define-public (withdraw (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (user-deposit (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
    (reserve (unwrap! (map-get? reserve-data asset) ERR_NOT_FOUND))
  )
    (begin
      (asserts! (>= user-deposit amount) ERR_INSUFFICIENT_LIQUIDITY)
      (map-set deposits { asset: asset, user: tx-sender } (- user-deposit amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (if (>= (get total-deposits reserve) amount) (- (get total-deposits reserve) amount) u0) }))
      (ok true)
    )
  )
)

;; @desc Collect accumulated protocol reserves
(define-public (collect-reserves (asset-trait <sip-010-ft-trait>))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) ERR_NOT_FOUND))
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

;; --- Read-only Functions ---

;; @desc Get total deposits for a specific asset
(define-read-only (get-total-deposits (asset principal))
  (match (map-get? reserve-data asset)
    reserve (ok (get total-deposits reserve))
    (ok u0)
  )
)

;; @desc Get total borrows for a specific asset
(define-read-only (get-total-borrows (asset principal))
  (match (map-get? reserve-data asset)
    reserve (ok (get total-borrows reserve))
    (ok u0)
  )
)

(define-read-only (get-reserve-data (asset principal))
  (map-get? reserve-data asset)
)

(define-read-only (get-user-supply-balance (user principal) (asset principal))
  (map-get? deposits { asset: asset, user: user })
)

;; @desc Calculate total value locked in the lending manager (Legacy, redirects to telemetry)
(define-read-only (get-protocol-tvl)
  (ok u0)
)

;; --- Admin ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
