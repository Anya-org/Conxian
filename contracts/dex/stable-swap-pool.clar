;; stable-swap-pool.clar
;; Conxian Protocol: Stable swap pool implementation for low-slippage stablecoin trading

;; Dependencies
(use-trait .sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait .defi-traits .defi-traits.defi-traits)

;; Constants
(define-constant ERR_INVALID_TOKEN (err 33001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err 33002))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err 33003))
(define-constant ERR_POOL_NOT_ACTIVE (err 33004))
(define-constant ERR_INVALID_AMOUNT (err 33005))

;; Stable swap parameters
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant A_PRECISION u1000) ;; Amplifier precision
(define-constant MIN_A u100) ;; Minimum amplifier
(define-constant MAX_A u10000) ;; Maximum amplifier
(define-constant MIN_LIQUIDITY u1000000) ;; 1 STX equivalent
(define-constant MAX_SLIPPAGE u500) ;; 5% max slippage
(define-constant SWAP_FEE u4) ;; 0.04% fee (lower than regular pools)

;; Data variables
(define-data-var pool-active bool true)
(define-data-var total-liquidity uint u0)
(define-data-var total-swaps uint u0)
(define-data-var amplifier uint u1000) ;; Default amplifier

;; Storage maps
(define-map pool-state { pool-id: (string-ascii 32) } { 
  token-0: principal,
  token-1: principal,
  reserve-0: uint,
  reserve-1: uint,
  total-liquidity: uint,
  amplifier: uint,
  fee-tier: uint,
  last-updated: uint,
  active: bool
})

(define-map liquidity-positions { owner: principal, pool-id: (string-ascii 32) } { 
  liquidity-amount: uint,
  token-0-deposited: uint,
  token-1-deposited: uint,
  last-deposit: uint,
  rewards-earned: uint
})

(define-map swap-history { swap-id: (buff 32) } { 
  pool-id: (string-ascii 32),
  token-in: principal,
  amount-in: uint,
  token-out: principal,
  amount-out: uint,
  fee: uint,
  timestamp: uint,
  user: principal
})

(define-map pool-statistics { pool-id: (string-ascii 32) } { 
  total-swaps: uint,
  total-volume: uint,
  total-fees: uint,
  average-slippage: uint,
  last-swap: uint
})

;; Events
(define-event (pool-created (pool-id (string-ascii 32)) (token-0 principal) (token-1 principal)))
(define-event (liquidity-added (pool-id (string-ascii 32)) (owner principal) (amount-0 uint) (amount-1 uint)))
(define-event (liquidity-removed (pool-id (string-ascii 32)) (owner principal) (amount-0 uint) (amount-1 uint)))
(define-event (swap-executed (pool-id (string-ascii 32)) (token-in principal) (amount-in uint) (token-out principal) (amount-out uint)))
(define-event (amplifier-updated (pool-id (string-ascii 32)) (old-amplifier uint) (new-amplifier uint)))
(define-event (pool-activated (pool-id (string-ascii 32)))
(define-event (pool-deactivated (pool-id (string-ascii 32)))

;; Read-only functions

(define-read-only (get-pool-state (pool-id (string-ascii 32)))
  (map-get? pool-state { pool-id: pool-id }))

(define-read-only (get-pool-reserves (pool-id (string-ascii 32)))
  (match (get-pool-state pool-id)
    pool (ok { reserve-0: (get pool reserve-0), reserve-1: (get pool reserve-1) })
    none (ok { reserve-0: u0, reserve-1: u0 })
  )
)

(define-read-only (get-pool-tokens (pool-id (string-ascii 32)))
  (match (get-pool-state pool-id)
    pool (ok { token-0: (get pool token-0), token-1: (get pool token-1) })
    none (ok { token-0: tx-sender, token-1: tx-sender })
  )
)

(define-read-only (get-pool-amplifier (pool-id (string-ascii 32)))
  (match (get-pool-state pool-id)
    pool (ok (get pool amplifier))
    none (ok u1000)
  )
)

(define-read-only (get-liquidity-position (owner principal) (pool-id (string-ascii 32)))
  (map-get? liquidity-positions { owner: owner, pool-id: pool-id }))

(define-read-only (get-swap-history (swap-id (buff 32)))
  (map-get? swap-history { swap-id: swap-id }))

(define-read-only (get-pool-statistics (pool-id (string-ascii 32)))
  (map-get? pool-statistics { pool-id: pool-id }))

(define-read-only (is-pool-active (pool-id (string-ascii 32)))
  (match (get-pool-state pool-id)
    pool (ok (get pool active))
    none (ok false)
  )
)

(define-read-only (is-pool-active-global)
  (var-get pool-active))

(define-read-only (get-total-liquidity)
  (var-get total-liquidity))

(define-read-only (get-total-swaps)
  (var-get total-swaps))

;; Public functions

(define-public (create-stable-pool (pool-id (string-ascii 32)) (token-0 principal) (token-1 principal) (initial-amount-0 uint) (initial-amount-1 uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool-id) u0) ERR_INVALID_TOKEN)
    (asserts! (principal? token-0) ERR_INVALID_TOKEN)
    (asserts! (principal? token-1) ERR_INVALID_TOKEN)
    (asserts! (not (is-eq token-0 token-1)) ERR_INVALID_TOKEN)
    (asserts! (> initial-amount-0 u0) ERR_INVALID_AMOUNT)
    (asserts! (> initial-amount-1 u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool already exists
    (let ((existing_pool (get-pool-state pool-id)))
      (asserts! (is-none existing_pool) ERR_INVALID_TOKEN)
      
      ;; Create pool
      (map-set pool-state { pool-id: pool-id } {
        token-0: token-0,
        token-1: token-1,
        reserve-0: initial-amount-0,
        reserve-1: initial-amount-1,
        total-liquidity: (calculate-liquidity initial-amount-0 initial-amount-1 u1000),
        amplifier: u1000,
        fee-tier: SWAP_FEE,
        last-updated: block-height,
        active: true
      })
      
      ;; Initialize statistics
      (map-set pool-statistics { pool-id: pool-id } {
        total-swaps: u0,
        total-volume: u0,
        total-fees: u0,
        average-slippage: u0,
        last-swap: u0
      })
      
      ;; Update global totals
      (var-set total-liquidity (+ (var-get total-liquidity) (calculate-liquidity initial-amount-0 initial-amount-1 u1000)))
      
      ;; Emit event
      (emit-event (pool-created pool_id token-0 token-1))
      
      (ok {
        pool-id: pool-id,
        token-0: token-0,
        token-1: token-1,
        reserve-0: initial-amount-0,
        reserve-1: initial-amount-1,
        total-liquidity: (calculate-liquidity initial-amount-0 initial-amount-1 u1000)
      })
    )
  )
)

(define-public (add-liquidity (pool-id (string-ascii 32)) (amount-0 uint) (amount-1 uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool-id) u0) ERR_INVALID_TOKEN)
    (asserts! (> amount-0 u0) ERR_INVALID_AMOUNT)
    (asserts! (> amount-1 u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Calculate liquidity to mint
        (let ((liquidity-to-mint (calculate-liquidity amount-0 amount-1 (get pool amplifier))))
          
          ;; Update pool reserves
          (map-set pool-state { pool-id: pool-id } {
            token-0: (get pool token-0),
            token-1: (get pool token-1),
            reserve-0: (+ (get pool reserve-0) amount-0),
            reserve-1: (+ (get pool reserve-1) amount-1),
            total-liquidity: (+ (get pool total-liquidity) liquidity-to-mint),
            amplifier: (get pool amplifier),
            fee-tier: (get pool fee-tier),
            last-updated: block-height,
            active: (get pool active)
          })
          
          ;; Update liquidity position
          (let ((existing-position (get-liquidity-position tx-sender pool_id)))
            (if (is-some existing-position)
                (begin
                  (let ((position (unwrap-optional existing-position)))
                    (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                      liquidity-amount: (+ (get position liquidity-amount) liquidity-to-mint),
                      token-0-deposited: (+ (get position token-0-deposited) amount-0),
                      token-1-deposited: (+ (get position token-1-deposited) amount-1),
                      last-deposit: block-height,
                      rewards-earned: (get position rewards-earned)
                    })
                  )
                )
                ;; Create new position
                (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                  liquidity-amount: liquidity-to-mint,
                  token-0-deposited: amount-0,
                  token-1-deposited: amount-1,
                  last-deposit: block-height,
                  rewards-earned: u0
                })
            )
          )
          
          ;; Update global totals
          (var-set total-liquidity (+ (var-get total-liquidity) liquidity-to-mint))
          
          ;; Emit event
          (emit-event (liquidity-added pool_id tx-sender amount-0 amount-1))
          
          (ok {
            liquidity-minted: liquidity-to-mint,
            new-reserve-0: (+ (get pool reserve-0) amount-0),
            new-reserve-1: (+ (get pool reserve-1) amount-1)
          })
        )
      )
    )
  )
)

(define-public (remove-liquidity (pool-id (string-ascii 32)) (liquidity-amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_TOKEN)
    (asserts! (> liquidity-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Check user's liquidity position
        (let ((position (get-liquidity-position tx-sender pool_id)))
          (asserts! (is-some position) ERR_INSUFFICIENT_LIQUIDITY)
          
          (let ((user-position (unwrap-optional position)))
            (asserts! (>= (get user-position liquidity-amount) liquidity-amount) ERR_INSUFFICIENT_LIQUIDITY)
            
            ;; Calculate amounts to withdraw
            (let ((withdraw-0 (/ (* liquidity-amount (get pool reserve-0)) (get pool total-liquidity)))
                  (withdraw-1 (/ (* liquidity-amount (get pool reserve-1)) (get pool total-liquidity))))
              
              ;; Update pool reserves
              (map-set pool-state { pool-id: pool_id } {
                token-0: (get pool token-0),
                token-1: (get pool token-1),
                reserve-0: (- (get pool reserve-0) withdraw-0),
                reserve-1: (- (get pool reserve-1) withdraw-1),
                total-liquidity: (- (get pool total-liquidity) liquidity-amount),
                amplifier: (get pool amplifier),
                fee-tier: (get pool fee-tier),
                last-updated: block-height,
                active: (get pool active)
              })
              
              ;; Update user position
              (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                liquidity-amount: (- (get user-position liquidity-amount) liquidity-amount),
                token-0-deposited: (get user-position token-0-deposited),
                token-1-deposited: (get user-position token-1-deposited),
                last-deposit: (get user-position last-deposit),
                rewards-earned: (get user-position rewards-earned)
              })
              
              ;; Update global totals
              (var-set total-liquidity (- (var-get total-liquidity) liquidity-amount))
              
              ;; Emit event
              (emit-event (liquidity-removed pool_id tx-sender withdraw-0 withdraw-1))
              
              (ok {
                amount-0: withdraw-0,
                amount-1: withdraw-1,
                remaining-liquidity: (- (get user-position liquidity-amount) liquidity-amount)
              })
            )
          )
        )
      )
    )
  )
)

(define-public (swap (pool-id (string-ascii 32)) (token-in principal) (amount-in uint) (min-amount-out uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_TOKEN)
    (asserts! (principal? token-in) ERR_INVALID_TOKEN)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    (asserts! (> min-amount-out u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Determine which token is being swapped in
        (let ((is-token-0 (is-eq token-in (get pool token-0)))
              (reserve-in (if is-token-0 (get pool reserve-0) (get pool reserve-1)))
              (reserve-out (if is-token-0 (get pool reserve-1) (get pool reserve-0)))
              (token-out (if is-token-0 (get pool token-1) (get pool token-0))))
          
          ;; Calculate output using stable swap formula
          (let ((output-amount (calculate-stable-swap-output amount-in reserve-in reserve-out (get pool amplifier)))
                (fee (/ (* amount-in SWAP_FEE) u10000)))
            
            ;; Check slippage
            (let ((slippage (/ (* (- amount-in output-amount) u10000) amount-in)))
              (asserts! (<= slippage MAX_SLIPPAGE) ERR_SLIPPAGE_TOO_HIGH)
              
              ;; Check minimum output
              (asserts! (>= output-amount min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
              
              ;; Generate swap ID
              (let ((swap-id (hash160 (concat (principal-to-buff? tx-sender) (int-to-buff block-height))))
                
                ;; Update pool reserves
                (map-set pool-state { pool-id: pool_id } {
                  token-0: (get pool token-0),
                  token-1: (get pool token-1),
                  reserve-0: (if is-token-0 (+ (get pool reserve-0) amount-in) (- (get pool reserve-0) output-amount)),
                  reserve-1: (if is-token-0 (- (get pool reserve-1) output-amount) (+ (get pool reserve-1) amount-in)),
                  total-liquidity: (get pool total-liquidity),
                  amplifier: (get pool amplifier),
                  fee-tier: (get pool fee-tier),
                  last-updated: block-height,
                  active: (get pool active)
                })
                
                ;; Create swap record
                (map-set swap-history { swap-id: swap-id } {
                  pool-id: pool_id,
                  token-in: token-in,
                  amount-in: amount-in,
                  token-out: token-out,
                  amount-out: output-amount,
                  fee: fee,
                  timestamp: block-height,
                  user: tx-sender
                })
                
                ;; Update statistics
                (let ((stats (get-pool-statistics pool_id)))
                  (if (is-some stats)
                      (begin
                        (let ((current-stats (unwrap-optional stats)))
                          (map-set pool-statistics { pool-id: pool_id } {
                            total-swaps: (+ (get current-stats total-swaps) u1),
                            total-volume: (+ (get current-stats total-volume) amount-in),
                            total-fees: (+ (get current-stats total-fees) fee),
                            average-slippage: (/ (+ (* (get current-stats average-slippage) (get current-stats total-swaps)) slippage) (+ (get current-stats total-swaps) u1)),
                            last-swap: block-height
                          })
                        )
                      )
                      ;; Create new statistics
                      (map-set pool-statistics { pool-id: pool_id } {
                        total-swaps: u1,
                        total-volume: amount-in,
                        total-fees: fee,
                        average-slippage: slippage,
                        last-swap: block-height
                      })
                  )
                )
                
                ;; Update global counters
                (var-set total-swaps (+ (var-get total-swaps) u1))
                
                ;; Emit event
                (emit-event (swap-executed pool_id token-in amount-in token-out output-amount))
                
                (ok {
                  amount-out: output-amount,
                  fee: fee,
                  slippage: slippage,
                  swap-id: swap-id
                })
              )
            )
          )
        )
      )
    )
  )
)

(define-public (update-amplifier (pool-id (string-ascii 32)) (new-amplifier uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_TOKEN)
    (asserts! (>= new-amplifier MIN_A) ERR_INVALID_TOKEN)
    (asserts! (<= new-amplifier MAX_A) ERR_INVALID_TOKEN)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Update amplifier
        (let ((old-amplifier (get pool amplifier)))
          (map-set pool-state { pool-id: pool_id } {
            token-0: (get pool token-0),
            token-1: (get pool token-1),
            reserve-0: (get pool reserve-0),
            reserve-1: (get pool reserve-1),
            total-liquidity: (get pool total-liquidity),
            amplifier: new-amplifier,
            fee-tier: (get pool fee-tier),
            last-updated: block-height,
            active: (get pool active)
          })
          
          ;; Update global amplifier
          (var-set amplifier new-amplifier)
          
          ;; Emit event
          (emit-event (amplifier-updated pool_id old-amplifier new-amplifier))
          
          (ok {
            old-amplifier: old-amplifier,
            new-amplifier: new-amplifier
          })
        )
      )
    )
  )
)

(define-public (activate-pool (pool-id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_TOKEN)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        ;; Activate pool
        (map-set pool-state { pool-id: pool_id } {
          token-0: (get pool token-0),
          token-1: (get pool token-1),
          reserve-0: (get pool reserve-0),
          reserve-1: (get pool reserve-1),
          total-liquidity: (get pool total-liquidity),
          amplifier: (get pool amplifier),
          fee-tier: (get pool fee-tier),
          last-updated: block-height,
          active: true
        })
        
        ;; Emit event
        (emit-event (pool-activated pool_id))
        
        (ok true)
      )
    )
  )
)

(define-public (deactivate-pool (pool-id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_TOKEN)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists
    (let ((pool_info (get-pool-state pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_ACTIVE)
      
      (let ((pool (unwrap-optional pool_info)))
        ;; Deactivate pool
        (map-set pool-state { pool-id: pool_id } {
          token-0: (get pool token-0),
          token-1: (get pool token-1),
          reserve-0: (get pool reserve-0),
          reserve-1: (get pool reserve-1),
          total-liquidity: (get pool total-liquidity),
          amplifier: (get pool amplifier),
          fee-tier: (get pool fee-tier),
          last-updated: block-height,
          active: false
        })
        
        ;; Emit event
        (emit-event (pool-deactivated pool_id))
        
        (ok true)
      )
    )
  )
)

(define-public (set-pool-active (active bool))
  (begin
    ;; Only admin can set pool status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_POOL_NOT_ACTIVE)
    
    (var-set pool-active active)
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { liquidity-amount: uint, token-0-deposited: uint, token-1-deposited: uint, last-deposit: uint, rewards-earned: uint } option))

(define-private (calculate-liquidity (amount-0 uint) (amount-1 uint) (amplifier uint))
  (begin
    ;; Calculate liquidity using stable swap formula
    ;; D = (x * y)^(1/2) when A = 0
    ;; D = ((x * y)^(1/2) + (x + y) / 2) when A > 0
    
    (if (is-eq amplifier u0)
        (sqrt (* amount-0 amount-1))
        (let ((sqrt-product (sqrt (* amount-0 amount-1)))
              (sum (/ (+ amount-0 amount-1) u2)))
          (/ (+ sqrt-product sum) u2)
        )
    )
  )
)

(define-private (sqrt (value uint))
  (begin
    ;; Simplified square root calculation
    ;; In practice, would use proper square root algorithm
    
    (if (is-eq value u0)
        u0
        (if (is-eq value PRECISION)
            u1
            (/ value u1000) // Simplified approximation
        )
    )
  )
)

(define-private (calculate-stable-swap-output (amount-in uint) (reserve-in uint) (reserve-out uint) (amplifier uint))
  (begin
    ;; Calculate output using stable swap formula
    ;; y = ((x * y)^(1/2) + (x + y) / 2) - x when A > 0
    
    (let ((x (+ reserve-in amount-in))
          (y reserve-out)
          (A amplifier))
      
      (if (is-eq A u0)
          ;; Constant product formula
          (/ (* reserve-out amount-in) (+ reserve-in amount-in))
          ;; Stable swap formula
          (let ((sqrt-xy (sqrt (* x y)))
                (sum (/ (+ x y) u2)))
            (- sum x)
          )
      )
    )
  )
)

;; Utility functions

(define-read-only (get-pool-status)
  {
    active: (var-get pool-active),
    total-liquidity: (var-get total-liquidity),
    total-swaps: (var-get total-swaps),
    amplifier: (var-get amplifier)
  }
)

(define-read-only (get-pool-summary (pool-id (string-ascii 32)))
  (match (get-pool-state pool_id)
    pool
      (ok {
        pool-id: pool_id,
        token-0: (get pool token-0),
        token-1: (get pool token-1),
        reserve-0: (get pool reserve-0),
        reserve-1: (get pool reserve-1),
        total-liquidity: (get pool total-liquidity),
        amplifier: (get pool amplifier),
        active: (get pool active),
        fee-tier: (get pool fee-tier)
      })
    none (err ERR_POOL_NOT_ACTIVE)
  )
)
