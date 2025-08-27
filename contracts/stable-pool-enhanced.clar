;; Enhanced Stable Pool - Curve-style Low Slippage Trading
;; Optimized for stable assets (stablecoins, wrapped assets) with minimal price impact

(use-trait ft-trait .sip-010-trait.sip-010-trait)
(impl-trait .pool-trait.pool-trait)

;; Import enhanced math library
(use-trait math-lib .math-lib-enhanced)

;; Pool configuration
(define-constant PRECISION u1000000) ;; 6 decimal precision
(define-constant MIN_AMPLIFICATION u1)
(define-constant MAX_AMPLIFICATION u10000)
(define-constant INITIAL_A u100) ;; Default amplification coefficient
(define-constant FEE_DENOMINATOR u10000)
(define-constant MAX_FEE u1000) ;; 10% max fee

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u2001))
(define-constant ERR_INVALID_AMPLIFICATION (err u2002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u2003))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u2004))
(define-constant ERR_INVALID_AMOUNT (err u2005))
(define-constant ERR_POOL_IMBALANCED (err u2006))

;; Pool state
(define-data-var pool-token-x principal .mock-ft)
(define-data-var pool-token-y principal .mock-ft)
(define-data-var reserve-x uint u0)
(define-data-var reserve-y uint u0)
(define-data-var amplification-coefficient uint INITIAL_A)
(define-data-var fee-rate uint u30) ;; 0.3% default fee
(define-data-var admin-fee-rate uint u500) ;; 5% of fees to admin
(define-data-var total-supply uint u0)
(define-data-var paused bool false)

;; LP token balances
(define-map lp-balances principal uint)

;; Admin controls
(define-data-var contract-owner principal tx-sender)

;; Pool initialization
(define-public (initialize-pool 
  (token-x-trait <ft-trait>) 
  (token-y-trait <ft-trait>)
  (initial-x uint)
  (initial-y uint)
  (amp-coefficient uint))
  (let ((sender tx-sender))
    (asserts! (is-eq sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= amp-coefficient MIN_AMPLIFICATION) 
                   (<= amp-coefficient MAX_AMPLIFICATION)) ERR_INVALID_AMPLIFICATION)
    (asserts! (and (> initial-x u0) (> initial-y u0)) ERR_INVALID_AMOUNT)
    
    ;; Set pool parameters
    (var-set pool-token-x (contract-of token-x-trait))
    (var-set pool-token-y (contract-of token-y-trait))
    (var-set amplification-coefficient amp-coefficient)
    (var-set reserve-x initial-x)
    (var-set reserve-y initial-y)
    
    ;; Calculate initial LP tokens (geometric mean)
    (let ((initial-lp-supply (unwrap! (contract-call? .math-lib-enhanced calculate-sqrt (* initial-x initial-y)) ERR_INVALID_AMOUNT)))
      (var-set total-supply initial-lp-supply)
      (map-set lp-balances sender initial-lp-supply)
      
      ;; Transfer initial liquidity
      (try! (contract-call? token-x-trait transfer initial-x sender (as-contract tx-sender) none))
      (try! (contract-call? token-y-trait transfer initial-y sender (as-contract tx-sender) none))
      
      (print {
        event: "pool-initialized",
        token-x: (contract-of token-x-trait),
        token-y: (contract-of token-y-trait),
        initial-x: initial-x,
        initial-y: initial-y,
        amplification: amp-coefficient,
        lp-tokens: initial-lp-supply
      })
      
      (ok initial-lp-supply))))

;; StableSwap invariant calculation
;; D^(n+1) / (n^n * prod(x_i)) + A * n^n * sum(x_i) = A * D * n^n + D
(define-private (calculate-d (x uint) (y uint) (amp uint))
  (let ((sum (+ x y))
        (product (* x y))
        (n u2)
        (ann (* amp (* n n))))
    (if (is-eq sum u0)
      u0
      (calculate-d-iterate sum product ann u0 u0))))

(define-private (calculate-d-iterate (sum uint) (product uint) (ann uint) (d-prev uint) (iterations uint))
  (if (>= iterations u255)
    d-prev
    (let ((d-p (* (/ (* d-prev d-prev) (* u4 product)) d-prev))
          (d-new (/ (+ (* ann sum) (* u2 d-p)) (+ (* (- ann u1) d-prev) (* u3 d-p)))))
      (if (<= (abs-diff d-new d-prev) u1)
        d-new
        (calculate-d-iterate sum product ann d-new (+ iterations u1))))))

;; Calculate output amount for stable swap
(define-private (get-y (x-new uint) (x-old uint) (y-old uint) (amp uint))
  (let ((d (calculate-d x-old y-old amp))
        (ann (* amp u4))
        (c (/ (* d d) (* u4 x-new)))
        (c (/ (* c d) (* ann u2)))
        (b (+ x-new (/ d ann))))
    (get-y-iterate c b d u0 u0)))

(define-private (get-y-iterate (c uint) (b uint) (d uint) (y-prev uint) (iterations uint))
  (if (>= iterations u255)
    y-prev
    (let ((y-new (/ (+ (* y-prev y-prev) c) (+ (* u2 y-prev) b (- d)))))
      (if (<= (abs-diff y-new y-prev) u1)
        y-new
        (get-y-iterate c b d y-new (+ iterations u1))))))

;; Swap function with stable curve mathematics
(define-public (swap-x-for-y 
  (token-x-trait <ft-trait>) 
  (token-y-trait <ft-trait>)
  (dx uint) 
  (min-dy uint))
  (let ((sender tx-sender)
        (current-x (var-get reserve-x))
        (current-y (var-get reserve-y))
        (amp (var-get amplification-coefficient))
        (fee (var-get fee-rate)))
    
    (asserts! (not (var-get paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> dx u0) ERR_INVALID_AMOUNT)
    
    ;; Calculate output amount using StableSwap curve
    (let ((new-x (+ current-x dx))
          (new-y (get-y new-x current-x current-y amp))
          (dy-before-fee (- current-y new-y))
          (fee-amount (/ (* dy-before-fee fee) FEE_DENOMINATOR))
          (dy (- dy-before-fee fee-amount)))
      
      (asserts! (>= dy min-dy) ERR_SLIPPAGE_EXCEEDED)
      (asserts! (> dy u0) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Execute swap
      (try! (contract-call? token-x-trait transfer dx sender (as-contract tx-sender) none))
      (try! (as-contract (contract-call? token-y-trait transfer dy tx-sender sender none)))
      
      ;; Update reserves
      (var-set reserve-x new-x)
      (var-set reserve-y (- current-y dy-before-fee))
      
      (print {
        event: "stable-swap",
        trader: sender,
        token-in: (contract-of token-x-trait),
        token-out: (contract-of token-y-trait),
        amount-in: dx,
        amount-out: dy,
        fee: fee-amount,
        price-impact: (contract-call? .math-lib-enhanced calculate-slippage 
                        (/ (* current-y PRECISION) current-x)
                        (/ (* (var-get reserve-y) PRECISION) (var-get reserve-x)))
      })
      
      (ok dy))))

;; Add liquidity with balanced deposits
(define-public (add-liquidity 
  (token-x-trait <ft-trait>) 
  (token-y-trait <ft-trait>)
  (dx uint) 
  (dy uint) 
  (min-lp-tokens uint))
  (let ((sender tx-sender)
        (current-x (var-get reserve-x))
        (current-y (var-get reserve-y))
        (current-supply (var-get total-supply)))
    
    (asserts! (not (var-get paused)) ERR_NOT_AUTHORIZED)
    (asserts! (and (> dx u0) (> dy u0)) ERR_INVALID_AMOUNT)
    
    (let ((lp-tokens (if (is-eq current-supply u0)
                       ;; Initial liquidity
                       (unwrap! (contract-call? .math-lib-enhanced calculate-sqrt (* dx dy)) ERR_INVALID_AMOUNT)
                       ;; Proportional liquidity
                       (min (/ (* dx current-supply) current-x)
                            (/ (* dy current-supply) current-y)))))
      
      (asserts! (>= lp-tokens min-lp-tokens) ERR_SLIPPAGE_EXCEEDED)
      
      ;; Transfer tokens
      (try! (contract-call? token-x-trait transfer dx sender (as-contract tx-sender) none))
      (try! (contract-call? token-y-trait transfer dy sender (as-contract tx-sender) none))
      
      ;; Update state
      (var-set reserve-x (+ current-x dx))
      (var-set reserve-y (+ current-y dy))
      (var-set total-supply (+ current-supply lp-tokens))
      (map-set lp-balances sender (+ (default-to u0 (map-get? lp-balances sender)) lp-tokens))
      
      (print {
        event: "liquidity-added",
        provider: sender,
        amount-x: dx,
        amount-y: dy,
        lp-tokens: lp-tokens,
        total-supply: (var-get total-supply)
      })
      
      (ok lp-tokens))))

;; Remove liquidity proportionally
(define-public (remove-liquidity 
  (token-x-trait <ft-trait>) 
  (token-y-trait <ft-trait>)
  (lp-tokens uint) 
  (min-dx uint) 
  (min-dy uint))
  (let ((sender tx-sender)
        (current-x (var-get reserve-x))
        (current-y (var-get reserve-y))
        (current-supply (var-get total-supply))
        (user-balance (default-to u0 (map-get? lp-balances sender))))
    
    (asserts! (not (var-get paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> lp-tokens u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance lp-tokens) ERR_INSUFFICIENT_LIQUIDITY)
    
    (let ((dx (/ (* lp-tokens current-x) current-supply))
          (dy (/ (* lp-tokens current-y) current-supply)))
      
      (asserts! (and (>= dx min-dx) (>= dy min-dy)) ERR_SLIPPAGE_EXCEEDED)
      
      ;; Transfer tokens back
      (try! (as-contract (contract-call? token-x-trait transfer dx tx-sender sender none)))
      (try! (as-contract (contract-call? token-y-trait transfer dy tx-sender sender none)))
      
      ;; Update state
      (var-set reserve-x (- current-x dx))
      (var-set reserve-y (- current-y dy))
      (var-set total-supply (- current-supply lp-tokens))
      (map-set lp-balances sender (- user-balance lp-tokens))
      
      (print {
        event: "liquidity-removed",
        provider: sender,
        amount-x: dx,
        amount-y: dy,
        lp-tokens: lp-tokens,
        total-supply: (var-get total-supply)
      })
      
      (ok {dx: dx, dy: dy}))))

;; Administrative functions
(define-public (set-amplification (new-amp uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= new-amp MIN_AMPLIFICATION) (<= new-amp MAX_AMPLIFICATION)) ERR_INVALID_AMPLIFICATION)
    (var-set amplification-coefficient new-amp)
    (ok true)))

(define-public (set-fee-rate (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee MAX_FEE) ERR_INVALID_AMOUNT)
    (var-set fee-rate new-fee)
    (ok true)))

(define-public (pause-pool (pause bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set paused pause)
    (ok true)))

;; Read-only functions
(define-read-only (get-pool-info))
  {
    token-x: (var-get pool-token-x),
    token-y: (var-get pool-token-y),
    reserve-x: (var-get reserve-x),
    reserve-y: (var-get reserve-y),
    amplification: (var-get amplification-coefficient),
    fee-rate: (var-get fee-rate),
    total-supply: (var-get total-supply),
    paused: (var-get paused)
  })

(define-read-only (get-lp-balance (user principal))
  (default-to u0 (map-get? lp-balances user)))

(define-read-only (get-swap-amount (dx uint) (x-to-y bool))
  (let ((current-x (var-get reserve-x))
        (current-y (var-get reserve-y))
        (amp (var-get amplification-coefficient))
        (fee (var-get fee-rate)))
    (if x-to-y
      (let ((new-x (+ current-x dx))
            (new-y (get-y new-x current-x current-y amp))
            (dy-before-fee (- current-y new-y))
            (fee-amount (/ (* dy-before-fee fee) FEE_DENOMINATOR)))
        (- dy-before-fee fee-amount))
      (let ((new-y (+ current-y dx))
            (new-x (get-y new-y current-y current-x amp))
            (dx-before-fee (- current-x new-x))
            (fee-amount (/ (* dx-before-fee fee) FEE_DENOMINATOR)))
        (- dx-before-fee fee-amount)))))

;; Utility function for absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (> a b) (- a b) (- b a)))

;; Minimum function
(define-private (min (a uint) (b uint))
  (if (< a b) a b))