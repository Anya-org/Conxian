;; lending-manager.clar
;; Comprehensive Lending System for Conxian Protocol

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INVALID_AMOUNT u1003)

;; Storage
(define-data-var circuit-breaker (optional principal) none)
(define-map deposits { asset: principal, user: principal } uint)
(define-map borrows { asset: principal, user: principal } uint)
(define-map reserve-data principal { total-deposits: uint, total-borrows: uint, last-updated: uint })

;; --- Helpers ---

(define-private (is-admin)
  (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin))
)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb (if (contract-call? .circuit-breaker is-contract-paused (as-contract tx-sender))
         (err ERR_PAUSED)
         (ok true))
    (ok true)
  )
)

;; --- Core Logic ---

;; @desc Deposit assets into the lending protocol.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to deposit.
;; @param amount uint - The amount of tokens to deposit.
;; @returns (response bool uint)
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (current-dep (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
    (reserve (default-to { total-deposits: u0, total-borrows: u0, last-updated: block-height } (map-get? reserve-data asset)))
  )
    (begin
      (try! (check-circuit-breaker))
      (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))

      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

      (map-set deposits { asset: asset, user: tx-sender } (+ current-dep amount))
      (map-set reserve-data asset (merge reserve {
        total-deposits: (+ (get total-deposits reserve) amount),
        last-updated: block-height
      }))

      (print { event: "deposit", user: tx-sender, asset: asset, amount: amount })
      (ok true)
    )
  )
)

;; @desc Borrow assets from the protocol.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to borrow.
;; @param amount uint - The amount of tokens to borrow.
;; @returns (response bool uint)
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
    (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
  )
    (begin
      (try! (check-circuit-breaker))
      (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))
      (asserts! (<= amount (get total-deposits reserve)) (err ERR_INSUFFICIENT_LIQUIDITY))

      ;; Note: In a full implementation, this would query the risk-manager for collateralization
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) tx-sender none)))

      (map-set borrows { asset: asset, user: tx-sender } (+ current-bor amount))
      (map-set reserve-data asset (merge reserve {
        total-borrows: (+ (get total-borrows reserve) amount),
        last-updated: block-height
      }))

      (print { event: "borrow", user: tx-sender, asset: asset, amount: amount })
      (ok true)
    )
  )
)

;; @desc Repay borrowed assets.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to repay.
;; @param amount uint - The amount of tokens to repay.
;; @returns (response bool uint)
(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
    (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
  )
    (begin
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

      (let ((repaid-amount (if (> current-bor amount) amount current-bor)))
        (map-set borrows { asset: asset, user: tx-sender } (- current-bor repaid-amount))
        (map-set reserve-data asset (merge reserve {
          total-borrows: (- (get total-borrows reserve) repaid-amount),
          last-updated: block-height
        }))

        (print { event: "repay", user: tx-sender, asset: asset, amount: repaid-amount })
        (ok true)
      )
    )
  )
)

;; Read-only

;; @desc Get global data for a specific asset reserve.
(define-read-only (get-reserve-data (asset principal))
  (map-get? reserve-data asset)
)

;; @desc Get the deposit balance for a user.
(define-read-only (get-user-deposit (asset principal) (user principal))
  (default-to u0 (map-get? deposits { asset: asset, user: user }))
)

;; @desc Get the borrow balance for a user.
(define-read-only (get-user-borrow (asset principal) (user principal))
  (default-to u0 (map-get? borrows { asset: asset, user: user }))
)

;; Admin

(define-public (set-circuit-breaker (new-cb principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set circuit-breaker (some new-cb))
    (ok true)
  )
)
