;; Tick Mathematics Contract
;; Implements precise tick-to-price and price-to-tick conversions for concentrated liquidity

;; Import mathematical libraries
(use-trait math-trait .math-lib-advanced.advanced-math-trait)
(use-trait fixed-point-trait .fixed-point-math.fixed-point-trait)

;; Constants for tick mathematics
(define-constant MIN_TICK -887272) ;; Minimum tick (price  0)
(define-constant MAX_TICK 887272)  ;; Maximum tick (price  )
(define-constant Q96 u79228162514264337593543950336) ;; 2^96 for price calculations
(define-constant PRECISION u1000000000000000000) ;; 18 decimal precision

;; Tick spacing constants
(define-constant TICK_SPACING_10 u10)   ;; 0.01% pools
(define-constant TICK_SPACING_60 u60)   ;; 0.3% pools  
(define-constant TICK_SPACING_200 u200) ;; 1% pools

;; Mathematical constants for tick calculations
(define-constant LOG_SQRT_1_0001 u255738958999603826347141) ;; log(sqrt(1.0001)) in Q128
(define-constant SQRT_1_0001 u79232123823359799118286999567) ;; sqrt(1.0001) in Q96

;; Error constants
(define-constant ERR_TICK_OUT_OF_BOUNDS u3000)
(define-constant ERR_PRICE_OUT_OF_BOUNDS u3001)
(define-constant ERR_INVALID_TICK_SPACING u3002)
(define-constant ERR_MATH_OVERFLOW u3003)

;; Tick-to-price conversion using geometric progression
;; price = 1.0001^tick
(define-public (tick-to-sqrt-price (tick int))
  (begin
    ;; Validate tick bounds
    (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) (err ERR_TICK_OUT_OF_BOUNDS))
    
    (if (is-eq tick 0)
      (ok Q96) ;; sqrt(1) = 1 in Q96 format
      (if (> tick 0)
        (tick-to-sqrt-price-positive (to-uint tick))
        (tick-to-sqrt-price-negative (to-uint (- tick)))))))

;; Handle positive ticks
(define-private (tick-to-sqrt-price-positive (abs-tick uint))
  (let ((ratio (if (> abs-tick u0)
                 u79228162514264337593543950336 ;; 2^96
                 Q96)))
    
    ;; Apply bit-by-bit calculation for precision
    (let ((ratio-1 (if (and abs-tick u2) 
                     (/ (* ratio u340248342086729790484326174814286782778) Q96)
                     ratio)))
      (let ((ratio-2 (if (and abs-tick u4)
                       (/ (* ratio-1 u340214320654664324051920982716015181260) Q96)
                       ratio-1)))
        (let ((ratio-3 (if (and abs-tick u8)
                         (/ (* ratio-2 u340146287995602323631171512101879684304) Q96)
                         ratio-2)))
          (let ((ratio-4 (if (and abs-tick u16)
                           (/ (* ratio-3 u340010263488231146823593991679159461444) Q96)
                           ratio-3)))
            (let ((ratio-5 (if (and abs-tick u32)
                             (/ (* ratio-4 u339738377640345403697157401104375502016) Q96)
                             ratio-4)))
              (let ((ratio-6 (if (and abs-tick u64)
                               (/ (* ratio-5 u339195258003219555707034227454543997025) Q96)
                               ratio-5)))
                (let ((ratio-7 (if (and abs-tick u128)
                                 (/ (* ratio-6 u338111622100601834656805679988414885971) Q96)
                                 ratio-6)))
                  (let ((ratio-8 (if (and abs-tick u256)
                                   (/ (* ratio-7 u335954724994790223023589805789778977700) Q96)
                                   ratio-7)))
                    (let ((ratio-9 (if (and abs-tick u512)
                                     (/ (* ratio-8 u331682121138379247127172139078559817300) Q96)
                                     ratio-8)))
                      (let ((ratio-10 (if (and abs-tick u1024)
                                        (/ (* ratio-9 u323299236684853023288211250268160618739) Q96)
                                        ratio-9)))
                        (let ((ratio-11 (if (and abs-tick u2048)
                                          (/ (* ratio-10 u307163716377032989948697243942600083929) Q96)
                                          ratio-10)))
                          (let ((ratio-12 (if (and abs-tick u4096)
                                            (/ (* ratio-11 u277268403626896220162999269216087595045) Q96)
                                            ratio-11)))
                            (let ((ratio-13 (if (and abs-tick u8192)
                                              (/ (* ratio-12 u225923453940442621947126027127485391333) Q96)
                                              ratio-12)))
                              (let ((ratio-14 (if (and abs-tick u16384)
                                                (/ (* ratio-13 u149997214084966997727330242082538205943) Q96)
                                                ratio-13)))
                                (let ((ratio-15 (if (and abs-tick u32768)
                                                  (/ (* ratio-14 u66119101136024775622716233608466517926) Q96)
                                                  ratio-14)))
                                  (let ((ratio-16 (if (and abs-tick u65536)
                                                    (/ (* ratio-15 u12847376061809297530290974190478138313) Q96)
                                                    ratio-15)))
                                    (let ((ratio-17 (if (and abs-tick u131072)
                                                      (/ (* ratio-16 u485053260817066172746253684029974020) Q96)
                                                      ratio-16)))
                                      (let ((ratio-18 (if (and abs-tick u262144)
                                                        (/ (* ratio-17 u691415978906521570653435304214168) Q96)
                                                        ratio-17)))
                                        (let ((ratio-final (if (and abs-tick u524288)
                                                             (/ (* ratio-18 u1404880482679654955896180642) Q96)
                                                             ratio-18)))
                                          
                                          ;; Shift right to get sqrt price in Q96
                                          (ok (/ ratio-final u4294967296))))))))))))))))))))))

;; Handle negative ticks
(define-private (tick-to-sqrt-price-negative (abs-tick uint))
  (let ((positive-result (unwrap-panic (tick-to-sqrt-price-positive abs-tick))))
    ;; For negative ticks, take reciprocal: 1/sqrt(1.0001^|tick|)
    (ok (/ (* Q96 Q96) positive-result))))

;; Price-to-tick conversion using logarithms
;; tick = log(price) / log(1.0001)
(define-public (sqrt-price-to-tick (sqrt-price uint))
  (begin
    ;; Validate price bounds
    (asserts! (> sqrt-price u0) (err ERR_PRICE_OUT_OF_BOUNDS))
    (asserts! (<= sqrt-price u1461446703485210103287273052203988822378723970341) (err ERR_PRICE_OUT_OF_BOUNDS))
    
    (if (is-eq sqrt-price Q96)
      (ok 0) ;; sqrt(1) corresponds to tick 0
      (if (> sqrt-price Q96)
        (sqrt-price-to-tick-positive sqrt-price)
        (sqrt-price-to-tick-negative sqrt-price)))))

;; Handle sqrt prices > Q96 (positive ticks)
(define-private (sqrt-price-to-tick-positive (sqrt-price uint))
  (let ((ratio (/ sqrt-price Q96)))
    ;; Use binary search approximation for log calculation
    (let ((log-result (calculate-log2 ratio)))
      ;; Convert log2 to log(1.0001) base
      (ok (to-int (/ (* log-result PRECISION) LOG_SQRT_1_0001))))))

;; Handle sqrt prices < Q96 (negative ticks)  
(define-private (sqrt-price-to-tick-negative (sqrt-price uint))
  (let ((ratio (/ Q96 sqrt-price)))
    ;; Use binary search approximation for log calculation
    (let ((log-result (calculate-log2 ratio)))
      ;; Convert log2 to log(1.0001) base and negate
      (ok (- 0 (to-int (/ (* log-result PRECISION) LOG_SQRT_1_0001)))))))

;; Calculate log2 using binary approximation
(define-private (calculate-log2 (x uint))
  (let ((msb (most-significant-bit x)))
    (let ((normalized (if (>= msb u128)
                       (/ x (pow u2 (- msb u127)))
                       (* x (pow u2 (- u127 msb))))))
      ;; Apply polynomial approximation for fractional part
      (+ (* msb PRECISION) (calculate-log2-fractional normalized)))))

;; Calculate fractional part of log2
(define-private (calculate-log2-fractional (x uint))
  ;; Simplified polynomial approximation
  ;; In production, would use more terms for higher precision
  (let ((x-1 (- x PRECISION)))
    (- (/ (* x-1 PRECISION) x)
       (/ (* x-1 x-1) (* u2 x x)))))

;; Find most significant bit
(define-private (most-significant-bit (x uint))
  (if (>= x u340282366920938463463374607431768211456) u128
    (if (>= x u170141183460469231731687303715884105728) u127
      (if (>= x u85070591730234615865843651857942052864) u126
        (if (>= x u42535295865117307932921825928971026432) u125
          (if (>= x u21267647932558653966460912964485513216) u124
            (if (>= x u10633823966279326983230456482242756608) u123
              (if (>= x u5316911983139663491615228241121378304) u122
                (if (>= x u2658455991569831745807614120560689152) u121
                  (if (>= x u1329227995784915872903807060280344576) u120
                    (if (>= x u664613997892457936451903530140172288) u119
                      (if (>= x u332306998946228968225951765070086144) u118
                        (if (>= x u166153499473114484112975882535043072) u117
                          (if (>= x u83076749736557242056487941267521536) u116
                            (if (>= x u41538374868278621028243970633760768) u115
                              (if (>= x u20769187434139310514121985316880384) u114
                                (if (>= x u10384593717069655257060992658440192) u113
                                  (if (>= x u5192296858534827628530496329220096) u112
                                    (if (>= x u2596148429267413814265248164610048) u111
                                      (if (>= x u1298074214633706907132624082305024) u110
                                        (if (>= x u649037107316853453566312041152512) u109
                                          (if (>= x u324518553658426726783156020576256) u108
                                            u107))))))))))))))))))))))

;; Power function for integer exponents
(define-private (pow (base uint) (exponent uint))
  (if (is-eq exponent u0)
    u1
    (if (is-eq exponent u1)
      base
      (let ((half-pow (pow base (/ exponent u2))))
        (if (is-eq (mod exponent u2) u0)
          (* half-pow half-pow)
          (* base (* half-pow half-pow)))))))

;; Liquidity calculation functions

;; Calculate liquidity for given amounts and price range
(define-public (calculate-liquidity-for-amounts
  (sqrt-price uint)
  (sqrt-price-a uint) 
  (sqrt-price-b uint)
  (amount-0 uint)
  (amount-1 uint))
  (begin
    ;; Ensure sqrt-price-a < sqrt-price-b
    (let ((sqrt-price-lower (if (< sqrt-price-a sqrt-price-b) sqrt-price-a sqrt-price-b))
          (sqrt-price-upper (if (< sqrt-price-a sqrt-price-b) sqrt-price-b sqrt-price-a)))
      
      (if (< sqrt-price sqrt-price-lower)
        ;; Current price below range - only token0 needed
        (ok (calculate-liquidity-0 sqrt-price-lower sqrt-price-upper amount-0))
        (if (>= sqrt-price sqrt-price-upper)
          ;; Current price above range - only token1 needed  
          (ok (calculate-liquidity-1 sqrt-price-lower sqrt-price-upper amount-1))
          ;; Current price in range - use minimum of both calculations
          (let ((liquidity-0 (calculate-liquidity-0 sqrt-price sqrt-price-upper amount-0))
                (liquidity-1 (calculate-liquidity-1 sqrt-price-lower sqrt-price amount-1)))
            (ok (if (< liquidity-0 liquidity-1) liquidity-0 liquidity-1))))))))

;; Calculate liquidity from token0 amount
(define-private (calculate-liquidity-0 (sqrt-price-a uint) (sqrt-price-b uint) (amount-0 uint))
  (/ (* amount-0 sqrt-price-a sqrt-price-b) 
     (* PRECISION (- sqrt-price-b sqrt-price-a))))

;; Calculate liquidity from token1 amount  
(define-private (calculate-liquidity-1 (sqrt-price-a uint) (sqrt-price-b uint) (amount-1 uint))
  (/ (* amount-1 PRECISION) (- sqrt-price-b sqrt-price-a)))

;; Calculate token amounts for given liquidity and price range
(define-public (calculate-amounts-for-liquidity
  (sqrt-price uint)
  (sqrt-price-a uint)
  (sqrt-price-b uint) 
  (liquidity uint))
  (begin
    ;; Ensure sqrt-price-a < sqrt-price-b
    (let ((sqrt-price-lower (if (< sqrt-price-a sqrt-price-b) sqrt-price-a sqrt-price-b))
          (sqrt-price-upper (if (< sqrt-price-a sqrt-price-b) sqrt-price-b sqrt-price-a)))
      
      (if (< sqrt-price sqrt-price-lower)
        ;; Current price below range
        (ok {amount-0: (calculate-amount-0 sqrt-price-lower sqrt-price-upper liquidity),
             amount-1: u0})
        (if (>= sqrt-price sqrt-price-upper)
          ;; Current price above range
          (ok {amount-0: u0,
               amount-1: (calculate-amount-1 sqrt-price-lower sqrt-price-upper liquidity)})
          ;; Current price in range
          (ok {amount-0: (calculate-amount-0 sqrt-price sqrt-price-upper liquidity),
               amount-1: (calculate-amount-1 sqrt-price-lower sqrt-price liquidity)}))))))

;; Calculate token0 amount for given liquidity
(define-private (calculate-amount-0 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (/ (* liquidity (- sqrt-price-b sqrt-price-a)) 
     (* sqrt-price-a sqrt-price-b)))

;; Calculate token1 amount for given liquidity
(define-private (calculate-amount-1 (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (/ (* liquidity (- sqrt-price-b sqrt-price-a)) PRECISION))

;; Price impact calculation for concentrated liquidity
(define-public (calculate-price-impact
  (amount-in uint)
  (liquidity uint)
  (sqrt-price uint)
  (zero-for-one bool))
  (if (is-eq liquidity u0)
    (ok u0) ;; No liquidity, no price impact calculation possible
    (let ((price-impact-numerator (if zero-for-one
                                   (* amount-in PRECISION)
                                   (* amount-in sqrt-price)))
          (price-impact-denominator (if zero-for-one
                                     (* liquidity sqrt-price)
                                     (* liquidity PRECISION))))
      (ok (/ price-impact-numerator price-impact-denominator)))))

;; Fee growth tracking within tick ranges
(define-public (calculate-fee-growth-inside
  (tick-lower int)
  (tick-upper int)
  (current-tick int)
  (fee-growth-global uint)
  (fee-growth-outside-lower uint)
  (fee-growth-outside-upper uint))
  (let ((fee-growth-below (if (>= current-tick tick-lower)
                           fee-growth-outside-lower
                           (- fee-growth-global fee-growth-outside-lower)))
        (fee-growth-above (if (< current-tick tick-upper)
                           fee-growth-outside-upper
                           (- fee-growth-global fee-growth-outside-upper))))
    (ok (- (- fee-growth-global fee-growth-below) fee-growth-above))))

;; Tick spacing validation
(define-public (validate-tick-spacing (tick int) (spacing uint))
  (if (is-eq (mod (if (>= tick 0) (to-uint tick) (to-uint (- tick))) spacing) u0)
    (ok true)
    (err ERR_INVALID_TICK_SPACING)))

;; Get valid tick spacings for different fee tiers
(define-read-only (get-tick-spacing-for-fee (fee uint))
  (if (is-eq fee u500)   ;; 0.05%
    TICK_SPACING_10
    (if (is-eq fee u3000) ;; 0.3%
      TICK_SPACING_60
      (if (is-eq fee u10000) ;; 1%
        TICK_SPACING_200
        TICK_SPACING_60)))) ;; Default to 60

;; Read-only helper functions
(define-read-only (get-tick-bounds)
  {min-tick: MIN_TICK, max-tick: MAX_TICK})

(define-read-only (get-price-bounds)
  {min-sqrt-price: u4295128739,
   max-sqrt-price: u1461446703485210103287273052203988822378723970341})

(define-read-only (is-valid-tick (tick int))
  (and (>= tick MIN_TICK) (<= tick MAX_TICK)))

(define-read-only (is-valid-sqrt-price (sqrt-price uint))
  (and (> sqrt-price u0) 
       (<= sqrt-price u1461446703485210103287273052203988822378723970341)))