;; math-lib-concentrated.clar
;; Concentrated Liquidity Math Library
;; Implements core calculations for tick-based liquidity

(define-constant ERR_INVALID_TICK (err u2000))
(define-constant ERR_MATH_OVERFLOW (err u2001))

;; Min and Max Ticks (simplified for Clarity limits)
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)

;; Square root of 1.0001 in Q64.96 format (approximate for 1e18 precision here)
;; Using 1e18 as base for simplicity in this implementation
(define-constant SQRT_RATIO_AT_TICK_1 u1000049998750) ;; 1.0001^0.5 * 1e12

;; @desc Calculates sqrt(1.0001^tick) * 1e12
;; @param tick The tick index
(define-read-only (get-sqrt-ratio-at-tick (tick int))
  (let ((abs-tick (if (< tick 0)
      (* tick -1)
      tick
    )))
    (if (> abs-tick MAX_TICK)
      ERR_INVALID_TICK
      (ok (pow-sqrt-ratio abs-tick (>= tick 0)))
    )
  )
)

;; @desc Helper to calculate power of sqrt ratio
;; Iterative multiplication (O(log n))
(define-private (pow-sqrt-ratio (abs-tick int) (is-positive bool))
  (let
    (
      (ratio (fold pow-helper
        (list
          { tick: abs-tick, current: u1000049998750 }
          { tick: abs-tick, current: u1000100000000 }
          { tick: abs-tick, current: u1000200010000 }
          { tick: abs-tick, current: u1000400060004 }
          { tick: abs-tick, current: u1000800240021 }
          { tick: abs-tick, current: u1001600960128 }
          { tick: abs-tick, current: u1003203840923 }
          { tick: abs-tick, current: u1006415368983 }
          { tick: abs-tick, current: u1012869163026 }
          { tick: abs-tick, current: u1025850599931 }
          { tick: abs-tick, current: u1052350239995 }
          { tick: abs-tick, current: u1107445360166 }
          { tick: abs-tick, current: u1226445360166 }
          { tick: abs-tick, current: u1504188360166 }
          { tick: abs-tick, current: u2262562560166 }
          { tick: abs-tick, current: u5119098240166 }
        )
        { result: u1000000000000, bit: u1 }
      ))
    )
    (if is-positive
      (get result ratio)
      (/ u1000000000000 (get result ratio))
    )
  )
)

(define-private (pow-helper
    (entry {
      tick: int,
      current: uint,
    })
    (state {
      result: uint,
      bit: uint,
    })
  )
  (if (not (is-eq (and (get bit state) (get tick entry)) u0))
    (merge state { result: (/ (* (get result state) (get current entry)) u1000000000000), bit: (* (get bit state) u2) })
    (merge state { bit: (* (get bit state) u2) })
  )
)

;; @desc Calculates amount0 for a liquidity chunk
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
    (ok (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower))
      (* sqrt-ratio-upper sqrt-ratio-lower)
    ))
  )
)

;; @desc Calculates amount1 for a liquidity chunk
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
    (ok (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower)) u1000000000000))
    ;; normalized by 1e12
  )
)
