;; Tick Mathematics Contract
;; Implements precise tick-to-price and price-to-tick conversions for concentrated liquidity

;; Import mathematical libraries
(use-trait math-trait .math-trait.math-trait)
(use-trait fixed-point-trait .fixed-point-math.fixed-point-trait)

;; Constants for tick mathematics
(define-constant SQRT_1_0001 u79232123823359799118286999567) ;; sqrt(1.0001) in Q96
(define-constant LOG_SQRT_1_0001 u255738958999603826347141) ;; log(sqrt(1.0001)) in Q128
(define-constant TICK_SPACINGS (list u10 u60 u200)) ;; tick spacings for different fee tiers (0.01%, 0.3%, 1%)
(define-constant TICK_BOUNDS (list MIN_TICK -887272 MAX_TICK 887272)) ;; min and max tick values
(define-constant PRICE_BOUNDS (list u4295128739 MAX_SQRT_PRICE)) ;; min and max sqrt price values

;; Mathematical constants for tick calculations
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision

;; Error constants
(define-constant ERR_TICK_OUT_OF_BOUNDS u3000)
(define-constant ERR_PRICE_OUT_OF_BOUNDS u3001)
(define-constant ERR_INVALID_TICK_SPACING u3002)
(define-constant ERR_MATH_OVERFLOW u3003)

;; Tick-to-price conversion using geometric progression
(define-public (tick-to-sqrt-price (tick int))
  (begin
    (asserts! (is-valid-tick tick) (err ERR_TICK_OUT_OF_BOUNDS))
    (if (is-eq tick 0)
      (ok Q96)
      (if (> tick 0)
        (tick-to-sqrt-price-positive (to-uint tick))
        (tick-to-sqrt-price-negative (to-uint (- tick)))))))

;; Handle positive ticks
(define-private (tick-to-sqrt-price-positive (abs-tick uint))
  (ok (pow SQRT_1_0001 abs-tick)))

;; Handle negative ticks
(define-private (tick-to-sqrt-price-negative (abs-tick uint))
  (let ((positive-result (unwrap-panic (tick-to-sqrt-price-positive abs-tick))))
    (ok (/ (* Q96 Q96) positive-result))))

;; Price-to-tick conversion using logarithms
(define-public (sqrt-price-to-tick (sqrt-price uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) (err ERR_PRICE_OUT_OF_BOUNDS))
    (if (is-eq sqrt-price Q96)
      (ok 0)
      (if (> sqrt-price Q96)
        (sqrt-price-to-tick-positive sqrt-price)
        (sqrt-price-to-tick-negative sqrt-price)))))

;; Handle sqrt prices > Q96 (positive ticks)
(define-private (sqrt-price-to-tick-positive (sqrt-price uint))
  (let ((ratio (/ sqrt-price Q96)))
    (+ (* (calculate-log2 ratio) PRECISION)
       (/ (* LOG_SQRT_1_0001 PRECISION) Q96))))

;; Handle sqrt prices < Q96 (negative ticks)  
(define-private (sqrt-price-to-tick-negative (sqrt-price uint))
  (- 0 (sqrt-price-to-tick-positive (/ Q96 sqrt-price))))

;; Calculate liquidity for given amounts and price range
(define-public (calculate-liquidity-for-amounts
  (sqrt-price uint)
  (sqrt-price-a uint) 
  (sqrt-price-b uint)
  (amount-0 uint)
  (amount-1 uint))
  (begin
    (let ((sqrt-price-lower (min sqrt-price-a sqrt-price-b))
          (sqrt-price-upper (max sqrt-price-a sqrt-price-b)))
      
      (if (< sqrt-price sqrt-price-lower)
        (ok (calculate-liquidity-0 sqrt-price-lower sqrt-price-upper amount-0))
        (if (>= sqrt-price sqrt-price-upper)
          (ok (calculate-liquidity-1 sqrt-price-lower sqrt-price-upper amount-1))
          (let ((liquidity-0 (calculate-liquidity-0 sqrt-price sqrt-price-upper amount-0))
                (liquidity-1 (calculate-liquidity-1 sqrt-price-lower sqrt-price amount-1)))
            (ok (min liquidity-0 liquidity-1))))))))

;; Calculate liquidity from token0 amount
(define-private (calculate-liquidity-0 (sqrt-price-a uint) (sqrt-price-b uint) (amount-0 uint))
  (/ (* amount-0 (- sqrt-price-b sqrt-price-a))
     (* PRECISION (pow Q96 2))))

;; Calculate liquidity from token1 amount  
(define-private (calculate-liquidity-1 (sqrt-price-a uint) (sqrt-price-b uint) (amount-1 uint))
  (/ amount-1 (- sqrt-price-b sqrt-price-a)))

;; Calculate token amounts for given liquidity and price range
(define-public (calculate-amounts-for-liquidity
  (sqrt-price uint)
  (sqrt-price-a uint)
  (sqrt-price-b uint) 
  (liquidity uint))
  (begin
    (let ((sqrt-price-lower (min sqrt-price-a sqrt-price-b))
          (sqrt-price-upper (max sqrt-price-a sqrt-price-b)))
      
      (if (< sqrt-price sqrt-price-lower)
        (ok {amount-0: (calculate-amount-0 sqrt-price-lower sqrt-price-upper liquidity),
             amount-1: u0})
        (if (>= sqrt-price sqrt-price-upper)
          (ok {amount-0: u0,
               amount-1: (calculate-amount-1 sqrt-price-lower sqrt-price-upper liquidity)})
          (ok {amount-0: (calculate-amount-0 sqrt-price sqrt-price-upper liquidity),
               amount-1: (calculate-amount-1 sqrt-price-lower sqrt-price liquidity)}))))))

;; Calculate token0 amount for given liquidity
(define-private (calculate-amount-0 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (/ (* liquidity (- sqrt-price-b sqrt-price-a))
     (* (pow Q96 2) PRECISION)))

;; Calculate token1 amount for given liquidity
(define-private (calculate-amount-1 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (/ liquidity (- sqrt-price-b sqrt-price-a)))

(impl-trait .math-trait.math-trait)

(define-public (calculate-price-impact
  (amount-in uint)
  (liquidity uint)
  (sqrt-price uint)
  (zero-for-one bool)
)
  (if (is-eq liquidity u0)
    (ok u0)
    (let (
      (price-impact-numerator (if zero-for-one
        (* amount-in (sqrt-price))
        (* amount-in (sqrt-price))
      ))
      (price-impact-denominator liquidity)
    )
    (ok (/ price-impact-numerator price-impact-denominator))
  )
)