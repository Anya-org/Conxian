;; Concentrated Liquidity Swap Logic
;; Implements advanced swap execution with tick crossing and fee calculation

;; Import required traits and libraries
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(use-trait math-trait .math-lib-advanced.advanced-math-trait)

;; Constants
(define-constant Q96 u79228162514264337593543950336) ;; 2^96 for price calculations
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision
(define-constant MAX_UINT_128 u340282366920938463463374607431768211455)

;; Error constants
(define-constant ERR_INSUFFICIENT_LIQUIDITY u5000)
(define-constant ERR_INVALID_SQRT_PRICE u5001)
(define-constant ERR_SLIPPAGE_EXCEEDED u5002)
(define-constant ERR_TICK_OUT_OF_BOUNDS u5003)
(define-constant ERR_AMOUNT_TOO_LARGE u5004)
(define-constant ERR_ZERO_LIQUIDITY u5005)

;; Swap state structure for complex swaps
(define-map swap-states
  {swap-id: uint}
  {amount-specified-remaining: int,
   amount-calculated: int,
   sqrt-price: uint,
   tick: int,
   liquidity: uint,
   fee-growth-global: uint})

;; Swap step structure for tick crossing
(define-map swap-steps
  {swap-id: uint, step: uint}
  {sqrt-price-start: uint,
   tick-next: int,
   initialized: bool,
   sqrt-price-next: uint,
   amount-in: uint,
   amount-out: uint,
   fee-amount: uint})

;; Swap cache for gas optimization
(define-map swap-cache
  {pool: principal}
  {liquidity-start: uint,
   block-timestamp: uint,
   fee-protocol: uint,
   unlocked: bool})

;; Main swap execution function
(define-public (execute-swap
  (pool principal)
  (zero-for-one bool)
  (amount-specified int)
  (sqrt-price-limit-x96 uint)
  (fee-tier uint))
  (let ((swap-id (generate-swap-id)))
    
    ;; Validate inputs
    (asserts! (not (is-eq amount-specified 0)) (err ERR_INSUFFICIENT_LIQUIDITY))
    (asserts! (> sqrt-price-limit-x96 u0) (err ERR_INVALID_SQRT_PRICE))
    
    ;; Get initial pool state
    (let ((pool-state (unwrap-panic (contract-call? pool get-pool-state))))
      
      (let ((initial-sqrt-price (get current-sqrt-price pool-state))
            (initial-tick (get current-tick pool-state))
            (initial-liquidity (get liquidity pool-state)))
        
        ;; Validate price limit
        (asserts! (if zero-for-one
                    (< sqrt-price-limit-x96 initial-sqrt-price)
                    (> sqrt-price-limit-x96 initial-sqrt-price))
                  (err ERR_INVALID_SQRT_PRICE))
        
        ;; Initialize swap state
        (map-set swap-states
          {swap-id: swap-id}
          {amount-specified-remaining: amount-specified,
           amount-calculated: 0,
           sqrt-price: initial-sqrt-price,
           tick: initial-tick,
           liquidity: initial-liquidity,
           fee-growth-global: (if zero-for-one
                               (get fee-growth-global-0 pool-state)
                               (get fee-growth-global-1 pool-state))})
        
        ;; Execute swap with tick crossing
        (let ((swap-result (execute-swap-with-ticks 
                           swap-id 
                           pool 
                           zero-for-one 
                           sqrt-price-limit-x96 
                           fee-tier)))
          
          ;; Update pool state with final results
          (try! (update-pool-after-swap pool swap-result zero-for-one))
          
          (ok swap-result))))))

;; Execute swap with tick crossing logic
(define-private (execute-swap-with-ticks
  (swap-id uint)
  (pool principal)
  (zero-for-one bool)
  (sqrt-price-limit uint)
  (fee-tier uint))
  (let ((state (unwrap-panic (map-get? swap-states {swap-id: swap-id}))))
    
    (if (is-eq (get amount-specified-remaining state) 0)
      ;; Swap complete
      {amount-0: (if zero-for-one 
                   (- (get amount-calculated state))
                   (get amount-calculated state)),
       amount-1: (if zero-for-one
                   (get amount-calculated state)
                   (- (get amount-calculated state))),
       sqrt-price-x96: (get sqrt-price state),
       liquidity: (get liquidity state),
       tick: (get tick state)}
      
      ;; Continue swapping
      (let ((step-result (execute-swap-step 
                         swap-id 
                         pool 
                         zero-for-one 
                         sqrt-price-limit 
                         fee-tier)))
        
        ;; Update state and continue if needed
        (let ((updated-state (update-swap-state-after-step swap-id step-result)))
          (execute-swap-with-ticks 
           swap-id 
           pool 
           zero-for-one 
           sqrt-price-limit 
           fee-tier))))))

;; Execute a single swap step
(define-private (execute-swap-step
  (swap-id uint)
  (pool principal)
  (zero-for-one bool)
  (sqrt-price-limit uint)
  (fee-tier uint))
  (let ((state (unwrap-panic (map-get? swap-states {swap-id: swap-id}))))
    
    ;; Find next initialized tick
    (let ((next-tick-data (find-next-initialized-tick 
                          pool 
                          (get tick state) 
                          zero-for-one)))
      
      (let ((tick-next (get tick next-tick-data))
            (initialized (get initialized next-tick-data)))
        
        ;; Calculate sqrt price for next tick
        (let ((sqrt-price-next (tick-to-sqrt-price tick-next)))
          
          ;; Determine target sqrt price for this step
          (let ((sqrt-price-target (if (if zero-for-one
                                         (< sqrt-price-next sqrt-price-limit)
                                         (> sqrt-price-next sqrt-price-limit))
                                     sqrt-price-limit
                                     sqrt-price-next)))
            
            ;; Compute swap within this step
            (let ((step-amounts (compute-swap-step
                                (get sqrt-price state)
                                sqrt-price-target
                                (get liquidity state)
                                (get amount-specified-remaining state)
                                fee-tier)))
              
              ;; Handle tick crossing if we reached next tick
              (let ((final-amounts (if (and initialized 
                                           (is-eq sqrt-price-target sqrt-price-next))
                                    (cross-tick 
                                     pool 
                                     tick-next 
                                     zero-for-one 
                                     step-amounts)
                                    step-amounts)))
                
                final-amounts))))))))

;; Compute swap amounts within a single step
(define-private (compute-swap-step
  (sqrt-price-current uint)
  (sqrt-price-target uint)
  (liquidity uint)
  (amount-remaining int)
  (fee-tier uint))
  (let ((zero-for-one (< sqrt-price-target sqrt-price-current))
        (exact-in (> amount-remaining 0)))
    
    (if exact-in
      ;; Exact input swap
      (let ((amount-in (to-uint amount-remaining))
            (fee-amount (calculate-fee-amount amount-in fee-tier))
            (amount-in-after-fee (- amount-in fee-amount)))
        
        (let ((amount-out (calculate-amount-out
                          sqrt-price-current
                          sqrt-price-target
                          liquidity
                          amount-in-after-fee
                          zero-for-one)))
          
          {amount-in: amount-in,
           amount-out: amount-out,
           fee-amount: fee-amount,
           sqrt-price-next: sqrt-price-target}))
      
      ;; Exact output swap
      (let ((amount-out (to-uint (- amount-remaining)))
            (amount-in (calculate-amount-in
                       sqrt-price-current
                       sqrt-price-target
                       liquidity
                       amount-out
                       zero-for-one)))
        
        (let ((fee-amount (calculate-fee-amount amount-in fee-tier)))
          
          {amount-in: (+ amount-in fee-amount),
           amount-out: amount-out,
           fee-amount: fee-amount,
           sqrt-price-next: sqrt-price-target})))))

;; Calculate amount out for exact input
(define-private (calculate-amount-out
  (sqrt-price-current uint)
  (sqrt-price-target uint)
  (liquidity uint)
  (amount-in uint)
  (zero-for-one bool))
  (if zero-for-one
    ;; Selling token0 for token1
    (let ((numerator (* liquidity (- sqrt-price-current sqrt-price-target)))
          (denominator (* sqrt-price-current sqrt-price-target)))
      (/ numerator denominator))
    
    ;; Selling token1 for token0
    (let ((price-diff (- sqrt-price-target sqrt-price-current)))
      (/ (* liquidity price-diff) PRECISION))))

;; Calculate amount in for exact output
(define-private (calculate-amount-in
  (sqrt-price-current uint)
  (sqrt-price-target uint)
  (liquidity uint)
  (amount-out uint)
  (zero-for-one bool))
  (if zero-for-one
    ;; Need token0 to get token1 out
    (let ((numerator (* amount-out sqrt-price-current sqrt-price-target))
          (denominator (* liquidity (- sqrt-price-current sqrt-price-target))))
      (/ numerator denominator))
    
    ;; Need token1 to get token0 out
    (let ((price-diff (- sqrt-price-target sqrt-price-current)))
      (/ (* amount-out PRECISION) (* liquidity price-diff)))))

;; Calculate fee amount based on fee tier
(define-private (calculate-fee-amount (amount uint) (fee-tier uint))
  (/ (* amount fee-tier) u1000000)) ;; fee-tier in basis points

;; Find next initialized tick
(define-private (find-next-initialized-tick
  (pool principal)
  (current-tick int)
  (zero-for-one bool))
  ;; Simplified implementation - in production would use tick bitmap
  (if zero-for-one
    ;; Moving down in price, find next lower tick
    {tick: (- current-tick 60), initialized: true}
    ;; Moving up in price, find next higher tick  
    {tick: (+ current-tick 60), initialized: true}))

;; Cross a tick and update liquidity
(define-private (cross-tick
  (pool principal)
  (tick int)
  (zero-for-one bool)
  (step-amounts (tuple (amount-in uint) (amount-out uint) (fee-amount uint) (sqrt-price-next uint))))
  (let ((tick-data (unwrap-panic (contract-call? pool get-tick-data tick))))
    
    ;; Update liquidity based on tick crossing direction
    (let ((liquidity-net (get liquidity-net tick-data))
          (liquidity-delta (if zero-for-one (- liquidity-net) liquidity-net)))
      
      ;; Update fee growth outside
      (try! (update-tick-fee-growth pool tick zero-for-one))
      
      ;; Return updated amounts (simplified)
      step-amounts)))

;; Update tick fee growth when crossing
(define-private (update-tick-fee-growth (pool principal) (tick int) (zero-for-one bool))
  ;; Simplified implementation - in production would update fee growth outside
  (ok true))

;; Update swap state after a step
(define-private (update-swap-state-after-step
  (swap-id uint)
  (step-result (tuple (amount-in uint) (amount-out uint) (fee-amount uint) (sqrt-price-next uint))))
  (let ((state (unwrap-panic (map-get? swap-states {swap-id: swap-id}))))
    
    (let ((amount-in (get amount-in step-result))
          (amount-out (get amount-out step-result))
          (sqrt-price-next (get sqrt-price-next step-result)))
      
      ;; Update state
      (map-set swap-states
        {swap-id: swap-id}
        (merge state
          {amount-specified-remaining: (if (> (get amount-specified-remaining state) 0)
                                        (- (get amount-specified-remaining state) (to-int amount-in))
                                        (+ (get amount-specified-remaining state) (to-int amount-out))),
           amount-calculated: (if (> (get amount-specified-remaining state) 0)
                               (+ (get amount-calculated state) (to-int amount-out))
                               (- (get amount-calculated state) (to-int amount-in))),
           sqrt-price: sqrt-price-next,
           tick: (sqrt-price-to-tick sqrt-price-next)}))
      
      (ok true))))

;; Update pool state after swap completion
(define-private (update-pool-after-swap
  (pool principal)
  (swap-result (tuple (amount-0 int) (amount-1 int) (sqrt-price-x96 uint) (liquidity uint) (tick int)))
  (zero-for-one bool))
  ;; Simplified implementation - in production would update pool state
  (ok true))

;; Price impact calculation for concentrated liquidity
(define-public (calculate-price-impact
  (pool principal)
  (amount-in uint)
  (zero-for-one bool))
  (let ((pool-state (unwrap-panic (contract-call? pool get-pool-state))))
    
    (let ((current-sqrt-price (get current-sqrt-price pool-state))
          (liquidity (get liquidity pool-state)))
      
      (if (is-eq liquidity u0)
        (ok u0) ;; No liquidity, no price impact
        
        ;; Calculate new price after swap
        (let ((new-sqrt-price (calculate-new-sqrt-price
                              current-sqrt-price
                              liquidity
                              amount-in
                              zero-for-one)))
          
          ;; Calculate price impact as percentage
          (let ((price-change (if (> new-sqrt-price current-sqrt-price)
                               (- new-sqrt-price current-sqrt-price)
                               (- current-sqrt-price new-sqrt-price)))
                (price-impact-bps (/ (* price-change u10000) current-sqrt-price)))
            
            (ok price-impact-bps)))))))

;; Calculate new sqrt price after swap
(define-private (calculate-new-sqrt-price
  (sqrt-price uint)
  (liquidity uint)
  (amount-in uint)
  (zero-for-one bool))
  (if zero-for-one
    ;; Selling token0, price decreases
    (let ((numerator (* sqrt-price liquidity))
          (denominator (+ (* liquidity PRECISION) (* amount-in sqrt-price))))
      (/ (* numerator PRECISION) denominator))
    
    ;; Selling token1, price increases
    (+ sqrt-price (/ (* amount-in PRECISION) liquidity))))

;; Slippage protection for swaps
(define-public (check-slippage
  (expected-amount uint)
  (actual-amount uint)
  (max-slippage-bps uint))
  (let ((slippage (if (> expected-amount actual-amount)
                   (/ (* (- expected-amount actual-amount) u10000) expected-amount)
                   u0)))
    
    (if (<= slippage max-slippage-bps)
      (ok {slippage: slippage, within-tolerance: true})
      (err ERR_SLIPPAGE_EXCEEDED))))

;; Fee calculation and distribution
(define-public (calculate-swap-fees
  (amount-in uint)
  (fee-tier uint)
  (protocol-fee-bps uint))
  (let ((total-fee (/ (* amount-in fee-tier) u1000000))
        (protocol-fee (/ (* total-fee protocol-fee-bps) u10000))
        (lp-fee (- total-fee protocol-fee)))
    
    (ok {total-fee: total-fee,
         protocol-fee: protocol-fee,
         lp-fee: lp-fee})))

;; Liquidity utilization across tick ranges
(define-public (calculate-liquidity-utilization
  (pool principal)
  (tick-lower int)
  (tick-upper int))
  (let ((pool-state (unwrap-panic (contract-call? pool get-pool-state))))
    
    (let ((current-tick (get current-tick pool-state))
          (total-liquidity (get liquidity pool-state)))
      
      (if (and (>= current-tick tick-lower) (< current-tick tick-upper))
        ;; Position is active
        (ok {active: true,
             utilization: u10000, ;; 100% in basis points
             in-range: true})
        ;; Position is inactive
        (ok {active: false,
             utilization: u0,
             in-range: false})))))

;; Helper functions

;; Convert tick to sqrt price (simplified)
(define-private (tick-to-sqrt-price (tick int))
  ;; Simplified implementation - in production would use precise calculation
  (if (>= tick 0)
    (+ Q96 (to-uint (* tick 1000)))
    (- Q96 (to-uint (* (- tick) 1000)))))

;; Convert sqrt price to tick (simplified)
(define-private (sqrt-price-to-tick (sqrt-price uint))
  ;; Simplified implementation - in production would use precise calculation
  (if (>= sqrt-price Q96)
    (to-int (/ (- sqrt-price Q96) u1000))
    (- 0 (to-int (/ (- Q96 sqrt-price) u1000)))))

;; Generate unique swap ID
(define-private (generate-swap-id)
  ;; Simplified implementation - in production would use more sophisticated ID generation
  (+ block-height (to-uint (len (unwrap-panic (get-block-info? id-header-hash block-height))))))

;; Read-only functions

;; Get swap state
(define-read-only (get-swap-state (swap-id uint))
  (map-get? swap-states {swap-id: swap-id}))

;; Get swap step
(define-read-only (get-swap-step (swap-id uint) (step uint))
  (map-get? swap-steps {swap-id: swap-id, step: step}))

;; Estimate swap output
(define-read-only (estimate-swap-output
  (pool principal)
  (amount-in uint)
  (zero-for-one bool)
  (fee-tier uint))
  (let ((pool-state (unwrap-panic (contract-call? pool get-pool-state))))
    
    (let ((sqrt-price (get current-sqrt-price pool-state))
          (liquidity (get liquidity pool-state)))
      
      (if (is-eq liquidity u0)
        u0
        (let ((fee-amount (calculate-fee-amount amount-in fee-tier))
              (amount-in-after-fee (- amount-in fee-amount)))
          
          ;; Simplified calculation - in production would handle tick crossing
          (if zero-for-one
            (/ (* amount-in-after-fee liquidity) (* sqrt-price PRECISION))
            (/ (* amount-in-after-fee sqrt-price) (* liquidity PRECISION))))))))

;; Check if swap is profitable considering gas costs
(define-read-only (is-swap-profitable
  (amount-in uint)
  (estimated-amount-out uint)
  (gas-cost uint)
  (min-profit-bps uint))
  (let ((gross-profit (if (> estimated-amount-out amount-in)
                       (- estimated-amount-out amount-in)
                       u0))
        (net-profit (if (> gross-profit gas-cost)
                     (- gross-profit gas-cost)
                     u0))
        (profit-bps (if (> amount-in u0)
                     (/ (* net-profit u10000) amount-in)
                     u0)))
    
    (>= profit-bps min-profit-bps)))