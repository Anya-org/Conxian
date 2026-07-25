;; concentrated-math.clar
;; Math library for concentrated liquidity.
;;
;; Price values in this contract use a decimal fixed-point scale of 1e12.
;; They are not Q96 values despite the legacy parameter names retained for ABI
;; compatibility. Tick conversion remains a deterministic linear
;; approximation, so execution-facing callers must use the checked APIs and
;; the narrower supported execution tick range below. Nothing in this module
;; claims exact Uniswap V3 tick math.

;; Constants
(define-constant MIN_TICK (- 887272))
(define-constant MAX_TICK 887272)
(define-constant MIN_EXECUTION_TICK (- 10000))
(define-constant MAX_EXECUTION_TICK 10000)
(define-constant PRICE_SCALE u1000000000000)
(define-constant TICK_PRICE_STEP u49998750)
(define-constant MIN_SUPPORTED_SQRT_PRICE u500012500000)
(define-constant MAX_SUPPORTED_SQRT_PRICE u1499987500000)
(define-constant MAX_SUPPORTED_LIQUIDITY u100000000000000)

;; Errors
(define-constant ERR_INVALID_TICK u2001)
(define-constant ERR_INVALID_SQRT_PRICE u2002)
(define-constant ERR_INVALID_LIQUIDITY u2003)
(define-constant ERR_INVALID_PRICE_RANGE u2004)

(define-private (is-supported-sqrt-price (sqrt-price uint))
  (and
    (>= sqrt-price MIN_SUPPORTED_SQRT_PRICE)
    (<= sqrt-price MAX_SUPPORTED_SQRT_PRICE)
  )
)

(define-private (is-supported-liquidity (liquidity uint))
  (and (> liquidity u0) (<= liquidity MAX_SUPPORTED_LIQUIDITY))
)

(define-private (divide-round-up (numerator uint) (denominator uint))
  (let ((quotient (/ numerator denominator)))
    (if (is-eq (mod numerator denominator) u0)
      quotient
      (+ quotient u1)
    )
  )
)

;; @desc Checked approximate conversion used by pool creation and previews.
(define-read-only (get-sqrt-ratio-at-tick-checked (tick int))
  (if (and (>= tick MIN_EXECUTION_TICK) (<= tick MAX_EXECUTION_TICK))
    (if (>= tick 0)
      (ok (+ PRICE_SCALE (* (to-uint tick) TICK_PRICE_STEP)))
      (ok (- PRICE_SCALE (* (to-uint (* tick (- 1))) TICK_PRICE_STEP)))
    )
    (err ERR_INVALID_TICK)
  )
)

;; @desc Legacy ABI-shape wrapper. It preserves the raw uint return shape, not
;; historical behavior. Unsupported ticks return u0, which is ambiguous with a
;; valid zero result and must never be used for settlement.
(define-read-only (get-sqrt-ratio-at-tick (tick int))
  (match (get-sqrt-ratio-at-tick-checked tick)
    sqrt-price sqrt-price
    error-code u0
  )
)

;; @desc Checked inverse conversion for the supported linear approximation.
;; Returns the greatest supported tick whose model price is <= sqrt-price.
(define-read-only (get-tick-at-sqrt-ratio-checked (sqrt-price uint))
  (if (is-supported-sqrt-price sqrt-price)
    (if (>= sqrt-price PRICE_SCALE)
      (ok (to-int (/ (- sqrt-price PRICE_SCALE) TICK_PRICE_STEP)))
      ;; Negative ticks require the ceiling magnitude. PRICE_SCALE - 1 is
      ;; below tick 0 and therefore floors to tick -1.
      (ok (* (to-int (divide-round-up (- PRICE_SCALE sqrt-price) TICK_PRICE_STEP)) (- 1)))
    )
    (err ERR_INVALID_SQRT_PRICE)
  )
)

;; @desc Legacy ABI-shape wrapper. Invalid values return tick 0; that fallback
;; is ambiguous with a valid result, so settlement must use the checked API.
(define-read-only (get-tick-at-sqrt-ratio (sqrt-price-x96 uint))
  (match (get-tick-at-sqrt-ratio-checked sqrt-price-x96)
    tick tick
    error-code 0
  )
)

;; The checked delta helpers bound both sqrt prices and liquidity before any
;; multiplication. Under these bounds:
;;   liquidity * price-difference * PRICE_SCALE <= 1e38
;;   sqrt-price-high * sqrt-price-low < 2.25e24
;; so every intermediate fits Clarity's uint128 range. Amount0 is the bounded
;; approximation L * (sqrtB - sqrtA) * scale / (sqrtB * sqrtA); amount1 is
;; L * (sqrtB - sqrtA) / scale. Down helpers floor; up helpers ceil.

(define-private (validate-delta-inputs
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (begin
    (asserts! (is-supported-sqrt-price sqrt-price-a-x96) (err ERR_INVALID_SQRT_PRICE))
    (asserts! (is-supported-sqrt-price sqrt-price-b-x96) (err ERR_INVALID_SQRT_PRICE))
    (asserts! (not (is-eq sqrt-price-a-x96 sqrt-price-b-x96)) (err ERR_INVALID_PRICE_RANGE))
    (asserts! (is-supported-liquidity liquidity) (err ERR_INVALID_LIQUIDITY))
    (ok true)
  )
)

(define-read-only (get-amount0-delta-down
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (begin
    (try! (validate-delta-inputs sqrt-price-a-x96 sqrt-price-b-x96 liquidity))
    (let (
      (sqrt-price-low (if (< sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (sqrt-price-high (if (> sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (price-difference (- sqrt-price-high sqrt-price-low))
      (numerator (* (* liquidity price-difference) PRICE_SCALE))
      (denominator (* sqrt-price-high sqrt-price-low))
    )
      (ok (/ numerator denominator))
    )
  )
)

(define-read-only (get-amount0-delta-up
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (begin
    (try! (validate-delta-inputs sqrt-price-a-x96 sqrt-price-b-x96 liquidity))
    (let (
      (sqrt-price-low (if (< sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (sqrt-price-high (if (> sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (price-difference (- sqrt-price-high sqrt-price-low))
      (numerator (* (* liquidity price-difference) PRICE_SCALE))
      (denominator (* sqrt-price-high sqrt-price-low))
    )
      (ok (divide-round-up numerator denominator))
    )
  )
)

(define-read-only (get-amount1-delta-down
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (begin
    (try! (validate-delta-inputs sqrt-price-a-x96 sqrt-price-b-x96 liquidity))
    (let (
      (sqrt-price-low (if (< sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (sqrt-price-high (if (> sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
    )
      (ok (/ (* liquidity (- sqrt-price-high sqrt-price-low)) PRICE_SCALE))
    )
  )
)

(define-read-only (get-amount1-delta-up
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (begin
    (try! (validate-delta-inputs sqrt-price-a-x96 sqrt-price-b-x96 liquidity))
    (let (
      (sqrt-price-low (if (< sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
      (sqrt-price-high (if (> sqrt-price-a-x96 sqrt-price-b-x96) sqrt-price-a-x96 sqrt-price-b-x96))
    )
      (ok (divide-round-up (* liquidity (- sqrt-price-high sqrt-price-low)) PRICE_SCALE))
    )
  )
)

;; Legacy ABI-shape wrappers return u0 for invalid/out-of-bound inputs. That
;; fallback is ambiguous with a valid zero amount, so execution code must use
;; the explicit checked round-down or round-up APIs.
(define-read-only (get-amount0-delta
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (match (get-amount0-delta-down sqrt-price-a-x96 sqrt-price-b-x96 liquidity)
    amount amount
    error-code u0
  )
)

(define-read-only (get-amount1-delta
    (sqrt-price-a-x96 uint)
    (sqrt-price-b-x96 uint)
    (liquidity uint)
  )
  (match (get-amount1-delta-down sqrt-price-a-x96 sqrt-price-b-x96 liquidity)
    amount amount
    error-code u0
  )
)

;; @desc Check if tick is valid
(define-read-only (is-valid-tick (tick int))
  (and (>= tick MIN_TICK) (<= tick MAX_TICK))
)

;; @desc Get MIN_TICK
(define-read-only (get-min-tick)
  MIN_TICK
)

;; @desc Get MAX_TICK
(define-read-only (get-max-tick)
  MAX_TICK
)

(define-read-only (is-supported-execution-tick (tick int))
  (and (>= tick MIN_EXECUTION_TICK) (<= tick MAX_EXECUTION_TICK))
)

(define-read-only (get-min-execution-tick)
  MIN_EXECUTION_TICK
)

(define-read-only (get-max-execution-tick)
  MAX_EXECUTION_TICK
)

(define-read-only (get-price-scale)
  PRICE_SCALE
)

(define-read-only (get-max-supported-liquidity)
  MAX_SUPPORTED_LIQUIDITY
)
