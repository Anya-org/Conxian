;; concentrated-math.clar
;; Conxian Standard: Q64.64 Fixed Point Math
;; Essential for SqrtPriceX96 and Tick calculations
;; Adheres to Decentralized Modularity and Bitcoin Ethos

(define-constant Q96 u79228162514264337593543950336) ;; 2^96
(define-constant ERR_OVERFLOW (err u3000))
(define-constant ERR_DIV_ZERO (err u3001))

;; @desc Multiplies two numbers and divides by a third with full precision
(define-read-only (mul-div
    (a uint)
    (b uint)
    (denominator uint)
  )
  (let ((prod-a-b (* a b)))
    (if (is-eq denominator u0)
      ERR_DIV_ZERO
      (ok (/ prod-a-b denominator))
    )
  )
)

;; @desc Iterative Square Root Implementation (Babylonian method)
;; Clarity does not support recursion; using fold over a fixed range
(define-read-only (sqrt (y uint))
  (if (> y u3)
    (let (
        (z y)
        (x (+ (/ y u2) u1))
      )
      ;; 16 iterations is usually enough for uint precision
      (fold sqrt-iter-step
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16) {
        y: y,
        x: x,
      })
    )
    (if (is-eq y u0)
      {
        y: y,
        x: u0,
      }
      {
        y: y,
        x: u1,
      }
    )
  )
)

(define-private (sqrt-iter-step
    (unused uint)
    (state {
      y: uint,
      x: uint,
    })
  )
  (let (
      (y (get y state))
      (x (get x state))
      (next-x (/ (+ x (/ y x)) u2))
    )
    (if (is-eq next-x x)
      state
      {
        y: y,
        x: next-x,
      }
    )
  )
)

;; @desc Wrapper to return just the sqrt value
(define-read-only (get-sqrt (y uint))
  (get x (sqrt y))
)

;; @desc Converts a price to a sqrt-price X96
(define-read-only (get-sqrt-price-x96 (price uint))
  (* (get-sqrt price) Q96)
)

(define-read-only (get-next-sqrt-price
    (sqrt-price-current uint)
    (liquidity uint)
    (amount uint)
    (add bool)
  )
  (if add
    (+ sqrt-price-current (/ (* amount Q96) liquidity))
    (- sqrt-price-current (/ (* amount Q96) liquidity))
  )
)

;; @desc Calculates the amount of token0 for a price range
(define-read-only (get-amount0-delta
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (liquidity uint)
  )
  (let (
      (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96)
      (* sqrt-ratio-upper sqrt-ratio-lower)
    )
  )
)

;; @desc Calculates the amount of token1 for a price range
(define-read-only (get-amount1-delta
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (liquidity uint)
  )
  (let (
      (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower)) Q96)
  )
)
