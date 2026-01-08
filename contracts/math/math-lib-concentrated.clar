;; Concentrated Liquidity Math Library
;; Mathematical functions for concentrated liquidity pools

(define-constant TICK_SPACING u60)
(define-constant MIN_TICK (- i887272))
(define-constant MAX_TICK i887272)

;; Convert price to tick
(define-public (price-to-tick (price uint))
  (begin
    (asserts! (> price u0) (err 1001))
    (let ((tick (/ (* (log2 price) u1000000) TICK_SPACING)))
      (ok (default-to i0 (some-to-int (floor tick))))
    )
  )
)

;; Convert tick to price
(define-public (tick-to-price (tick int))
  (begin
    (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) (err 1002))
    (ok (pow u2 (* (to-uint tick) TICK_SPACING)))
  )
)

;; Calculate liquidity amount for a given price range
(define-public (get-liquidity (current-price uint) (price-lower uint) (price-upper uint) (amount uint))
  (begin
    (asserts! (and (> current-price u0) (> price-lower u0) (> price-upper u0)) (err 1003))
    (asserts! (< price-lower price-upper) (err 1004))
    
    (if (<= current-price price-lower)
        ;; Current price below range - all liquidity in base token
        (ok (/ (* amount price-lower) (- price-upper price-lower)))
        
        (if (>= current-price price-upper)
            ;; Current price above range - all liquidity in quote token
            (ok amount)
            
            ;; Current price within range - balanced liquidity
            (let ((liquidity-base (/ (* amount current-price) (- price-upper current-price)))
                  (liquidity-quote (/ (* amount price-lower) (- price-upper price-lower))))
              (ok (min liquidity-base liquidity-quote))
            )
        )
    )
  )
)

;; Calculate token amounts for given liquidity
(define-public (get-token-amounts (liquidity uint) (price-lower uint) (price-upper uint) (current-price uint))
  (begin
    (asserts! (and (> liquidity u0) (> price-lower u0) (> price-upper u0) (> current-price u0)) (err 1005))
    (asserts! (< price-lower price-upper) (err 1006))
    
    (if (<= current-price price-lower)
        ;; Below range - only base token
        (ok {
          base-amount: (/ (* liquidity (- price-upper price-lower)) price-lower),
          quote-amount: u0
        })
        
        (if (>= current-price price-upper)
            ;; Above range - only quote token
            (ok {
              base-amount: u0,
              quote-amount: liquidity
            })
            
            ;; Within range - both tokens
            (ok {
              base-amount: (/ (* liquidity (- price-upper current-price)) current-price),
              quote-amount: (* liquidity (- current-price price-lower))
            })
        )
    )
  )
)

;; Calculate fees for liquidity position
(define-public (calculate-fees (liquidity uint) (fee-growth-inside-x128 uint) (fee-growth-outside-x128 uint))
  (begin
    (asserts! (> liquidity u0) (err 1007))
    (let ((fee-amount (/ (* liquidity (- fee-growth-inside-x128 fee-growth-outside-x128)) u1000000000000000000000000000000000)))
      (ok fee-amount)
    )
  )
)

;; Update tick data
(define-public (update-tick (tick int) (liquidity-gross uint) (liquidity-net int))
  (begin
    (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) (err 1008))
    (ok {
      tick: tick,
      liquidity-gross: liquidity-gross,
      liquidity-net: liquidity-net,
      fee-growth-outside-x128: u0
    })
  )
)

;; Get next initialized tick
(define-public (get-next-tick (current-tick int) (tick-spacing int) (zero-for-one bool))
  (begin
    (asserts! (and (>= current-tick MIN_TICK) (<= current-tick MAX_TICK)) (err 1009))
    (let ((next-tick (if zero-for-one
                       (- current-tick tick-spacing)
                       (+ current-tick tick-spacing))))
      (if (or (< next-tick MIN_TICK) (> next-tick MAX_TICK))
          (err 1010)
          (ok next-tick)
    )
  )
)

;; Cross tick boundary
(define-public (cross-tick (tick int) (liquidity-net int))
  (begin
    (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) (err 1011))
    (ok {
      crossed-tick: tick,
      liquidity-delta: liquidity-net
    })
  )
)

;; Calculate sqrt price
(define-public (sqrt-price-x96 (price uint))
  (begin
    (asserts! (> price u0) (err 1012))
    (ok (* (sqrt price) u79228162514264337593543950336))
  )
)

;; Calculate price from sqrt price
(define-public (price-from-sqrt-x96 (sqrt-price-x96 uint))
  (begin
    (asserts! (> sqrt-price-x96 u0) (err 1013))
    (ok (/ (* sqrt-price-x96 sqrt-price-x96) u79228162514264337593543950336))
  )
)

;; Validate tick spacing
(define-public (validate-tick-spacing (tick-spacing int))
  (begin
    (asserts! (> tick-spacing 0) (err 1014))
    (asserts! (is-divisible-by TICK_SPACING (to-uint tick-spacing)) (err 1015))
    (ok true)
  )
)

;; Helper function to check divisibility
(define-private (is-divisible-by (value uint) (divisor uint))
  (is-eq (mod value divisor) u0)
)
