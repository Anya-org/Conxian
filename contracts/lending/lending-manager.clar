;; lending-manager.clar
;; Comprehensive Lending System for Conxian Protocol

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1002))
(define-constant ERR_PAUSED (err u1001))

;; Storage
(define-map deposits { asset: principal, user: principal } uint)
(define-map borrows { asset: principal, user: principal } uint)
(define-map reserve-data principal { total-deposits: uint, total-borrows: uint })

;; --- Core Logic ---

(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let ((asset (contract-of asset-trait))
        (current-dep (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
        (reserve (default-to { total-deposits: u0, total-borrows: u0 } (map-get? reserve-data asset))))
    (begin
      (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) ERR_PAUSED)
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      (map-set deposits { asset: asset, user: tx-sender } (+ current-dep amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (+ (get total-deposits reserve) amount) }))
      (ok true)
    )
  )
)

(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let ((asset (contract-of asset-trait))
        (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
        (reserve (unwrap! (map-get? reserve-data asset) (err u404))))
    (begin
      (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) ERR_PAUSED)
      ;; Collateral health check would call risk-manager
      (try! (as-contract (contract-call? asset-trait transfer amount tx-sender tx-sender none)))
      (map-set borrows { asset: asset, user: tx-sender } (+ current-bor amount))
      (map-set reserve-data asset (merge reserve { total-borrows: (+ (get total-borrows reserve) amount) }))
      (ok true)
    )
  )
)

(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let ((asset (contract-of asset-trait))
        (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
        (reserve (unwrap! (map-get? reserve-data asset) (err u404))))
    (begin
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      (map-set borrows { asset: asset, user: tx-sender } (if (> current-bor amount) (- current-bor amount) u0))
      (map-set reserve-data asset (merge reserve { total-borrows: (if (> (get total-borrows reserve) amount) (- (get total-borrows reserve) amount) u0) }))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-reserve-data (asset principal))
  (map-get? reserve-data asset)
)
