;; weighted-swap-pool.clar
;; Conxian Protocol: Weighted swap pool implementation for custom token ratios

;; Dependencies
(use-trait .sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait .defi-traits .defi-traits.defi-traits)

;; Constants
(define-constant ERR_INVALID_WEIGHT (err 41001))
(define-constant ERR_WEIGHT_SUM_MISMATCH (err 41002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err 41003))
(define-constant ERR_POOL_NOT_ACTIVE (err 41004))
(define-constant ERR_INVALID_AMOUNT (err 41005))

;; Weighted pool parameters
(define-constant PRECISION u1000000) ;; 6 decimal places
(define-constant WEIGHT_PRECISION u10000) ;; 4 decimal places for weights
(define-constant MIN_WEIGHT u1000) ;; 10% minimum weight
(define-constant MAX_WEIGHT u9000) ;; 90% maximum weight
(define-constant MIN_LIQUIDITY u1000000) ;; 1 STX equivalent
(define-constant SWAP_FEE u300) ;; 0.3% fee
(define-constant MAX_TOKENS u10) ;; Maximum tokens per pool

;; Data variables
(define-data-var pool-active bool true)
(define-data-var total-pools uint u0)
(define-data-var total-liquidity uint u0)
(define-data-var total-swaps uint u0)

;; Storage maps
(define-map weighted-pools { pool-id: (string-ascii 32) } { 
  tokens: (list 10 principal),
  weights: (list 10 uint),
  reserves: (list 10 uint),
  total-liquidity: uint,
  fee-tier: uint,
  last-updated: uint,
  active: bool,
  created-at: uint
})

(define-map liquidity-positions { owner: principal, pool-id: (string-ascii 32) } { 
  liquidity-amount: uint,
  token-deposits: (list 10 { token: principal, amount: uint }),
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
(define-event (pool-created (pool-id (string-ascii 32)) (tokens (list 10 principal)) (weights (list 10 uint))))
(define-event (liquidity-added (pool-id (string-ascii 32)) (owner principal) (liquidity-amount uint)))
(define-event (liquidity-removed (pool-id (string-ascii 32)) (owner principal) (liquidity-amount uint)))
(define-event (swap-executed (pool-id (string-ascii 32)) (token-in principal) (amount-in uint) (token-out principal) (amount-out uint)))
(define-event (weights-updated (pool-id (string-ascii 32)) (old-weights (list 10 uint)) (new-weights (list 10 uint))))
(define-event (pool-activated (pool-id (string-ascii 32)))
(define-event (pool-deactivated (pool-id (string-ascii 32)))

;; Read-only functions

(define-read-only (get-weighted-pool (pool-id (string-ascii 32)))
  (map-get? weighted-pools { pool-id: pool-id }))

(define-read-only (get-pool-tokens (pool-id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool (ok (get pool tokens))
    none (ok (list 0 principal))
  )
)

(define-read-only (get-pool-weights (pool-id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool (ok (get pool weights))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-pool-reserves (pool-id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool (ok (get pool reserves))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-pool-liquidity (pool-id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool (ok (get pool total-liquidity))
    none (ok u0)
  )
)

(define-read-only (is-pool-active (pool-id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool (ok (get pool active))
    none (ok false)
  )
)

(define-read-only (get-liquidity-position (owner principal) (pool-id (string-ascii 32)))
  (map-get? liquidity-positions { owner: owner, pool-id: pool_id }))

(define-read-only (get-swap-history (swap-id (buff 32)))
  (map-get? swap-history { swap-id: swap_id }))

(define-read-only (get-pool-statistics (pool-id (string-ascii 32)))
  (map-get? pool-statistics { pool-id: pool_id }))

(define-read-only (is-pool-active-global)
  (var-get pool-active))

(define-read-only (get-total-pools)
  (var-get total-pools))

(define-read-only (get-total-liquidity)
  (var-get total-liquidity))

;; Public functions

(define-public (create-weighted-pool (pool-id (string-ascii 32)) (tokens (list 10 principal)) (weights (list 10 uint)) (initial-deposits (list 10 uint)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len tokens) u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (len tokens) (len weights)) ERR_WEIGHT_SUM_MISMATCH)
    (asserts! (is-eq (len tokens) (len initial-deposits)) ERR_WEIGHT_SUM_MISMATCH)
    (asserts! (<= (len tokens) MAX_TOKENS) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Validate weights
    (asserts! (validate-weights weights) ERR_INVALID_WEIGHT)
    
    ;; Validate initial deposits
    (asserts! (validate-initial-deposits tokens initial_deposits) ERR_INVALID_AMOUNT)
    
    ;; Check if pool already exists
    (let ((existing_pool (get-weighted-pool pool_id)))
      (asserts! (is-none existing_pool) ERR_INVALID_AMOUNT)
      
      ;; Create pool
      (map-set weighted-pools { pool-id: pool_id } {
        tokens: tokens,
        weights: weights,
        reserves: initial_deposits,
        total-liquidity: (calculate-liquidity initial_deposits weights),
        fee-tier: SWAP_FEE,
        last-updated: block-height,
        active: true,
        created-at: block-height
      })
      
      ;; Initialize statistics
      (map-set pool-statistics { pool-id: pool_id } {
        total-swaps: u0,
        total-volume: u0,
        total-fees: u0,
        average-slippage: u0,
        last-swap: u0
      })
      
      ;; Update global counters
      (var-set total-pools (+ (var-get total-pools) u1))
      (var-set total-liquidity (+ (var-get total-liquidity) (calculate-liquidity initial_deposits weights)))
      
      ;; Emit event
      (emit-event (pool-created pool_id tokens weights))
      
      (ok {
        pool-id: pool_id,
        tokens: tokens,
        weights: weights,
        initial-liquidity: (calculate-liquidity initial_deposits weights),
        created-at: block-height
      })
    )
  )
)

(define-public (add-liquidity (pool-id (string-ascii 32)) (deposits (list 10 uint)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len deposits) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Validate deposits match pool tokens
        (asserts! (is-eq (len deposits) (len (get pool tokens))) ERR_INVALID_AMOUNT)
        
        ;; Calculate liquidity to mint
        (let ((liquidity-to-mint (calculate-liquidity deposits (get pool weights))))
          
          ;; Update pool reserves
          (let ((new-reserves (add-reserves (get pool reserves) deposits)))
            (map-set weighted-pools { pool-id: pool_id } {
              tokens: (get pool tokens),
              weights: (get pool weights),
              reserves: new-reserves,
              total-liquidity: (+ (get pool total-liquidity) liquidity-to-mint),
              fee-tier: (get pool fee-tier),
              last-updated: block-height,
              active: (get pool active),
              created-at: (get pool created-at)
            })
          )
          
          ;; Update liquidity position
          (let ((existing-position (get-liquidity-position tx-sender pool_id)))
            (if (is-some existing_position)
                (begin
                  (let ((position (unwrap-optional existing_position)))
                    (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                      liquidity-amount: (+ (get position liquidity-amount) liquidity-to-mint),
                      token-deposits: (add-token-deposits (get position token-deposits) deposits),
                      last-deposit: block-height,
                      rewards-earned: (get position rewards-earned)
                    })
                  )
                )
                ;; Create new position
                (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                  liquidity-amount: liquidity-to-mint,
                  token-deposits: deposits,
                  last-deposit: block-height,
                  rewards-earned: u0
                })
            )
          )
          
          ;; Update global counters
          (var-set total-liquidity (+ (var-get total-liquidity) liquidity-to-mint))
          
          ;; Emit event
          (emit-event (liquidity-added pool_id tx-sender liquidity-to-mint))
          
          (ok {
            liquidity-minted: liquidity-to-mint,
            new-reserves: new-reserves,
            total-liquidity: (+ (get pool total-liquidity) liquidity-to-mint)
          })
        )
      )
    )
  )
)

(define-public (remove-liquidity (pool_id (string-ascii 32)) (liquidity-amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (> liquidity-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Check user's liquidity position
        (let ((position (get-liquidity-position tx-sender pool_id)))
          (asserts! (is-some position) ERR_INSUFFICIENT_LIQUIDITY)
          
          (let ((user-position (unwrap-optional position)))
            (asserts! (>= (get user-position liquidity-amount) liquidity-amount) ERR_INSUFFICIENT_LIQUIDITY)
            
            ;; Calculate amounts to withdraw
            (let ((withdraw-amounts (calculate-withdrawal-amounts liquidity-amount (get pool total-liquidity) (get pool reserves))))
              
              ;; Update pool reserves
              (let ((new-reserves (subtract-reserves (get pool reserves) withdraw-amounts)))
                (map-set weighted-pools { pool-id: pool_id } {
                  tokens: (get pool tokens),
                  weights: (get pool weights),
                  reserves: new-reserves,
                  total-liquidity: (- (get pool total-liquidity) liquidity-amount),
                  fee-tier: (get pool fee-tier),
                  last-updated: block-height,
                  active: (get pool active),
                  created-at: (get pool created-at)
                })
              )
              
              ;; Update user position
              (map-set liquidity-positions { owner: tx-sender, pool-id: pool_id } {
                liquidity-amount: (- (get user-position liquidity-amount) liquidity-amount),
                token-deposits: (get user-position token-deposits),
                last-deposit: (get user-position last-deposit),
                rewards-earned: (get user-position rewards-earned)
              })
              
              ;; Update global counters
              (var-set total-liquidity (- (var-get total-liquidity) liquidity-amount))
              
              ;; Emit event
              (emit-event (liquidity-removed pool_id tx-sender liquidity-amount))
              
              (ok {
                withdrawn-amounts: withdraw-amounts,
                remaining-liquidity: (- (get user-position liquidity-amount) liquidity-amount)
              })
            )
          )
        )
      )
    )
  )

(define-public (swap (pool_id (string-ascii 32)) (token-in principal) (amount-in uint) (token-out principal) (min-amount-out uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (principal? token-in) ERR_INVALID_AMOUNT)
    (asserts! (principal? token-out) ERR_INVALID_AMOUNT)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    (asserts! (> min-amount-out u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq token-in token_out)) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists and is active
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        (asserts! (get pool active) ERR_POOL_NOT_ACTIVE)
        
        ;; Check if tokens are in pool
        (asserts! (is-token-in-pool (get pool tokens) token-in) ERR_INVALID_AMOUNT)
        (asserts! (is-token-in-pool (get pool tokens) token_out) ERR_INVALID_AMOUNT)
        
        ;; Calculate output using weighted formula
        (let ((output-amount (calculate-weighted-swap-output pool token-in amount-in token-out))
              (fee (/ (* amount-in SWAP_FEE) u10000)))
          
          ;; Check minimum output
          (asserts! (>= output-amount min-amount-out) ERR_INVALID_AMOUNT)
          
          ;; Generate swap ID
          (let ((swap-id (hash160 (concat (principal-to-buff? tx-sender) (int-to-buff block-height))))
            
            ;; Update pool reserves
            (let ((new-reserves (update-reserves-for-swap (get pool reserves) token-in amount-in token-out output-amount)))
              (map-set weighted-pools { pool-id: pool_id } {
                tokens: (get pool tokens),
                weights: (get pool weights),
                reserves: new-reserves,
                total-liquidity: (get pool total-liquidity),
                fee-tier: (get pool fee-tier),
                last-updated: block-height,
                active: (get pool active),
                created-at: (get pool created-at)
              })
            )
            
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
                        average-slippage: (get current-stats average-slippage),
                        last-swap: block-height
                      })
                    )
                  )
                  ;; Create new statistics
                  (map-set pool-statistics { pool-id: pool_id } {
                    total-swaps: u1,
                    total-volume: amount-in,
                    total-fees: fee,
                    average-slippage: u0,
                    last-swap: block-height
                  })
              )
            )
            
            ;; Update global counters
            (var-set total-swaps (+ (var-get total-swaps) u1))
            
            ;; Emit event
            (emit-event (swap-executed pool_id token-in amount-in token_out output-amount))
            
            (ok {
              amount-out: output-amount,
              fee: fee,
              swap-id: swap-id
            })
          )
        )
      )
    )
  )
)

(define-public (update-weights (pool_id (string-ascii 32)) (new-weights (list 10 uint)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len new-weights) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        ;; Validate new weights
        (asserts! (validate-weights new-weights) ERR_INVALID_WEIGHT)
        
        ;; Update pool weights
        (map-set weighted-pools { pool-id: pool_id } {
          tokens: (get pool tokens),
          weights: new-weights,
          reserves: (get pool reserves),
          total-liquidity: (get pool total-liquidity),
          fee-tier: (get pool fee-tier),
          last-updated: block-height,
          active: (get pool active),
          created-at: (get pool created-at)
        })
        
        ;; Emit event
        (emit-event (weights-updated pool_id (get pool weights) new-weights))
        
        (ok {
          old-weights: (get pool weights),
          new-weights: new-weights,
          updated-at: block-height
        })
      )
    )
  )
)

(define-public (activate-pool (pool_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        ;; Activate pool
        (map-set weighted-pools { pool-id: pool_id } {
          tokens: (get pool tokens),
          weights: (get pool weights),
          reserves: (get pool reserves),
          total-liquidity: (get pool total-liquidity),
          fee-tier: (get pool fee-tier),
          last-updated: block-height,
          active: true,
          created-at: (get pool created-at)
        })
        
        ;; Emit event
        (emit-event (pool-activated pool_id))
        
        (ok true)
      )
    )
  )
)

(define-public (deactivate-pool (pool_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool_id) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
    
    ;; Check if pool exists
    (let ((pool_info (get-weighted-pool pool_id)))
      (asserts! (is-some pool_info) ERR_POOL_NOT_FOUND)
      
      (let ((pool (unwrap-optional pool_info)))
        ;; Deactivate pool
        (map-set weighted-pools { pool-id: pool_id } {
          tokens: (get pool tokens),
          weights: (get pool weights),
          reserves: (get pool reserves),
          total-liquidity: (get pool total-liquidity),
          fee-tier: (get pool fee-tier),
          last-updated: block-height,
          active: false,
          created-at: (get pool created-at)
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

(define-private (validate-weights (weights (list 10 uint)))
  (begin
    ;; Check that all weights are within valid range
    (fold weights true
      (lambda ((valid bool) (weight uint))
        (and 
          valid
          (>= weight MIN_WEIGHT)
          (<= weight MAX_WEIGHT)
        )
      )
    )
  )
)

(define-private (validate-initial-deposits (tokens (list 10 principal)) (deposits (list 10 uint)))
  (begin
    ;; Check that all deposits are positive
    (fold deposits true
      (lambda ((valid bool) (deposit uint))
        (and valid (> deposit u0))
      )
    )
  )
)

(define-private (calculate-liquidity (reserves (list 10 uint)) (weights (list 10 uint)))
  (begin
    ;; Calculate liquidity using weighted geometric mean
    (let ((weighted-product (fold reserves u1
      (lambda ((product uint) (reserve uint) (index uint))
        (* product (pow reserve (/ (get weights index) WEIGHT_PRECISION)))
      ))))
      
      (pow weighted-product (/ u10000 (len reserves)))
    )
  )
)

(define-private (add-reserves (reserves (list 10 uint)) (deposits (list 10 uint)))
  (begin
    ;; Add deposits to reserves
    (fold reserves (list 0 uint)
      (lambda ((result (list 10 uint)) (deposit uint) (index uint))
        (let ((current-reserve (get reserves index)))
          (append result (+ current-reserve deposit))
        )
      )
    )
  )
)

(define-private (subtract-reserves (reserves (list 10 uint)) (withdrawals (list 10 uint)))
  (begin
    ;; Subtract withdrawals from reserves
    (fold reserves (list 0 uint)
      (lambda ((result (list 10 uint)) (withdrawal uint) (index uint))
        (let ((current-reserve (get reserves index)))
          (append result (- current-reserve withdrawal))
        )
      )
    )
  )
)

(define-private (calculate-withdrawal-amounts (liquidity-amount uint) (total-liquidity uint) (reserves (list 10 uint)))
  (begin
    ;; Calculate withdrawal amounts based on liquidity share
    (fold reserves (list 0 uint)
      (lambda ((result (list 10 uint)) (reserve uint))
        (let ((share (/ (* liquidity-amount reserve) total-liquidity)))
          (append result share)
        )
      )
    )
  )
)

(define-private (is-token-in-pool (tokens (list 10 principal)) (token principal))
  (begin
    ;; Check if token is in pool
    (fold tokens false
      (lambda ((found bool) (pool-token principal))
        (or found (is-eq pool-token token))
      )
    )
  )
)

(define-private (get-token-index (tokens (list 10 principal)) (token principal))
  (begin
    ;; Get index of token in pool
    (fold tokens u100
      (lambda ((result uint) (pool-token principal) (index uint))
        (if (is-eq pool-token token)
            index
            result
        )
      )
    )
  )
)

(define-private (calculate-weighted-swap-output (pool { tokens: (list 10 principal), weights: (list 10 uint), reserves: (list 10 uint), total-liquidity: uint, fee-tier: uint, last-updated: uint, active: bool, created-at: uint }) (token-in principal) (amount-in uint) (token-out principal))
  (begin
    ;; Calculate output using weighted AMM formula
    (let ((token-in-index (get-token-index (get pool tokens) token-in))
          (token-out-index (get-token-index (get pool tokens) token-out))
          (weight-in (get weights token-in-index))
          (weight-out (get weights token-out-index))
          (reserve-in (get reserves token-in-index))
          (reserve-out (get reserves token-out-index)))
      
      ;; Weighted swap formula: Y_out = Y_in * (X_out / X_in)^(W_in/W_out)
      (let ((weight-ratio (/ weight-in weight-out))
            (reserve-ratio (/ reserve-out reserve-in)))
        
        (* amount-in (pow reserve-ratio weight-ratio))
      )
    )
  )
)

(define-private (update-reserves-for-swap (reserves (list 10 uint)) (token-in principal) (amount-in uint) (token-out principal) (amount-out uint))
  (begin
    ;; Update reserves for swap
    (let ((token-in-index (get-token-index (get pool tokens) token-in))
          (token-out-index (get-token-index (get pool tokens) token-out)))
      
      (fold reserves (list 0 uint)
        (lambda ((result (list 10 uint)) (reserve uint) (index uint))
          (if (is-eq index token-in-index)
              (append result (+ reserve amount-in))
              (if (is-eq index token-out-index)
                  (append result (- reserve amount-out))
                  (append result reserve)
              )
          )
        )
      )
    )
  )
)

(define-private (add-token-deposits (current-deposits (list 10 { token: principal, amount: uint })) (new-deposits (list 10 uint)))
  (begin
    ;; Add new deposits to existing deposits
    (fold new-deposits current-deposits
      (lambda ((result (list 10 { token: principal, amount: uint })) (deposit uint) (index uint))
        (let ((current-deposit (get result index)))
          (let ((token (get current-deposit token)))
            (append result { token: token, amount: (+ (get current-deposit amount) deposit) })
          )
        )
      )
    )
  )
)

;; Utility functions

(define-read-only (get-pool-system-status)
  {
    active: (var-get pool-active),
    total-pools: (var-get total-pools),
    total-liquidity: (var-get total-liquidity),
    total-swaps: (var-get total-swaps)
  }
)

(define-read-only (get-pool-summary (pool_id (string-ascii 32)))
  (match (get-weighted-pool pool_id)
    pool
      (ok {
        pool-id: pool_id,
        tokens: (get pool tokens),
        weights: (get pool weights),
        reserves: (get pool reserves),
        total-liquidity: (get pool total-liquidity),
        active: (get pool active),
        fee-tier: (get pool fee-tier)
      })
    none (err ERR_POOL_NOT_FOUND)
  )
)
