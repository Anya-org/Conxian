;; Concentrated Liquidity Pool Contract
;; Implements Uniswap V3-style concentrated liquidity with tick-based price ranges

;; Import required traits and libraries
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(use-trait math-trait .math-lib-advanced.advanced-math-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant TICK_SPACING u60) ;; Standard tick spacing
(define-constant MIN_TICK -887272) ;; Minimum tick (price ≈ 0)
(define-constant MAX_TICK 887272)  ;; Maximum tick (price ≈ ∞)
(define-constant Q96 u79228162514264337593543950336) ;; 2^96 for price calculations
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision

;; Error constants
(define-constant ERR_UNAUTHORIZED u2000)
(define-constant ERR_INVALID_TICK_RANGE u2001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u2002)
(define-constant ERR_POSITION_NOT_FOUND u2003)
(define-constant ERR_SLIPPAGE_EXCEEDED u2004)
(define-constant ERR_DEADLINE_EXCEEDED u2005)
(define-constant ERR_INVALID_AMOUNT u2006)
(define-constant ERR_TICK_NOT_INITIALIZED u2007)
(define-constant ERR_POSITION_ALREADY_EXISTS u2008)

;; Pool configuration
(define-data-var token-0 principal 'SP000000000000000000002Q6VF78)
(define-data-var token-1 principal 'SP000000000000000000002Q6VF78)
(define-data-var fee-tier uint u3000) ;; 0.3% fee in basis points
(define-data-var tick-spacing uint TICK_SPACING)
(define-data-var current-tick int 0)
(define-data-var current-sqrt-price uint u79228162514264337593543950336) ;; sqrt(1) in Q96
(define-data-var liquidity uint u0)
(define-data-var next-position-id uint u1)

;; Fee growth globals
(define-data-var fee-growth-global-0 uint u0)
(define-data-var fee-growth-global-1 uint u0)

;; Position data structure
(define-map positions
  {position-id: uint}
  {owner: principal,
   tick-lower: int,
   tick-upper: int,
   liquidity: uint,
   fee-growth-inside-0-last: uint,
   fee-growth-inside-1-last: uint,
   tokens-owed-0: uint,
   tokens-owed-1: uint,
   created-at: uint})

;; User position tracking
(define-map user-positions
  {user: principal, index: uint}
  {position-id: uint})

(define-map user-position-count
  {user: principal}
  {count: uint})

;; Tick data structure
(define-map ticks
  {tick: int}
  {liquidity-gross: uint,
   liquidity-net: int,
   fee-growth-outside-0: uint,
   fee-growth-outside-1: uint,
   initialized: bool})

;; Pool state tracking
(define-map pool-state
  {key: (string-ascii 20)}
  {value: uint})

;; Initialize pool with token pair and fee tier
(define-public (initialize-pool 
  (token-0-contract principal)
  (token-1-contract principal)
  (fee uint)
  (initial-sqrt-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set token-0 token-0-contract)
    (var-set token-1 token-1-contract)
    (var-set fee-tier fee)
    (var-set current-sqrt-price initial-sqrt-price)
    (var-set current-tick (sqrt-price-to-tick initial-sqrt-price))
    (ok true)))

;; Create a new concentrated liquidity position
(define-public (mint-position 
  (tick-lower int) 
  (tick-upper int) 
  (amount-0-desired uint) 
  (amount-1-desired uint)
  (amount-0-min uint)
  (amount-1-min uint)
  (deadline uint))
  (let ((position-id (var-get next-position-id))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate inputs
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (< tick-lower tick-upper) (err ERR_INVALID_TICK_RANGE))
    (asserts! (>= tick-lower MIN_TICK) (err ERR_INVALID_TICK_RANGE))
    (asserts! (<= tick-upper MAX_TICK) (err ERR_INVALID_TICK_RANGE))
    (asserts! (is-eq (mod tick-lower (get tick-spacing (var-get tick-spacing))) 0) (err ERR_INVALID_TICK_RANGE))
    (asserts! (is-eq (mod tick-upper (get tick-spacing (var-get tick-spacing))) 0) (err ERR_INVALID_TICK_RANGE))
    
    ;; Calculate liquidity amount from desired amounts
    (let ((liquidity-amount (calculate-liquidity-for-amounts 
                            (var-get current-sqrt-price)
                            (tick-to-sqrt-price tick-lower)
                            (tick-to-sqrt-price tick-upper)
                            amount-0-desired
                            amount-1-desired)))
      
      ;; Calculate actual amounts needed
      (let ((amounts (calculate-amounts-for-liquidity
                     (var-get current-sqrt-price)
                     (tick-to-sqrt-price tick-lower)
                     (tick-to-sqrt-price tick-upper)
                     liquidity-amount)))
        
        (let ((amount-0 (get amount-0 amounts))
              (amount-1 (get amount-1 amounts)))
          
          ;; Validate minimum amounts
          (asserts! (>= amount-0 amount-0-min) (err ERR_SLIPPAGE_EXCEEDED))
          (asserts! (>= amount-1 amount-1-min) (err ERR_SLIPPAGE_EXCEEDED))
          
          ;; Update tick data
          (try! (update-tick tick-lower liquidity-amount true))
          (try! (update-tick tick-upper liquidity-amount false))
          
          ;; Get fee growth inside the range
          (let ((fee-growth-inside (get-fee-growth-inside tick-lower tick-upper)))
            
            ;; Create position
            (map-set positions
              {position-id: position-id}
              {owner: tx-sender,
               tick-lower: tick-lower,
               tick-upper: tick-upper,
               liquidity: liquidity-amount,
               fee-growth-inside-0-last: (get fee-growth-0 fee-growth-inside),
               fee-growth-inside-1-last: (get fee-growth-1 fee-growth-inside),
               tokens-owed-0: u0,
               tokens-owed-1: u0,
               created-at: current-time})
            
            ;; Update user position tracking
            (let ((user-count (default-to u0 (get count (map-get? user-position-count {user: tx-sender})))))
              (map-set user-positions
                {user: tx-sender, index: user-count}
                {position-id: position-id})
              (map-set user-position-count
                {user: tx-sender}
                {count: (+ user-count u1)}))
            
            ;; Update global liquidity if position is in range
            (if (and (>= (var-get current-tick) tick-lower) 
                     (< (var-get current-tick) tick-upper))
              (var-set liquidity (+ (var-get liquidity) liquidity-amount))
              true)
            
            ;; Transfer tokens from user
            (try! (contract-call? (var-get token-0) transfer amount-0 tx-sender (as-contract tx-sender) none))
            (try! (contract-call? (var-get token-1) transfer amount-1 tx-sender (as-contract tx-sender) none))
            
            ;; Increment position ID
            (var-set next-position-id (+ position-id u1))
            
            (ok {position-id: position-id,
                 liquidity: liquidity-amount,
                 amount-0: amount-0,
                 amount-1: amount-1})))))))

;; Remove liquidity from a position
(define-public (burn-position 
  (position-id uint)
  (liquidity-to-remove uint)
  (amount-0-min uint)
  (amount-1-min uint)
  (deadline uint))
  (let ((position (unwrap! (map-get? positions {position-id: position-id}) (err ERR_POSITION_NOT_FOUND)))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate inputs
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (is-eq (get owner position) tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (<= liquidity-to-remove (get liquidity position)) (err ERR_INSUFFICIENT_LIQUIDITY))
    
    (let ((tick-lower (get tick-lower position))
          (tick-upper (get tick-upper position)))
      
      ;; Calculate amounts to return
      (let ((amounts (calculate-amounts-for-liquidity
                     (var-get current-sqrt-price)
                     (tick-to-sqrt-price tick-lower)
                     (tick-to-sqrt-price tick-upper)
                     liquidity-to-remove)))
        
        (let ((amount-0 (get amount-0 amounts))
              (amount-1 (get amount-1 amounts)))
          
          ;; Validate minimum amounts
          (asserts! (>= amount-0 amount-0-min) (err ERR_SLIPPAGE_EXCEEDED))
          (asserts! (>= amount-1 amount-1-min) (err ERR_SLIPPAGE_EXCEEDED))
          
          ;; Update tick data
          (try! (update-tick tick-lower liquidity-to-remove false))
          (try! (update-tick tick-upper liquidity-to-remove true))
          
          ;; Update position
          (let ((new-liquidity (- (get liquidity position) liquidity-to-remove)))
            (if (is-eq new-liquidity u0)
              ;; Remove position entirely
              (map-delete positions {position-id: position-id})
              ;; Update position with reduced liquidity
              (map-set positions
                {position-id: position-id}
                (merge position {liquidity: new-liquidity}))))
          
          ;; Update global liquidity if position is in range
          (if (and (>= (var-get current-tick) tick-lower) 
                   (< (var-get current-tick) tick-upper))
            (var-set liquidity (- (var-get liquidity) liquidity-to-remove))
            true)
          
          ;; Transfer tokens to user
          (try! (as-contract (contract-call? (var-get token-0) transfer amount-0 tx-sender tx-sender none)))
          (try! (as-contract (contract-call? (var-get token-1) transfer amount-1 tx-sender tx-sender none)))
          
          (ok {amount-0: amount-0,
               amount-1: amount-1,
               remaining-liquidity: (- (get liquidity position) liquidity-to-remove)}))))))

;; Collect accumulated fees from a position
(define-public (collect-fees (position-id uint))
  (let ((position (unwrap! (map-get? positions {position-id: position-id}) (err ERR_POSITION_NOT_FOUND))))
    
    ;; Validate ownership
    (asserts! (is-eq (get owner position) tx-sender) (err ERR_UNAUTHORIZED))
    
    (let ((tick-lower (get tick-lower position))
          (tick-upper (get tick-upper position))
          (fee-growth-inside (get-fee-growth-inside tick-lower tick-upper)))
      
      ;; Calculate fees owed
      (let ((fees-0 (calculate-fees-owed 
                    (get liquidity position)
                    (get fee-growth-0 fee-growth-inside)
                    (get fee-growth-inside-0-last position)
                    (get tokens-owed-0 position)))
            (fees-1 (calculate-fees-owed 
                    (get liquidity position)
                    (get fee-growth-1 fee-growth-inside)
                    (get fee-growth-inside-1-last position)
                    (get tokens-owed-1 position))))
        
        ;; Update position to reset owed fees
        (map-set positions
          {position-id: position-id}
          (merge position 
            {fee-growth-inside-0-last: (get fee-growth-0 fee-growth-inside),
             fee-growth-inside-1-last: (get fee-growth-1 fee-growth-inside),
             tokens-owed-0: u0,
             tokens-owed-1: u0}))
        
        ;; Transfer fees to user
        (if (> fees-0 u0)
          (try! (as-contract (contract-call? (var-get token-0) transfer fees-0 tx-sender tx-sender none)))
          true)
        (if (> fees-1 u0)
          (try! (as-contract (contract-call? (var-get token-1) transfer fees-1 tx-sender tx-sender none)))
          true)
        
        (ok {fees-0: fees-0, fees-1: fees-1})))))

;; Swap tokens through the concentrated liquidity pool
(define-public (swap
  (zero-for-one bool)
  (amount-specified int)
  (sqrt-price-limit-x96 uint)
  (deadline uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate inputs
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (not (is-eq amount-specified 0)) (err ERR_INVALID_AMOUNT))
    
    ;; Execute swap logic
    (let ((swap-result (execute-swap zero-for-one amount-specified sqrt-price-limit-x96)))
      
      (let ((amount-0 (get amount-0 swap-result))
            (amount-1 (get amount-1 swap-result)))
        
        ;; Handle token transfers
        (if zero-for-one
          (begin
            ;; User pays token-0, receives token-1
            (try! (contract-call? (var-get token-0) transfer (to-uint (- amount-0)) tx-sender (as-contract tx-sender) none))
            (try! (as-contract (contract-call? (var-get token-1) transfer (to-uint amount-1) tx-sender tx-sender none))))
          (begin
            ;; User pays token-1, receives token-0
            (try! (contract-call? (var-get token-1) transfer (to-uint (- amount-1)) tx-sender (as-contract tx-sender) none))
            (try! (as-contract (contract-call? (var-get token-0) transfer (to-uint amount-0) tx-sender tx-sender none)))))
        
        (ok swap-result)))))

;; Helper functions

;; Update tick data when liquidity is added or removed
(define-private (update-tick (tick int) (liquidity-delta uint) (upper bool))
  (let ((tick-data (default-to 
                   {liquidity-gross: u0,
                    liquidity-net: 0,
                    fee-growth-outside-0: u0,
                    fee-growth-outside-1: u0,
                    initialized: false}
                   (map-get? ticks {tick: tick}))))
    
    (let ((new-liquidity-gross (+ (get liquidity-gross tick-data) liquidity-delta))
          (liquidity-net-delta (if upper (- 0 (to-int liquidity-delta)) (to-int liquidity-delta)))
          (new-liquidity-net (+ (get liquidity-net tick-data) liquidity-net-delta)))
      
      ;; Initialize tick if not already initialized
      (let ((updated-tick-data (if (not (get initialized tick-data))
                               (merge tick-data 
                                 {fee-growth-outside-0: (var-get fee-growth-global-0),
                                  fee-growth-outside-1: (var-get fee-growth-global-1),
                                  initialized: true})
                               tick-data)))
        
        (map-set ticks
          {tick: tick}
          (merge updated-tick-data
            {liquidity-gross: new-liquidity-gross,
             liquidity-net: new-liquidity-net}))
        
        (ok true)))))

;; Calculate fee growth inside a tick range
(define-private (get-fee-growth-inside (tick-lower int) (tick-upper int))
  (let ((current-tick-val (var-get current-tick))
        (global-fee-growth-0 (var-get fee-growth-global-0))
        (global-fee-growth-1 (var-get fee-growth-global-1))
        (lower-tick-data (default-to 
                         {liquidity-gross: u0,
                          liquidity-net: 0,
                          fee-growth-outside-0: u0,
                          fee-growth-outside-1: u0,
                          initialized: false}
                         (map-get? ticks {tick: tick-lower})))
        (upper-tick-data (default-to 
                         {liquidity-gross: u0,
                          liquidity-net: 0,
                          fee-growth-outside-0: u0,
                          fee-growth-outside-1: u0,
                          initialized: false}
                         (map-get? ticks {tick: tick-upper}))))
    
    ;; Calculate fee growth below lower tick
    (let ((fee-growth-below-0 (if (>= current-tick-val tick-lower)
                               (get fee-growth-outside-0 lower-tick-data)
                               (- global-fee-growth-0 (get fee-growth-outside-0 lower-tick-data))))
          (fee-growth-below-1 (if (>= current-tick-val tick-lower)
                               (get fee-growth-outside-1 lower-tick-data)
                               (- global-fee-growth-1 (get fee-growth-outside-1 lower-tick-data)))))
      
      ;; Calculate fee growth above upper tick
      (let ((fee-growth-above-0 (if (< current-tick-val tick-upper)
                                 (get fee-growth-outside-0 upper-tick-data)
                                 (- global-fee-growth-0 (get fee-growth-outside-0 upper-tick-data))))
            (fee-growth-above-1 (if (< current-tick-val tick-upper)
                                 (get fee-growth-outside-1 upper-tick-data)
                                 (- global-fee-growth-1 (get fee-growth-outside-1 upper-tick-data)))))
        
        ;; Calculate fee growth inside
        {fee-growth-0: (- (- global-fee-growth-0 fee-growth-below-0) fee-growth-above-0),
         fee-growth-1: (- (- global-fee-growth-1 fee-growth-below-1) fee-growth-above-1)}))))

;; Calculate fees owed to a position
(define-private (calculate-fees-owed 
  (liquidity uint)
  (fee-growth-inside uint)
  (fee-growth-inside-last uint)
  (tokens-owed uint))
  (+ tokens-owed 
     (/ (* liquidity (- fee-growth-inside fee-growth-inside-last)) PRECISION)))

;; Convert tick to sqrt price
(define-private (tick-to-sqrt-price (tick int))
  ;; Simplified implementation - in production would use more precise calculation
  (if (>= tick 0)
    (+ Q96 (to-uint (* tick 1000)))
    (- Q96 (to-uint (* (- tick) 1000)))))

;; Convert sqrt price to tick
(define-private (sqrt-price-to-tick (sqrt-price uint))
  ;; Simplified implementation - in production would use more precise calculation
  (if (>= sqrt-price Q96)
    (to-int (/ (- sqrt-price Q96) u1000))
    (- 0 (to-int (/ (- Q96 sqrt-price) u1000)))))

;; Calculate liquidity for given amounts
(define-private (calculate-liquidity-for-amounts
  (sqrt-price uint)
  (sqrt-price-a uint)
  (sqrt-price-b uint)
  (amount-0 uint)
  (amount-1 uint))
  ;; Simplified calculation - in production would use more precise math
  (let ((liquidity-0 (if (> sqrt-price sqrt-price-a)
                      (/ (* amount-0 sqrt-price-a sqrt-price-b) 
                         (* PRECISION (- sqrt-price-b sqrt-price-a)))
                      u0))
        (liquidity-1 (if (< sqrt-price sqrt-price-b)
                      (/ (* amount-1 PRECISION) 
                         (- sqrt-price-b sqrt-price-a))
                      u0)))
    (if (< liquidity-0 liquidity-1) liquidity-0 liquidity-1)))

;; Calculate amounts for given liquidity
(define-private (calculate-amounts-for-liquidity
  (sqrt-price uint)
  (sqrt-price-a uint)
  (sqrt-price-b uint)
  (liquidity uint))
  ;; Simplified calculation - in production would use more precise math
  (let ((amount-0 (if (> sqrt-price sqrt-price-a)
                   (/ (* liquidity (- sqrt-price-b sqrt-price)) 
                      (* sqrt-price sqrt-price-b))
                   (/ (* liquidity (- sqrt-price-b sqrt-price-a)) 
                      (* sqrt-price-a sqrt-price-b))))
        (amount-1 (if (< sqrt-price sqrt-price-b)
                   (* liquidity (- sqrt-price sqrt-price-a))
                   (* liquidity (- sqrt-price-b sqrt-price-a)))))
    {amount-0: (/ amount-0 PRECISION), amount-1: (/ amount-1 PRECISION)}))

;; Execute swap logic (simplified)
(define-private (execute-swap (zero-for-one bool) (amount-specified int) (sqrt-price-limit uint))
  ;; Simplified swap implementation - in production would handle tick crossing, etc.
  (let ((amount-in (if (> amount-specified 0) (to-uint amount-specified) u0))
        (current-liquidity (var-get liquidity)))
    
    (if (> current-liquidity u0)
      (let ((amount-out (/ (* amount-in u997) u1000))) ;; 0.3% fee
        (if zero-for-one
          {amount-0: (- 0 amount-specified), amount-1: (to-int amount-out)}
          {amount-0: (to-int amount-out), amount-1: (- 0 amount-specified)}))
      {amount-0: 0, amount-1: 0})))

;; Read-only functions

(define-read-only (get-position (position-id uint))
  (map-get? positions {position-id: position-id}))

(define-read-only (get-user-positions (user principal))
  (let ((count (default-to u0 (get count (map-get? user-position-count {user: user})))))
    (map get-user-position-at-index (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))))

(define-private (get-user-position-at-index (index uint))
  (map-get? user-positions {user: tx-sender, index: index}))

(define-read-only (get-tick-data (tick int))
  (map-get? ticks {tick: tick}))

(define-read-only (get-pool-state)
  {token-0: (var-get token-0),
   token-1: (var-get token-1),
   fee-tier: (var-get fee-tier),
   current-tick: (var-get current-tick),
   current-sqrt-price: (var-get current-sqrt-price),
   liquidity: (var-get liquidity),
   fee-growth-global-0: (var-get fee-growth-global-0),
   fee-growth-global-1: (var-get fee-growth-global-1)})

(define-read-only (get-next-position-id)
  (var-get next-position-id))