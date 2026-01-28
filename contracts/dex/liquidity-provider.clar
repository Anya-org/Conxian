;; liquidity-provider.clar
;; Conxian Standard: Liquidity Provider Management
;; Manages liquidity providers and their positions in pools

;; Dependencies
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_INSUFFICIENT_BALANCE (err u13001))
(define-constant ERR_INVALID_POOL (err u13002))
(define-constant ERR_ZERO_AMOUNT (err u13003))
(define-constant ERR_ALREADY_PROVIDER (err u13004))
(define-constant ERR_NOT_PROVIDER (err u13005))
(define-constant ERR_INVALID_PARAMETERS (err u13006))
(define-constant ERR_UNAUTHORIZED (err u13007))

;; Minimum liquidity thresholds
(define-constant MIN_LIQUIDITY u1000000) ;; 1 STX equivalent

;; Data variables
(define-data-var total-liquidity-supplied uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var liquidity-provider-active bool true)

;; Storage maps
(define-map liquidity-positions { pool: principal, provider: principal } {
  liquidity-amount: uint,
  pool-shares: uint,
  last-deposit: uint,
  rewards-earned: uint,
  rewards-claimed: uint,
  fee-tier: uint
})

(define-map provider-stats { provider: principal } {
  total-liquidity: uint,
  total-rewards: uint,
  pool-count: uint,
  first-provision: uint
})

(define-map reward-history { provider: principal } {
  timestamp: uint,
  pool: principal,
  amount: uint
})

;; Read-only functions

;; @desc Get liquidity position for a provider in a specific pool
(define-read-only (get-liquidity-position (pool principal) (provider principal))
  (map-get? liquidity-positions { pool: pool, provider: provider })
)

;; @desc Get cumulative stats for a liquidity provider
(define-read-only (get-provider-stats (provider principal))
  (map-get? provider-stats { provider: provider })
)

;; Public functions

;; @desc Add liquidity to a specific pool
(define-public (add-liquidity (pool principal) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= amount MIN_LIQUIDITY) ERR_INSUFFICIENT_BALANCE)
    
    (let ((existing-position (default-to
                               { liquidity-amount: u0, pool-shares: u0, last-deposit: u0, rewards-earned: u0, rewards-claimed: u0, fee-tier: u0 }
                               (map-get? liquidity-positions { pool: pool, provider: tx-sender }))))
      
      ;; Update position
      (map-set liquidity-positions { pool: pool, provider: tx-sender } {
        liquidity-amount: (+ (get liquidity-amount existing-position) amount),
        pool-shares: (+ (get pool-shares existing-position) amount), ;; Simplified share calculation
        last-deposit: burn-block-height,
        rewards-earned: (get rewards-earned existing-position),
        rewards-claimed: (get rewards-claimed existing-position),
        fee-tier: u1000
      })

      ;; Update provider stats
      (let ((stats (default-to { total-liquidity: u0, total-rewards: u0, pool-count: u0, first-provision: burn-block-height } (map-get? provider-stats { provider: tx-sender }))))
        (map-set provider-stats { provider: tx-sender } {
          total-liquidity: (+ (get total-liquidity stats) amount),
          total-rewards: (get total-rewards stats),
          pool-count: (+ (get pool-count stats) u1),
          first-provision: (get first-provision stats)
        })
      )

      (var-set total-liquidity-supplied (+ (var-get total-liquidity-supplied) amount))
      (print { event: "liquidity-added", provider: tx-sender, pool: pool, amount: amount })
      (ok true)
    )
  )
)

;; @desc Remove liquidity from a specific pool
(define-public (remove-liquidity (pool principal) (amount uint))
  (let ((position (unwrap! (map-get? liquidity-positions { pool: pool, provider: tx-sender }) ERR_NOT_PROVIDER)))
    (asserts! (<= amount (get liquidity-amount position)) ERR_INSUFFICIENT_BALANCE)
    
    (map-set liquidity-positions { pool: pool, provider: tx-sender } {
      liquidity-amount: (- (get liquidity-amount position) amount),
      pool-shares: (- (get pool-shares position) amount), ;; Simplified
      last-deposit: (get last-deposit position),
      rewards-earned: (get rewards-earned position),
      rewards-claimed: (get rewards-claimed position),
      fee-tier: (get fee-tier position)
    })

    (let ((stats (unwrap-panic (map-get? provider-stats { provider: tx-sender }))))
      (map-set provider-stats { provider: tx-sender } {
        total-liquidity: (- (get total-liquidity stats) amount),
        total-rewards: (get total-rewards stats),
        pool-count: (get pool-count stats),
        first-provision: (get first-provision stats)
      })
    )

    (var-set total-liquidity-supplied (- (var-get total-liquidity-supplied) amount))
    (print { event: "liquidity-removed", provider: tx-sender, pool: pool, amount: amount })
    (ok true)
  )
)

;; @desc Claim earned rewards from a specific pool
(define-public (claim-rewards (pool principal))
  (let (
    (position (unwrap! (map-get? liquidity-positions { pool: pool, provider: tx-sender }) ERR_NOT_PROVIDER))
    (unclaimed (- (get rewards-earned position) (get rewards-claimed position)))
  )
    (asserts! (> unclaimed u0) ERR_ZERO_AMOUNT)
    
    (map-set liquidity-positions { pool: pool, provider: tx-sender } {
      liquidity-amount: (get liquidity-amount position),
      pool-shares: (get pool-shares position),
      last-deposit: (get last-deposit position),
      rewards-earned: (get rewards-earned position),
      rewards-claimed: (get rewards-earned position),
      fee-tier: (get fee-tier position)
    })

    (let ((stats (unwrap-panic (map-get? provider-stats { provider: tx-sender }))))
      (map-set provider-stats { provider: tx-sender } {
        total-liquidity: (get total-liquidity stats),
        total-rewards: (+ (get total-rewards stats) unclaimed),
        pool-count: (get pool-count stats),
        first-provision: (get first-provision stats)
      })
    )

    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) unclaimed))
    (print { event: "rewards-claimed", provider: tx-sender, pool: pool, amount: unclaimed })
    (ok unclaimed)
  )
)

;; @desc Batch claim rewards from multiple pools
(define-public (batch-claim-rewards (pools (list 20 principal)))
  (begin
    (asserts! (<= (len pools) u20) ERR_INVALID_PARAMETERS)
    (ok (fold batch-claim-helper pools u0))
  )
)

(define-private (batch-claim-helper (pool principal) (total uint))
  (match (claim-rewards pool)
    amount (+ total amount)
    err total
  )
)

;; Admin functions

;; @desc Set the active status of the liquidity provider system
(define-public (set-liquidity-provider-active (active bool))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) ERR_UNAUTHORIZED)
    (var-set liquidity-provider-active active)
    (ok true)
  )
)
