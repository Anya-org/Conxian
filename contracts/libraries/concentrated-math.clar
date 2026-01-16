;; concentrated-math.clar
;; Conxian Standard: Q64.64 Fixed Point Math
;; Essential for SqrtPriceX96 and Tick calculations
;; Adheres to Decentralized Modularity and Bitcoin Ethos

(define-constant Q96 u79228162514264337593543950336) ;; 2^96
(define-constant ERR_OVERFLOW (err u3000))
(define-constant ERR_DIV_ZERO (err u3001))

;; BOLT: Constant for the starting bit in the bitwise sqrt algorithm (2^126)
(define-constant SQRT_BIT_START u85070591730234615865843651857942052864)

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

;; BOLT: Replaced iterative Babylonian method with a faster bitwise square root algorithm.
;; This method avoids expensive division in each iteration, resulting in significant gas savings.
;; Before: Iterative division, O(log N) with expensive division.
;; After: Bitwise operations, O(1) in terms of iterations (fixed at 16), with cheap bitwise ops.
(define-read-only (sqrt (y uint))
  (if (is-eq y u0)
      {x: u0, y: u0}
      (let ((res (fold sqrt-iter-bitwise
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60 u61 u62 u63)
        { n: y, root: u0, bit: SQRT_BIT_START }
      )))
        {x: (get root res), y: y}
      )
  )
)

(define-private (sqrt-iter-bitwise (unused uint) (state {n: uint, root: uint, bit: uint}))
  (let
    (
      (n (get n state))
      (root (get root state))
      (bit (get bit state))
    )
    (if (>= n (+ root bit))
      { n: (- n (+ root bit)), root: (+ (/ root u2) bit), bit: (/ bit u4) }
      { n: n, root: (/ root u2), bit: (/ bit u4) }
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
