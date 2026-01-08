;; liquidity-provider.clar
;; Conxian DEX: Liquidity provider management and rewards

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_INSUFFICIENT_BALANCE (err 13001))
(define-constant ERR_INVALID_POOL (err 13002))
(define-constant ERR_ZERO_AMOUNT (err 13003))
(define-constant ERR_ALREADY_PROVIDER (err 13004))
(define-constant ERR_NOT_PROVIDER (err 13005))
(define-constant ERR_REWARD_CLAIM_FAILED (err 13006))

;; Reward parameters
(define-constant REWARD_PRECISION u1000000) ;; 6 decimal places
(define-constant MIN_LIQUIDITY u1000000) ;; 1 STX equivalent
(define-constant REWARD_RATE u1000) ;; 0.1% of fees
(define-constant MAX_REWARD_HISTORY u100)

;; Data variables
(define-data-var total-liquidity-supplied uint u0)
(define-data-var total-rewards-distributed uint u0)

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
  amount: uint,
  reward-type: (string-ascii 16)
})

;; Events
(define-event (liquidity-added (pool principal) (provider principal) (amount uint) (shares uint)))
(define-event (liquidity-removed (pool principal) (provider principal) (amount uint) (shares uint)))
(define-event (rewards-claimed (provider principal) (pool principal) (amount uint)))
(define-event (provider-registered (provider principal)))
(define-event (provider-unregistered (provider principal)))

;; Read-only functions

(define-read-only (get-liquidity-position (pool principal) (provider principal))
  (map-get? liquidity-positions { pool: pool, provider: provider }))

(define-read-only (get-provider-liquidity (pool principal) (provider principal))
  (match (get-liquidity-position pool provider)
    position (ok (get position liquidity-amount))
    none (ok u0)
  )
)

(define-read-only (get-provider-shares (pool principal) (provider principal))
  (match (get-liquidity-position pool provider)
    position (ok (get position pool-shares))
    none (ok u0)
  )
)

(define-read-only (get-provider-rewards (pool principal) (provider principal))
  (match (get-liquidity-position pool provider)
    position (ok (get position rewards-earned))
    none (ok u0)
  )
)

(define-read-only (get-claimable-rewards (pool principal) (provider principal))
  (match (get-liquidity-position pool provider)
    position
      (let ((earned (get position rewards-earned))
            (claimed (get position rewards-claimed)))
        (ok (- earned claimed))
      )
    none (ok u0)
  )
)

(define-read-only (get-provider-stats (provider principal))
  (map-get? provider-stats { provider: provider }))

(define-read-only (get-total-liquidity-supplied)
  (var-get total-liquidity-supplied))

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed))

(define-read-only (is-liquidity-provider (pool principal) (provider principal))
  (match (get-liquidity-position pool provider)
    position (ok true)
    none (ok false)
  )
)

(define-read-only (get-pool-providers (pool principal))
  (begin
    ;; This would return all providers for a pool
    ;; Simplified implementation
    (ok (list 0 principal))
  )
)

;; Public functions

(define-public (add-liquidity (pool principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= amount MIN_LIQUIDITY) ERR_INSUFFICIENT_BALANCE)
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Check if provider already has position
    (let ((existing-position (get-liquidity-position pool tx-sender))
      (let ((current-shares (if (is-some existing-position) 
                                   (get-optional (get-provider-shares pool tx-sender))
                                   u0))
            (pool-total-liquidity (contract-call? .dex-facade get-pool-liquidity pool)))
        
        ;; Calculate shares (simplified - would use proper LP token calculation)
        (let ((new-shares (/ (* amount current-shares) pool-total-liquidity)))
          
          ;; Update or create position
          (map-set liquidity-positions { pool: pool, provider: tx-sender } {
            liquidity-amount: (+ (if (is-some existing-position) (get-optional (get-provider-liquidity pool tx-sender)) u0) amount),
            pool-shares: (+ current-shares new-shares),
            last-deposit: block-height,
            rewards-earned: (if (is-some existing-position) (get-optional (get-provider-rewards pool tx-sender)) u0),
            rewards-claimed: (if (is-some existing-position) (get-optional (get-provider-rewards pool tx-sender)) u0),
            fee-tier: u1000 ;; Default fee tier
          })
          
          ;; Update provider stats
          (map-set provider-stats { provider: tx-sender } {
            total-liquidity: (+ (if (is-some (get-provider-stats tx-sender)) (get-optional (get-provider-stats tx-sender)).total-liquidity u0) amount),
            total-rewards: (if (is-some (get-provider-stats tx-sender)) (get-optional (get-provider-stats tx-ssender)).total-rewards u0),
            pool-count: (+ (if (is-some (get-provider-stats tx-sender)) (get-optional (get-provider-stats tx-ssender)).pool-count u0) u1),
            first-provision: (if (is-some (get-provider-stats tx-sender)) (get-optional (get-provider-stats tx-ssender)).first-provision block-height)
          })
          
          ;; Update global totals
          (var-set total-liquidity-supplied (+ (var-get total-liquidity-supplied) amount))
          
          ;; Emit event
          (emit-event (liquidity-added pool tx-sender amount new-shares))
          
          (ok {
            liquidity-amount: (+ (if (is-some existing-position) (get-optional (get-provider-liquidity pool tx-sender)) u0) amount),
            pool-shares: (+ current-shares new-shares),
            total-liquidity: (var-get total-liquidity-supplied)
          })
        )
      )
    )
  )
)

(define-public (remove-liquidity (pool principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Check if provider has position
    (let ((position (get-liquidity-position pool tx-sender)))
      (asserts! (is-some position) ERR_NOT_PROVIDER)
      
      (let ((current-liquidity (get-optional (get-provider-liquidity pool tx-sender)))
            (current-shares (get-optional (get-provider-shares pool tx-sender))))
        
        (asserts! (>= current-liquidity amount) ERR_INSUFFICIENT_BALANCE)
        
        ;; Calculate shares to remove (simplified)
        (let ((pool-total-liquidity (contract-call? .dex-facade get-pool-liquidity pool))
              (shares-to-remove (/ (* amount current-shares) current-liquidity)))
          
          ;; Update position
          (map-set liquidity-positions { pool: pool, provider: tx-sender } {
            liquidity-amount: (- current-liquidity amount),
            pool-shares: (- current-shares shares-to-remove),
            last-deposit: (get position last-deposit),
            rewards-earned: (get position rewards-earned),
            rewards-claimed: (get position rewards-claimed),
            fee-tier: (get position fee-tier)
          })
          
          ;; Update provider stats
          (map-set provider-stats { provider: tx-sender } {
            total-liquidity: (- (get-optional (get-provider-stats tx-sender)).total-liquidity amount),
            total-rewards: (get-optional (get-provider-stats tx-sender)).total-rewards,
            pool-count: (get-optional (get-provider-stats tx-sender)).pool-count,
            first-provision: (get-optional (get-provider-stats tx-ssender)).first-provision
          })
          
          ;; Update global totals
          (var-set total-liquidity-supplied (- (var-get total-liquidity-supplied) amount))
          
          ;; Emit event
          (emit-event (liquidity-removed pool tx-sender amount shares-to-remove))
          
          (ok {
            liquidity-amount: (- current-liquidity amount),
            pool-shares: (- current-shares shares-to-remove),
            total-liquidity: (var-get total-liquidity-supplied)
          })
        )
      )
    )
  )
)

(define-public (claim-rewards (pool principal))
  (begin
    ;; Validate inputs
    (asserts! (contract-call? .dex-facade pool-exists pool) ERR_INVALID_POOL)
    
    ;; Check if provider has position
    (let ((position (get-liquidity-position pool tx-sender)))
      (asserts! (is-some position) ERR_NOT_PROVIDER)
      
      (let ((claimable (get-claimable-rewards pool tx-sender)))
        (asserts! (> claimable u0) ERR_REWARD_CLAIM_FAILED)
        
        ;; Calculate rewards based on liquidity and fee revenue
        (let ((pool-fee-revenue (contract-call? .dex-facade get-pool-fee-revenue pool))
              (provider-share (/ (* (get-optional (get-provider-shares pool tx-sender)) pool-fee-revenue) (contract-call? .dex-facade get-pool-total-shares pool)))
              (reward-amount (/ (* provider-share REWARD_RATE) u10000)))
        
          ;; Update position
          (map-set liquidity-positions { pool: pool, provider: tx-sender } {
            liquidity-amount: (get position liquidity-amount),
            pool-shares: (get position pool-shares),
            last-deposit: (get position last-deposit),
            rewards-earned: (+ (get position rewards-earned) reward-amount),
            rewards-claimed: (+ (get position rewards-claimed) reward-amount),
            fee-tier: (get position fee-tier)
          })
          
          ;; Update provider stats
          (map-set provider-stats { provider: tx-sender } {
            total-liquidity: (get position liquidity-amount),
            total-rewards: (+ (get-optional (get-provider-stats tx-sender)).total-rewards reward-amount),
            pool-count: (get-optional (get-provider-stats tx-ssender)).pool-count,
            first-provision: (get-optional (get-provider-stats tx-ssender)).first-provision
          })
          
          ;; Update global totals
          (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
          
          ;; Record reward history
          (map-set reward-history { provider: tx-sender } {
            timestamp: block-height,
            pool: pool,
            amount: reward-amount,
            reward-type: "liquidity-reward"
          })
          
          ;; Emit event
          (emit-event (rewards-claimed tx-sender pool reward-amount))
          
          (ok reward-amount)
        )
      )
    )
  )
)

(define-public (batch-claim-rewards (pools (list 20 principal)))
  (begin
    ;; Validate list size
    (asserts! (<= (len pools) u20) ERR_INVALID_PARAMETERS)
    
    ;; Claim rewards from each pool
    (fold pools u0
      (lambda ((total uint) (pool principal))
        (match (claim-rewards pool)
          amount (+ total amount)
          error total
        )
      )
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (get-optional (option))
  (default-to u0 option))

;; Admin functions

(define-public (emergency-update-liquidity (pool principal) (provider principal) (new-liquidity uint))
  (begin
    ;; Only admin can emergency update
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    
    ;; Update liquidity without checks
    (let ((position (get-liquidity-position pool provider)))
      (if (is-some position)
          (begin
            (map-set liquidity-positions { pool: pool, provider: provider } {
              liquidity-amount: new-liquidity,
              pool-shares: (get position pool-shares),
              last-deposit: (get position last-deposit),
              rewards-earned: (get position rewards-earned),
              rewards-claimed: (get position rewards-claimed),
              fee-tier: (get position fee-tier)
            })
            
            (ok true)
          )
          (err ERR_NOT_PROVIDER)
      )
    )
  )
)

(define-public (emergency-reset-provider (provider principal))
  (begin
    ;; Only admin can emergency reset
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    
    ;; Remove all positions for provider
    ;; This would require iterating through all pools
    ;; Simplified implementation
    
    ;; Reset provider stats
    (map-set provider-stats { provider: provider } {
      total-liquidity: u0,
      total-rewards: u0,
      pool-count: u0,
      first-provision: block-height
    })
    
    (ok true)
  )
)
