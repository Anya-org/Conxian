;; Stable Pool Enhanced - Curve-style StableSwap Implementation
;; Implements low-slippage trading for stable assets using StableSwap invariant
;; Supports 2-8 assets with dynamic amplification parameter

;; Import required traits and libraries
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)
(use-trait math-trait .math-lib-advanced.advanced-math-trait)
(use-trait fixed-point-trait .fixed-point-math.fixed-point-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision
(define-constant A_PRECISION u100) ;; Amplification precision
(define-constant MAX_COINS u8) ;; Maximum number of coins in pool
(define-constant MIN_COINS u2) ;; Minimum number of coins in pool
(define-constant FEE_DENOMINATOR u10000000000) ;; Fee denominator (10^10)
(define-constant ADMIN_FEE u5000000000) ;; 50% of fees go to admin
(define-constant MAX_ADMIN_FEE u10000000000) ;; 100% max admin fee
(define-constant MAX_FEE u5000000000) ;; 50% max fee
(define-constant MAX_A u1000000) ;; Maximum amplification coefficient
(define-constant MAX_A_CHANGE u10) ;; Maximum A change per day
(define-constant MIN_RAMP_TIME u86400) ;; Minimum ramp time (1 day)

;; Error constants
(define-constant ERR_UNAUTHORIZED u7000)
(define-constant ERR_INVALID_COIN_INDEX u7001)
(define-constant ERR_INSUFFICIENT_BALANCE u7002)
(define-constant ERR_SLIPPAGE_EXCEEDED u7003)
(define-constant ERR_DEADLINE_EXCEEDED u7004)
(define-constant ERR_INVALID_AMOUNT u7005)
(define-constant ERR_POOL_NOT_INITIALIZED u7006)
(define-constant ERR_INVALID_AMPLIFICATION u7007)
(define-constant ERR_RAMP_IN_PROGRESS u7008)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u7009)
(define-constant ERR_INVALID_FEE u7010)

;; Pool configuration
(define-data-var pool-initialized bool false)
(define-data-var n-coins uint u0)
(define-data-var fee uint u4000000) ;; 0.04% default fee
(define-data-var admin-fee uint u5000000000) ;; 50% admin fee
(define-data-var owner principal tx-sender)

;; Amplification coefficient and ramping
(define-data-var initial-A uint u0)
(define-data-var future-A uint u0)
(define-data-var initial-A-time uint u0)
(define-data-var future-A-time uint u0)

;; Token addresses and balances
(define-map coins {index: uint} {token: principal})
(define-map balances {index: uint} {balance: uint})
(define-map admin-balances {index: uint} {balance: uint})

;; LP token data
(define-data-var total-supply uint u0)
(define-map lp-balances {user: principal} {balance: uint})

;; Pool statistics
(define-data-var total-volume uint u0)
(define-data-var total-fees uint u0)
(define-data-var last-update uint u0)

;; Price oracle data
(define-map price-cumulative {index: uint} {cumulative: uint, last-update: uint})

;; Initialize stable pool with tokens and amplification
(define-public (initialize
  (tokens (list 8 principal))
  (amplification uint)
  (pool-fee uint)
  (admin-fee-pct uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get pool-initialized)) (err ERR_POOL_NOT_INITIALIZED))
    
    (let ((token-count (len tokens)))
      ;; Validate token count
      (asserts! (and (>= token-count MIN_COINS) (<= token-count MAX_COINS)) 
                (err ERR_INVALID_COIN_INDEX))
      
      ;; Validate amplification
      (asserts! (and (> amplification u0) (<= amplification MAX_A)) 
                (err ERR_INVALID_AMPLIFICATION))
      
      ;; Validate fees
      (asserts! (<= pool-fee MAX_FEE) (err ERR_INVALID_FEE))
      (asserts! (<= admin-fee-pct MAX_ADMIN_FEE) (err ERR_INVALID_FEE))
      
      ;; Set pool parameters
      (var-set n-coins token-count)
      (var-set fee pool-fee)
      (var-set admin-fee admin-fee-pct)
      (var-set initial-A (* amplification A_PRECISION))
      (var-set future-A (* amplification A_PRECISION))
      (var-set initial-A-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (var-set future-A-time (unwrap-panic (get-block-info? time (- block-height u1))))
      
      ;; Register tokens
      (try! (register-tokens tokens u0))
      
      ;; Initialize balances to zero
      (try! (initialize-balances u0))
      
      (var-set pool-initialized true)
      (var-set last-update (unwrap-panic (get-block-info? time (- block-height u1))))
      
      (ok true))))

;; Register tokens recursively
(define-private (register-tokens (tokens (list 8 principal)) (index uint))
  (match (element-at tokens index)
    token (begin
            (map-set coins {index: index} {token: token})
            (if (< (+ index u1) (len tokens))
              (register-tokens tokens (+ index u1))
              (ok true)))
    (ok true)))

;; Initialize balances to zero
(define-private (initialize-balances (index uint))
  (if (< index (var-get n-coins))
    (begin
      (map-set balances {index: index} {balance: u0})
      (map-set admin-balances {index: index} {balance: u0})
      (initialize-balances (+ index u1)))
    (ok true)))

;; Add liquidity to the pool
(define-public (add-liquidity
  (amounts (list 8 uint))
  (min-mint-amount uint)
  (deadline uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate deadline
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (var-get pool-initialized) (err ERR_POOL_NOT_INITIALIZED))
    
    (let ((n (var-get n-coins))
          (amp (get-A))
          (old-balances (get-all-balances n))
          (total-supply-before (var-get total-supply)))
      
      ;; Calculate new balances after deposit
      (let ((new-balances (add-amounts-to-balances old-balances amounts n)))
        
        ;; Calculate D values
        (let ((d0 (if (> total-supply-before u0)
                    (get-D old-balances amp n)
                    u0))
              (d1 (get-D new-balances amp n)))
          
          ;; Calculate mint amount
          (let ((mint-amount (if (> total-supply-before u0)
                              (/ (* total-supply-before (- d1 d0)) d0)
                              d1))) ;; First deposit gets D as LP tokens
            
            ;; Validate minimum mint amount
            (asserts! (>= mint-amount min-mint-amount) (err ERR_SLIPPAGE_EXCEEDED))
            
            ;; Transfer tokens from user
            (try! (transfer-tokens-from-user amounts n))
            
            ;; Update balances
            (try! (update-balances new-balances n))
            
            ;; Mint LP tokens
            (try! (mint-lp-tokens tx-sender mint-amount))
            
            ;; Update statistics
            (var-set last-update current-time)
            
            (ok {mint-amount: mint-amount,
                 new-total-supply: (+ total-supply-before mint-amount)})))))))

;; Remove liquidity from the pool
(define-public (remove-liquidity
  (lp-amount uint)
  (min-amounts (list 8 uint))
  (deadline uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate deadline and initialization
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (var-get pool-initialized) (err ERR_POOL_NOT_INITIALIZED))
    
    (let ((user-balance (get-lp-balance tx-sender))
          (total-supply-val (var-get total-supply))
          (n (var-get n-coins)))
      
      ;; Validate user has enough LP tokens
      (asserts! (>= user-balance lp-amount) (err ERR_INSUFFICIENT_BALANCE))
      (asserts! (> total-supply-val u0) (err ERR_INSUFFICIENT_LIQUIDITY))
      
      ;; Calculate withdrawal amounts
      (let ((withdrawal-amounts (calculate-withdrawal-amounts lp-amount total-supply-val n)))
        
        ;; Validate minimum amounts
        (try! (validate-min-amounts withdrawal-amounts min-amounts n))
        
        ;; Burn LP tokens
        (try! (burn-lp-tokens tx-sender lp-amount))
        
        ;; Transfer tokens to user
        (try! (transfer-tokens-to-user withdrawal-amounts n))
        
        ;; Update balances
        (try! (subtract-amounts-from-balances withdrawal-amounts n))
        
        ;; Update statistics
        (var-set last-update current-time)
        
        (ok {withdrawal-amounts: withdrawal-amounts,
             new-total-supply: (- total-supply-val lp-amount)}))))))

;; Exchange one token for another
(define-public (exchange
  (i uint)
  (j uint)
  (dx uint)
  (min-dy uint)
  (deadline uint))
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Validate inputs
    (asserts! (< current-time deadline) (err ERR_DEADLINE_EXCEEDED))
    (asserts! (var-get pool-initialized) (err ERR_POOL_NOT_INITIALIZED))
    (asserts! (not (is-eq i j)) (err ERR_INVALID_COIN_INDEX))
    (asserts! (< i (var-get n-coins)) (err ERR_INVALID_COIN_INDEX))
    (asserts! (< j (var-get n-coins)) (err ERR_INVALID_COIN_INDEX))
    (asserts! (> dx u0) (err ERR_INVALID_AMOUNT))
    
    (let ((n (var-get n-coins))
          (amp (get-A))
          (old-balances (get-all-balances n))
          (fee-val (var-get fee)))
      
      ;; Calculate output amount
      (let ((dy (get-dy i j dx old-balances amp n fee-val)))
        
        ;; Validate minimum output
        (asserts! (>= dy min-dy) (err ERR_SLIPPAGE_EXCEEDED))
        
        ;; Calculate fees
        (let ((fee-amount (/ (* dx fee-val) FEE_DENOMINATOR))
              (admin-fee-amount (/ (* fee-amount (var-get admin-fee)) FEE_DENOMINATOR)))
          
          ;; Transfer input token from user
          (let ((token-in (unwrap-panic (get token (map-get? coins {index: i})))))
            (try! (contract-call? token-in transfer dx tx-sender (as-contract tx-sender) none)))
          
          ;; Transfer output token to user
          (let ((token-out (unwrap-panic (get token (map-get? coins {index: j})))))
            (try! (as-contract (contract-call? token-out transfer dy tx-sender tx-sender none))))
          
          ;; Update balances
          (let ((new-balance-i (+ (get-balance i) dx))
                (new-balance-j (- (get-balance j) dy)))
            (map-set balances {index: i} {balance: new-balance-i})
            (map-set balances {index: j} {balance: new-balance-j}))
          
          ;; Update admin fees
          (if (> admin-fee-amount u0)
            (let ((current-admin-balance (get-admin-balance i)))
              (map-set admin-balances {index: i} {balance: (+ current-admin-balance admin-fee-amount)}))
            true)
          
          ;; Update statistics
          (var-set total-volume (+ (var-get total-volume) dx))
          (var-set total-fees (+ (var-get total-fees) fee-amount))
          (var-set last-update current-time)
          
          (ok {dy: dy,
               fee: fee-amount,
               admin-fee: admin-fee-amount}))))))

;; Calculate output amount for exchange (view function)
(define-read-only (get-dy (i uint) (j uint) (dx uint) (balances (list 8 uint)) (amp uint) (n uint) (fee-val uint))
  (let ((x (unwrap-panic (element-at balances i)))
        (y (unwrap-panic (element-at balances j))))
    
    ;; Calculate new x balance
    (let ((new-x (+ x dx)))
      
      ;; Calculate new y using StableSwap invariant
      (let ((new-y (get-y i j new-x balances amp n)))
        
        ;; Calculate dy before fees
        (let ((dy-before-fee (- y new-y)))
          
          ;; Apply fee
          (let ((fee-amount (/ (* dy-before-fee fee-val) FEE_DENOMINATOR)))
            (- dy-before-fee fee-amount)))))))

;; Calculate y given x using StableSwap invariant
(define-private (get-y (i uint) (j uint) (x uint) (balances (list 8 uint)) (amp uint) (n uint))
  (let ((d (get-D balances amp n))
        (ann (/ (* amp n) A_PRECISION))
        (s (calculate-sum-except balances i n))
        (c (calculate-c-for-y d ann s n)))
    
    ;; Solve for y using Newton's method
    (newton-solve-y d ann c x)))

;; Calculate StableSwap invariant D
(define-private (get-D (balances (list 8 uint)) (amp uint) (n uint))
  (let ((s (calculate-sum balances n))
        (ann (/ (* amp n) A_PRECISION)))
    
    (if (is-eq s u0)
      u0
      (newton-solve-d s ann n))))

;; Newton's method to solve for D
(define-private (newton-solve-d (s uint) (ann uint) (n uint))
  (let ((d-prev u0)
        (d s))
    (newton-d-iteration d d-prev s ann n u0)))

(define-private (newton-d-iteration (d uint) (d-prev uint) (s uint) (ann uint) (n uint) (iteration uint))
  (if (or (> iteration u255) (and (> iteration u0) (<= (abs-diff d d-prev) u1)))
    d
    (let ((d-p (/ (* d d d) (* (* n n) (calculate-product-for-d d n))))
          (numerator (+ (* ann s) (* d-p n)))
          (denominator (+ (* (- ann u1) d) (* (+ n u1) d-p))))
      
      (if (is-eq denominator u0)
        d
        (let ((new-d (/ (* d numerator) denominator)))
          (newton-d-iteration new-d d s ann n (+ iteration u1)))))))

;; Newton's method to solve for y
(define-private (newton-solve-y (d uint) (ann uint) (c uint) (x uint))
  (let ((y-prev u0)
        (y d))
    (newton-y-iteration y y-prev d ann c x u0)))

(define-private (newton-y-iteration (y uint) (y-prev uint) (d uint) (ann uint) (c uint) (x uint) (iteration uint))
  (if (or (> iteration u255) (and (> iteration u0) (<= (abs-diff y y-prev) u1)))
    y
    (let ((y-numerator (+ (* y y) c))
          (y-denominator (+ (* u2 y) (- d (/ d ann)) x)))
      
      (if (is-eq y-denominator u0)
        y
        (let ((new-y (/ y-numerator y-denominator)))
          (newton-y-iteration new-y y d ann c x (+ iteration u1)))))))

;; Helper functions for calculations

;; Calculate sum of all balances
(define-private (calculate-sum (balances (list 8 uint)) (n uint))
  (calculate-sum-iter balances u0 u0 n))

(define-private (calculate-sum-iter (balances (list 8 uint)) (index uint) (sum uint) (n uint))
  (if (>= index n)
    sum
    (let ((balance (unwrap-panic (element-at balances index))))
      (calculate-sum-iter balances (+ index u1) (+ sum balance) n))))

;; Calculate sum excluding one index
(define-private (calculate-sum-except (balances (list 8 uint)) (except-index uint) (n uint))
  (calculate-sum-except-iter balances u0 u0 except-index n))

(define-private (calculate-sum-except-iter (balances (list 8 uint)) (index uint) (sum uint) (except-index uint) (n uint))
  (if (>= index n)
    sum
    (if (is-eq index except-index)
      (calculate-sum-except-iter balances (+ index u1) sum except-index n)
      (let ((balance (unwrap-panic (element-at balances index))))
        (calculate-sum-except-iter balances (+ index u1) (+ sum balance) except-index n)))))

;; Calculate product for D calculation
(define-private (calculate-product-for-d (d uint) (n uint))
  ;; Simplified - in production would calculate proper product
  (pow d n))

;; Calculate c parameter for y calculation
(define-private (calculate-c-for-y (d uint) (ann uint) (s uint) (n uint))
  (/ (* d d d) (* ann (* n n) (+ s d))))

;; Amplification coefficient management

;; Get current amplification coefficient
(define-read-only (get-A)
  (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (initial-time (var-get initial-A-time))
        (future-time (var-get future-A-time)))
    
    (if (<= current-time initial-time)
      (/ (var-get initial-A) A_PRECISION)
      (if (>= current-time future-time)
        (/ (var-get future-A) A_PRECISION)
        ;; Linear interpolation during ramp
        (let ((time-elapsed (- current-time initial-time))
              (total-time (- future-time initial-time))
              (initial-a (var-get initial-A))
              (future-a (var-get future-A)))
          
          (if (> future-a initial-a)
            ;; A is increasing
            (/ (+ initial-a (/ (* (- future-a initial-a) time-elapsed) total-time)) A_PRECISION)
            ;; A is decreasing
            (/ (- initial-a (/ (* (- initial-a future-a) time-elapsed) total-time)) A_PRECISION)))))))

;; Ramp amplification coefficient
(define-public (ramp-A (future-a uint) (future-time uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    
    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1))))
          (current-a (get-A)))
      
      ;; Validate ramp parameters
      (asserts! (>= future-time (+ current-time MIN_RAMP_TIME)) (err ERR_INVALID_AMPLIFICATION))
      (asserts! (and (> future-a u0) (<= future-a MAX_A)) (err ERR_INVALID_AMPLIFICATION))
      
      ;; Validate A change is not too large
      (let ((a-ratio (if (> future-a current-a)
                      (/ future-a current-a)
                      (/ current-a future-a))))
        (asserts! (<= a-ratio MAX_A_CHANGE) (err ERR_INVALID_AMPLIFICATION)))
      
      ;; Set ramp parameters
      (var-set initial-A (* current-a A_PRECISION))
      (var-set future-A (* future-a A_PRECISION))
      (var-set initial-A-time current-time)
      (var-set future-A-time future-time)
      
      (ok true))))

;; Stop amplification ramp
(define-public (stop-ramp-A)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    
    (let ((current-a (get-A))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
      
      (var-set initial-A (* current-a A_PRECISION))
      (var-set future-A (* current-a A_PRECISION))
      (var-set initial-A-time current-time)
      (var-set future-A-time current-time)
      
      (ok true))))

;; Utility functions

;; Get balance for coin index
(define-private (get-balance (index uint))
  (default-to u0 (get balance (map-get? balances {index: index}))))

;; Get admin balance for coin index
(define-private (get-admin-balance (index uint))
  (default-to u0 (get balance (map-get? admin-balances {index: index}))))

;; Get all balances as list
(define-private (get-all-balances (n uint))
  (get-balances-iter u0 n (list)))

(define-private (get-balances-iter (index uint) (n uint) (acc (list 8 uint)))
  (if (>= index n)
    acc
    (let ((balance (get-balance index)))
      (get-balances-iter (+ index u1) n (unwrap-panic (as-max-len? (append acc balance) u8))))))

;; Add amounts to balances
(define-private (add-amounts-to-balances (balances (list 8 uint)) (amounts (list 8 uint)) (n uint))
  (add-amounts-iter balances amounts u0 n (list)))

(define-private (add-amounts-iter (balances (list 8 uint)) (amounts (list 8 uint)) (index uint) (n uint) (acc (list 8 uint)))
  (if (>= index n)
    acc
    (let ((balance (unwrap-panic (element-at balances index)))
          (amount (unwrap-panic (element-at amounts index))))
      (add-amounts-iter balances amounts (+ index u1) n 
                       (unwrap-panic (as-max-len? (append acc (+ balance amount)) u8))))))

;; LP token management

;; Get LP token balance
(define-read-only (get-lp-balance (user principal))
  (default-to u0 (get balance (map-get? lp-balances {user: user}))))

;; Mint LP tokens
(define-private (mint-lp-tokens (user principal) (amount uint))
  (let ((current-balance (get-lp-balance user))
        (new-balance (+ current-balance amount))
        (new-total-supply (+ (var-get total-supply) amount)))
    
    (map-set lp-balances {user: user} {balance: new-balance})
    (var-set total-supply new-total-supply)
    (ok true)))

;; Burn LP tokens
(define-private (burn-lp-tokens (user principal) (amount uint))
  (let ((current-balance (get-lp-balance user))
        (new-balance (- current-balance amount))
        (new-total-supply (- (var-get total-supply) amount)))
    
    (map-set lp-balances {user: user} {balance: new-balance})
    (var-set total-supply new-total-supply)
    (ok true)))

;; Token transfer helpers

;; Transfer tokens from user to pool
(define-private (transfer-tokens-from-user (amounts (list 8 uint)) (n uint))
  (transfer-tokens-from-user-iter amounts u0 n))

(define-private (transfer-tokens-from-user-iter (amounts (list 8 uint)) (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((amount (unwrap-panic (element-at amounts index))))
      (if (> amount u0)
        (let ((token (unwrap-panic (get token (map-get? coins {index: index})))))
          (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
          (transfer-tokens-from-user-iter amounts (+ index u1) n))
        (transfer-tokens-from-user-iter amounts (+ index u1) n)))))

;; Transfer tokens from pool to user
(define-private (transfer-tokens-to-user (amounts (list 8 uint)) (n uint))
  (transfer-tokens-to-user-iter amounts u0 n))

(define-private (transfer-tokens-to-user-iter (amounts (list 8 uint)) (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((amount (unwrap-panic (element-at amounts index))))
      (if (> amount u0)
        (let ((token (unwrap-panic (get token (map-get? coins {index: index})))))
          (try! (as-contract (contract-call? token transfer amount tx-sender tx-sender none)))
          (transfer-tokens-to-user-iter amounts (+ index u1) n))
        (transfer-tokens-to-user-iter amounts (+ index u1) n)))))

;; Update balances after operations
(define-private (update-balances (new-balances (list 8 uint)) (n uint))
  (update-balances-iter new-balances u0 n))

(define-private (update-balances-iter (new-balances (list 8 uint)) (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((balance (unwrap-panic (element-at new-balances index))))
      (map-set balances {index: index} {balance: balance})
      (update-balances-iter new-balances (+ index u1) n))))

;; Subtract amounts from balances
(define-private (subtract-amounts-from-balances (amounts (list 8 uint)) (n uint))
  (subtract-amounts-iter amounts u0 n))

(define-private (subtract-amounts-iter (amounts (list 8 uint)) (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((amount (unwrap-panic (element-at amounts index)))
          (current-balance (get-balance index)))
      (map-set balances {index: index} {balance: (- current-balance amount)})
      (subtract-amounts-iter amounts (+ index u1) n))))

;; Calculate withdrawal amounts proportionally
(define-private (calculate-withdrawal-amounts (lp-amount uint) (total-supply-val uint) (n uint))
  (calculate-withdrawal-iter lp-amount total-supply-val u0 n (list)))

(define-private (calculate-withdrawal-iter (lp-amount uint) (total-supply-val uint) (index uint) (n uint) (acc (list 8 uint)))
  (if (>= index n)
    acc
    (let ((balance (get-balance index))
          (withdrawal-amount (/ (* balance lp-amount) total-supply-val)))
      (calculate-withdrawal-iter lp-amount total-supply-val (+ index u1) n
                                (unwrap-panic (as-max-len? (append acc withdrawal-amount) u8))))))

;; Validate minimum amounts
(define-private (validate-min-amounts (amounts (list 8 uint)) (min-amounts (list 8 uint)) (n uint))
  (validate-min-amounts-iter amounts min-amounts u0 n))

(define-private (validate-min-amounts-iter (amounts (list 8 uint)) (min-amounts (list 8 uint)) (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((amount (unwrap-panic (element-at amounts index)))
          (min-amount (unwrap-panic (element-at min-amounts index))))
      (asserts! (>= amount min-amount) (err ERR_SLIPPAGE_EXCEEDED))
      (validate-min-amounts-iter amounts min-amounts (+ index u1) n))))

;; Utility math functions

;; Absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (> a b) (- a b) (- b a)))

;; Power function (simplified)
(define-private (pow (base uint) (exponent uint))
  (if (is-eq exponent u0)
    u1
    (if (is-eq exponent u1)
      base
      (* base (pow base (- exponent u1))))))

;; Read-only functions

;; Get pool configuration
(define-read-only (get-pool-config)
  {initialized: (var-get pool-initialized),
   n-coins: (var-get n-coins),
   fee: (var-get fee),
   admin-fee: (var-get admin-fee),
   amplification: (get-A),
   total-supply: (var-get total-supply),
   owner: (var-get owner)})

;; Get coin address by index
(define-read-only (get-coin (index uint))
  (map-get? coins {index: index}))

;; Get all coin addresses
(define-read-only (get-coins)
  (let ((n (var-get n-coins)))
    (get-coins-iter u0 n (list))))

(define-private (get-coins-iter (index uint) (n uint) (acc (list 8 principal)))
  (if (>= index n)
    acc
    (match (map-get? coins {index: index})
      coin-data (get-coins-iter (+ index u1) n 
                               (unwrap-panic (as-max-len? (append acc (get token coin-data)) u8)))
      (get-coins-iter (+ index u1) n acc))))

;; Get pool statistics
(define-read-only (get-pool-stats)
  {total-volume: (var-get total-volume),
   total-fees: (var-get total-fees),
   last-update: (var-get last-update),
   total-supply: (var-get total-supply)})

;; Calculate exchange output (view function)
(define-read-only (calc-token-amount (amounts (list 8 uint)) (deposit bool))
  (if (not (var-get pool-initialized))
    u0
    (let ((n (var-get n-coins))
          (amp (get-A))
          (current-balances (get-all-balances n)))
      
      (if deposit
        ;; Calculate LP tokens for deposit
        (let ((new-balances (add-amounts-to-balances current-balances amounts n))
              (d0 (get-D current-balances amp n))
              (d1 (get-D new-balances amp n))
              (total-supply-val (var-get total-supply)))
          
          (if (> total-supply-val u0)
            (/ (* total-supply-val (- d1 d0)) d0)
            d1))
        
        ;; Calculate tokens for withdrawal (simplified)
        u0))))

;; Administrative functions

;; Set new fee
(define-public (set-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-fee MAX_FEE) (err ERR_INVALID_FEE))
    (var-set fee new-fee)
    (ok true)))

;; Set new admin fee
(define-public (set-admin-fee (new-admin-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-admin-fee MAX_ADMIN_FEE) (err ERR_INVALID_FEE))
    (var-set admin-fee new-admin-fee)
    (ok true)))

;; Withdraw admin fees
(define-public (withdraw-admin-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    
    (let ((n (var-get n-coins)))
      (try! (withdraw-admin-fees-iter u0 n))
      (ok true))))

(define-private (withdraw-admin-fees-iter (index uint) (n uint))
  (if (>= index n)
    (ok true)
    (let ((admin-balance (get-admin-balance index)))
      (if (> admin-balance u0)
        (let ((token (unwrap-panic (get token (map-get? coins {index: index})))))
          (try! (as-contract (contract-call? token transfer admin-balance tx-sender (var-get owner) none)))
          (map-set admin-balances {index: index} {balance: u0})
          (withdraw-admin-fees-iter (+ index u1) n))
        (withdraw-admin-fees-iter (+ index u1) n)))))

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (var-set owner new-owner)
    (ok true)))