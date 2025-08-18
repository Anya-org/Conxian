;; BETA: Experimental DEX component - not audited; avoid production reliance.
;; Weighted Pool Implementation (Balancer-style AMM)
;; Supports arbitrary weight distributions for multi-asset pools

(impl-trait .pool-trait.pool-trait)
(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant ERR_INSUFFICIENT_LIQUIDITY u301)
(define-constant ERR_INVALID_AMOUNTS u302)
(define-constant ERR_SLIPPAGE_EXCEEDED u303)
(define-constant ERR_INVALID_WEIGHTS u304)
(define-constant ERR_POOL_PAUSED u305)
(define-constant ERR_UNAUTHORIZED u306)
(define-constant ERR_WEIGHT_SUM u307)
(define-constant ERR_EXPIRED u308)
(define-constant ERR_DEADLINE u309)

;; Mathematical constants
(define-constant ONE_8 u100000000) ;; 1.0 in 8 decimal fixed point
(define-constant MIN_WEIGHT u2000000) ;; 2% minimum weight (2% * ONE_8)
(define-constant MAX_WEIGHT u98000000) ;; 98% maximum weight (98% * ONE_8)
(define-constant MIN_FEE u100) ;; 0.01% minimum fee
(define-constant MAX_FEE u1000) ;; 10% maximum fee

;; Pool configuration
(define-data-var pool-token-x principal .mock-ft)
(define-data-var pool-token-y principal .mock-ft)
(define-data-var weight-x uint u50000000) ;; 50% weight (0.5 * ONE_8)
(define-data-var weight-y uint u50000000) ;; 50% weight (0.5 * ONE_8)
(define-data-var reserve-x uint u0)
(define-data-var reserve-y uint u0)
(define-data-var total-supply uint u0)

;; Pool parameters
(define-data-var swap-fee-bps uint u300) ;; 3% swap fee (300 BPS)
(define-data-var admin principal tx-sender)
(define-data-var pool-paused bool false)
(define-data-var pool-created-at uint u0)

;; Pool metrics
(define-data-var total-volume uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var swap-count uint u0)
;; Track last swap fee for external analytics (restores visibility present in disabled variant without breaking trait signature)
(define-data-var last-swap-fee uint u0)

;; Liquidity provider tracking
(define-map lp-balances
  { provider: principal }
  { 
    shares: uint,
    last-deposit: uint,
    total-fees-earned: uint
  }
)

;; Weight change proposals (for governance)
(define-map weight-proposals
  { proposal-id: uint }
  {
    new-weight-x: uint,
    new-weight-y: uint,
    proposed-at: uint,
    execution-block: uint,
    executed: bool
  }
)

(define-data-var proposal-count uint u0)

;; Price tracking for oracles
(define-map price-history
  { timestamp: uint }
  {
    price-x-per-y: uint,
    price-y-per-x: uint,
    block-height: uint
  }
)

;; Authorization
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Fixed-point mathematical operations
(define-private (mul-down (a uint) (b uint))
  (/ (* a b) ONE_8))

(define-private (div-down (a uint) (b uint))
  (/ (* a ONE_8) b))

;; Power function approximation for weighted pool math
(define-private (pow-fixed (base uint) (exponent uint))
  ;; Simplified power approximation
  ;; In production, would use Taylor series or more precise method
  (if (is-eq exponent ONE_8)
    base
    (if (is-eq exponent u0)
      ONE_8
      ;; Simple approximation: base^exp ~= 1 + exp * (base - 1)
      (+ ONE_8 (mul-down exponent (- base ONE_8))))))

;; Weighted pool invariant: (B_x / W_x)^W_x * (B_y / W_y)^W_y = k
(define-private (calculate-invariant (balance-x uint) (balance-y uint) (token-weight-x uint) (token-weight-y uint))
  ;; k = (B_x / W_x)^W_x * (B_y / W_y)^W_y
  (let ((normalized-x (div-down balance-x token-weight-x))
        (normalized-y (div-down balance-y token-weight-y)))
    (mul-down 
      (pow-fixed normalized-x token-weight-x)
      (pow-fixed normalized-y token-weight-y))))

;; Calculate output amount for weighted swap
;; amount_out = balance_out * (1 - (balance_in / (balance_in + amount_in))^(weight_in / weight_out))
(define-private (calculate-weighted-swap-out
  (amount-in uint)
  (balance-in uint)
  (balance-out uint)
  (weight-in uint)
  (weight-out uint))
  
  (let ((base (div-down balance-in (+ balance-in amount-in)))
        (exponent (div-down weight-in weight-out)))
    
    (mul-down balance-out 
      (- ONE_8 (pow-fixed base exponent)))))

;; Utility functions
(define-private (integer-sqrt (n uint))
  ;; Simplified square root to avoid circular dependency
  (if (< n u4)
    (if (is-eq n u0) u0 u1)
    (let ((x (/ n u2)))
      ;; Single iteration Newton's method
      (/ (+ x (/ n x)) u2))))

;; Pool functions implementation
(define-public (add-liquidity (amount-x uint) (amount-y uint) (min-shares uint) (deadline uint))
  (begin
    (asserts! (not (var-get pool-paused)) (err ERR_POOL_PAUSED))
    (asserts! (and (> amount-x u0) (> amount-y u0)) (err ERR_INVALID_AMOUNTS))
    (asserts! (>= deadline block-height) (err ERR_EXPIRED))
    
    (let ((current-supply (var-get total-supply))
          (current-reserve-x (var-get reserve-x))
          (current-reserve-y (var-get reserve-y)))
      
      (let ((shares (if (is-eq current-supply u0)
                      ;; Initial liquidity: simplified calculation
                      (/ (+ amount-x amount-y) u2) ;; Simple average
                      ;; Calculate proportional shares for weighted pool
                      (calculate-weighted-lp-shares amount-x amount-y current-reserve-x current-reserve-y current-supply))))
        
        (asserts! (>= shares min-shares) (err ERR_SLIPPAGE_EXCEEDED))
        
        ;; Update pool state
        (var-set reserve-x (+ current-reserve-x amount-x))
        (var-set reserve-y (+ current-reserve-y amount-y))
        (var-set total-supply (+ current-supply shares))
        
        ;; Update LP position
        (let ((current-lp (map-get? lp-balances { provider: tx-sender })))
          (match current-lp
            lp-data
              (map-set lp-balances 
                { provider: tx-sender }
                (merge lp-data { shares: (+ (get shares lp-data) shares), last-deposit: block-height }))
            
            (map-set lp-balances
              { provider: tx-sender }
              { shares: shares, last-deposit: block-height, total-fees-earned: u0 })))
        
        ;; Update price history
        (unwrap! (update-price-history) (err u500))
        
        (print {
          event: "weighted-liquidity-added",
          provider: tx-sender,
          amount-x: amount-x,
          amount-y: amount-y,
          shares: shares,
          weight-x: (var-get weight-x),
          weight-y: (var-get weight-y)
        })
        (ok { shares: shares })))))

(define-private (calculate-weighted-lp-shares 
  (amount-x uint) (amount-y uint) 
  (pool-reserve-x uint) (pool-reserve-y uint) 
  (current-supply uint))
  ;; For weighted pools, LP shares are proportional to value added
  (let ((pool-weight-x (var-get weight-x))
        (pool-weight-y (var-get weight-y)))
    
    ;; Calculate the proportional increase in pool value
    (let ((value-ratio-x (if (> pool-reserve-x u0) (div-down amount-x pool-reserve-x) u0))
          (value-ratio-y (if (> pool-reserve-y u0) (div-down amount-y pool-reserve-y) u0)))
      
      ;; Weight the contributions by pool weights
      (let ((weighted-contribution (+ (mul-down value-ratio-x pool-weight-x)
                                      (mul-down value-ratio-y pool-weight-y))))
        (mul-down current-supply weighted-contribution)))))

(define-public (remove-liquidity (shares uint) (min-x uint) (min-y uint) (deadline uint))
  (begin
    (asserts! (not (var-get pool-paused)) (err ERR_POOL_PAUSED))
    (asserts! (> shares u0) (err ERR_INVALID_AMOUNTS))
    (asserts! (<= block-height deadline) (err ERR_DEADLINE))
    
    (let ((lp-data (unwrap! (map-get? lp-balances { provider: tx-sender }) (err ERR_INSUFFICIENT_LIQUIDITY)))
          (user-shares (get shares lp-data))
          (total-shares (var-get total-supply)))
      
      (asserts! (>= user-shares shares) (err ERR_INSUFFICIENT_LIQUIDITY))
      
      ;; Calculate proportional withdrawal amounts
      (let ((amount-x (/ (* shares (var-get reserve-x)) total-shares))
            (amount-y (/ (* shares (var-get reserve-y)) total-shares)))
        
        (asserts! (and (>= amount-x min-x) (>= amount-y min-y)) (err ERR_SLIPPAGE_EXCEEDED))
        
        ;; Update pool state
        (var-set reserve-x (- (var-get reserve-x) amount-x))
        (var-set reserve-y (- (var-get reserve-y) amount-y))
        (var-set total-supply (- total-shares shares))
        
        ;; Update LP position
        (map-set lp-balances 
          { provider: tx-sender }
          (merge lp-data { shares: (- user-shares shares) }))
        
        (print {
          event: "weighted-liquidity-removed",
          provider: tx-sender,
          shares: shares,
          amount-x: amount-x,
          amount-y: amount-y
        })
  ;; Trait requires (response (tuple (dx uint) (dy uint)) uint)
  (ok { dx: amount-x, dy: amount-y })))))

(define-public (swap-exact-in (amount-in uint) (min-amount-out uint) (x-to-y bool) (deadline uint))
  (begin
    (asserts! (>= deadline block-height) (err u300))
    (asserts! (not (var-get pool-paused)) (err ERR_POOL_PAUSED))
    (asserts! (> amount-in u0) (err ERR_INVALID_AMOUNTS))
    
    (let ((reserve-in (if x-to-y (var-get reserve-x) (var-get reserve-y)))
          (reserve-out (if x-to-y (var-get reserve-y) (var-get reserve-x)))
          (weight-in (if x-to-y (var-get weight-x) (var-get weight-y)))
          (weight-out (if x-to-y (var-get weight-y) (var-get weight-x))))
      
      (let ((amount-out-gross (calculate-weighted-swap-out amount-in reserve-in reserve-out weight-in weight-out))
            (swap-fee (/ (* amount-out-gross (var-get swap-fee-bps)) u10000)))
        
        (let ((amount-out (- amount-out-gross swap-fee)))
          (asserts! (>= amount-out min-amount-out) (err ERR_SLIPPAGE_EXCEEDED))
          
          ;; Update reserves
          (if x-to-y
            (begin
              (var-set reserve-x (+ (var-get reserve-x) amount-in))
              (var-set reserve-y (- (var-get reserve-y) amount-out)))
            (begin
              (var-set reserve-y (+ (var-get reserve-y) amount-in))
              (var-set reserve-x (- (var-get reserve-x) amount-out))))
          
          ;; Update metrics
          (var-set total-volume (+ (var-get total-volume) amount-in))
          (var-set total-fees-collected (+ (var-get total-fees-collected) swap-fee))
          (var-set swap-count (+ (var-get swap-count) u1))
          
          ;; Update price history
          (unwrap! (update-price-history) (err u500))
          
          (print {
            event: "weighted-swap",
            trader: tx-sender,
            amount-in: amount-in,
            amount-out: amount-out,
            fee: swap-fee,
            x-to-y: x-to-y,
            swap-count: (var-get swap-count)
          })
          ;; Persist last fee (gas cost minimal single var-set); provides read-only access
          (var-set last-swap-fee swap-fee)
          ;; Trait requires only (tuple (amount-out uint))
          (ok { amount-out: amount-out }))))))

;; Price oracle updates
(define-private (update-price-history)
  (let ((current-reserve-x (var-get reserve-x))
        (current-reserve-y (var-get reserve-y)))
    
    (if (and (> current-reserve-x u0) (> current-reserve-y u0))
      (let ((price-x-per-y (div-down current-reserve-y current-reserve-x))
            (price-y-per-x (div-down current-reserve-x current-reserve-y)))
        
        (map-set price-history
          { timestamp: block-height }
          {
            price-x-per-y: price-x-per-y,
            price-y-per-x: price-y-per-x,
            block-height: block-height
          })
        (ok true))
      (ok true))))

;; Weight management for governance
(define-public (propose-weight-change (new-weight-x uint) (new-weight-y uint) (execution-delay uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq (+ new-weight-x new-weight-y) ONE_8) (err ERR_WEIGHT_SUM))
    (asserts! (and (>= new-weight-x MIN_WEIGHT) (>= new-weight-y MIN_WEIGHT)) (err ERR_INVALID_WEIGHTS))
    (asserts! (and (<= new-weight-x MAX_WEIGHT) (<= new-weight-y MAX_WEIGHT)) (err ERR_INVALID_WEIGHTS))
    
    (let ((proposal-id (+ (var-get proposal-count) u1)))
      (map-set weight-proposals
        { proposal-id: proposal-id }
        {
          new-weight-x: new-weight-x,
          new-weight-y: new-weight-y,
          proposed-at: block-height,
          execution-block: (+ block-height execution-delay),
          executed: false
        })
      
      (var-set proposal-count proposal-id)
      (print {
        event: "weight-change-proposed",
        proposal-id: proposal-id,
        new-weight-x: new-weight-x,
        new-weight-y: new-weight-y,
        execution-block: (+ block-height execution-delay)
      })
      (ok proposal-id))))

(define-public (execute-weight-change (proposal-id uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    (let ((proposal (unwrap! (map-get? weight-proposals { proposal-id: proposal-id }) (err u404))))
      (asserts! (not (get executed proposal)) (err u405))
      (asserts! (>= block-height (get execution-block proposal)) (err u406))
      
      ;; Execute weight change
      (var-set weight-x (get new-weight-x proposal))
      (var-set weight-y (get new-weight-y proposal))
      
      ;; Mark as executed
      (map-set weight-proposals
        { proposal-id: proposal-id }
        (merge proposal { executed: true }))
      
      (print {
        event: "weight-change-executed",
        proposal-id: proposal-id,
        new-weight-x: (get new-weight-x proposal),
        new-weight-y: (get new-weight-y proposal)
      })
      (ok true))))

;; Read-only functions
(define-public (get-reserves)
  (ok (tuple (rx (var-get reserve-x)) (ry (var-get reserve-y)))))

(define-read-only (get-weights)
  { weight-x: (var-get weight-x), weight-y: (var-get weight-y) })

(define-read-only (get-pool-info)
  {
    token-x: (var-get pool-token-x),
    token-y: (var-get pool-token-y),
    weight-x: (var-get weight-x),
    weight-y: (var-get weight-y),
    reserve-x: (var-get reserve-x),
    reserve-y: (var-get reserve-y),
    total-supply: (var-get total-supply),
    swap-fee-bps: (var-get swap-fee-bps),
    total-volume: (var-get total-volume),
    total-fees: (var-get total-fees-collected),
    swap-count: (var-get swap-count)
  })

(define-read-only (get-lp-position (provider principal))
  (map-get? lp-balances { provider: provider }))

(define-read-only (calculate-swap-output (amount-in uint) (x-to-y bool))
  (let ((reserve-in (if x-to-y (var-get reserve-x) (var-get reserve-y)))
        (reserve-out (if x-to-y (var-get reserve-y) (var-get reserve-x)))
        (weight-in (if x-to-y (var-get weight-x) (var-get weight-y)))
        (weight-out (if x-to-y (var-get weight-y) (var-get weight-x))))
    
    (let ((amount-out-gross (calculate-weighted-swap-out amount-in reserve-in reserve-out weight-in weight-out))
          (swap-fee (/ (* amount-out-gross (var-get swap-fee-bps)) u10000)))
      (- amount-out-gross swap-fee))))

(define-read-only (get-price-history (timestamp uint))
  (map-get? price-history { timestamp: timestamp }))

(define-read-only (get-weight-proposal (proposal-id uint))
  (map-get? weight-proposals { proposal-id: proposal-id }))

(define-read-only (calculate-price-impact (amount-in uint) (x-to-y bool))
  ;; Calculate price impact for weighted pools
  (let ((reserve-in (if x-to-y (var-get reserve-x) (var-get reserve-y)))
        (weight-in (if x-to-y (var-get weight-x) (var-get weight-y))))
    
    ;; Price impact = (amount_in / reserve_in) * (1 / weight_in)
    (if (> reserve-in u0)
      (div-down (div-down amount-in reserve-in) weight-in)
      u0)))

(define-read-only (get-spot-price (x-to-y bool))
  ;; Spot price = (reserve_out / weight_out) / (reserve_in / weight_in)
  (let ((reserve-in (if x-to-y (var-get reserve-x) (var-get reserve-y)))
        (reserve-out (if x-to-y (var-get reserve-y) (var-get reserve-x)))
        (weight-in (if x-to-y (var-get weight-x) (var-get weight-y)))
        (weight-out (if x-to-y (var-get weight-y) (var-get weight-x))))
    
    (if (and (> reserve-in u0) (> weight-in u0))
      (div-down (div-down reserve-out weight-out) (div-down reserve-in weight-in))
      u0)))

;; Administrative functions
(define-public (set-swap-fee (new-fee-bps uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= new-fee-bps MIN_FEE) (<= new-fee-bps MAX_FEE)) (err u407))
    (var-set swap-fee-bps new-fee-bps)
    (ok true)))

(define-public (pause-pool (paused bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set pool-paused paused)
    (ok true)))

(define-public (initialize-pool 
  (token-x principal) 
  (token-y principal) 
  (init-weight-x uint) 
  (init-weight-y uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq (+ init-weight-x init-weight-y) ONE_8) (err ERR_WEIGHT_SUM))
    
    (var-set pool-token-x token-x)
    (var-set pool-token-y token-y)
    (var-set weight-x init-weight-x)
    (var-set weight-y init-weight-y)
    (var-set pool-created-at block-height)
    
    (print {
      event: "weighted-pool-initialized",
      token-x: token-x,
      token-y: token-y,
      weight-x: init-weight-x,
      weight-y: init-weight-y
    })
    (ok true)))

(define-read-only (get-fee-info)
  (ok (tuple (lp-fee-bps (var-get swap-fee-bps)) (protocol-fee-bps u0))))

(define-read-only (get-price)
  (let ((current-reserve-x (var-get reserve-x))
        (current-reserve-y (var-get reserve-y)))
    (if (and (> current-reserve-x u0) (> current-reserve-y u0))
      (ok (tuple 
        (price-x-y (/ (* current-reserve-y u1000000) current-reserve-x))
        (price-y-x (/ (* current-reserve-x u1000000) current-reserve-y))
      ))
      (ok (tuple (price-x-y u0) (price-y-x u0))))))

;; Read-only accessor restoring fee transparency (not part of pool-trait to avoid signature drift)
(define-read-only (get-last-swap-fee)
  (var-get last-swap-fee))
