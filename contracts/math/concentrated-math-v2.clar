;; concentrated-math-v2.clar
;; Bounded fixed-point arithmetic for the executable CLP V2.
;;
;; This is deliberately NOT the Uniswap logarithmic tick grid. Version 1 uses
;; the injective linear mapping sqrt(tick) = Q + tick * TICK-STEP over the
;; closed envelope [-5000, 10000]. All prices use Q = 1e12.

(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant Q u1000000000000)
(define-constant TICK-STEP u100000000)
(define-constant MIN-TICK (- 5000))
(define-constant MAX-TICK 10000)
(define-constant MIN-SQRT u500000000000)
(define-constant MAX-SQRT u2000000000000)
(define-constant MAX-LIQUIDITY u1000000000000)
(define-constant MAX-AMOUNT u1000000000000)

(define-constant ERR-INVALID-TICK (err u2200))
(define-constant ERR-INVALID-PRICE (err u2201))
(define-constant ERR-INVALID-RANGE (err u2202))
(define-constant ERR-INVALID-AMOUNT (err u2203))
(define-constant ERR-OVERFLOW (err u2204))
(define-constant ERR-DIVIDE-BY-ZERO (err u2205))
(define-constant ERR-INSUFFICIENT-AMOUNTS (err u2206))

(define-private (checked-add (a uint) (b uint))
  (if (> a (- MAX-UINT b)) none (some (+ a b))))

(define-private (checked-sub (a uint) (b uint))
  (if (< a b) none (some (- a b))))

(define-private (checked-mul (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (some u0)
    (if (> a (/ MAX-UINT b)) none (some (* a b)))))

(define-private (checked-div (a uint) (b uint))
  (if (is-eq b u0) none (some (/ a b))))

(define-private (checked-ceil-div (a uint) (b uint))
  (if (is-eq b u0)
    none
    (let ((q (/ a b)) (r (mod a b)))
      (if (is-eq r u0) (some q) (checked-add q u1)))))

(define-private (mul-div-floor (a uint) (b uint) (denominator uint))
  (match (checked-mul a b)
    product (checked-div product denominator)
    none))

(define-private (mul-div-ceil (a uint) (b uint) (denominator uint))
  (match (checked-mul a b)
    product (checked-ceil-div product denominator)
    none))

(define-read-only (get-constants)
  {
    q: Q,
    tick-step: TICK-STEP,
    min-tick: MIN-TICK,
    max-tick: MAX-TICK,
    min-sqrt: MIN-SQRT,
    max-sqrt: MAX-SQRT,
    max-liquidity: MAX-LIQUIDITY,
    max-amount: MAX-AMOUNT,
    calculation-version: "linear-v1"
  })

(define-read-only (is-valid-tick (tick int))
  (and (>= tick MIN-TICK) (<= tick MAX-TICK)))

(define-read-only (is-valid-sqrt-price (sqrt-price uint))
  (and (>= sqrt-price MIN-SQRT) (<= sqrt-price MAX-SQRT)))

(define-read-only (tick-to-sqrt-price (tick int))
  (begin
    (asserts! (is-valid-tick tick) ERR-INVALID-TICK)
    (if (>= tick 0)
      (ok (+ Q (* (to-uint tick) TICK-STEP)))
      (ok (- Q (* (to-uint (* tick (- 1))) TICK-STEP))))))

;; Returns the greatest grid tick whose sqrt price is <= sqrt-price.
(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (if (>= sqrt-price Q)
      (ok (to-int (/ (- sqrt-price Q) TICK-STEP)))
      (let ((distance (- Q sqrt-price)))
        ;; Negative division must floor toward -infinity, not toward zero.
        (if (is-eq (mod distance TICK-STEP) u0)
          (ok (* (to-int (/ distance TICK-STEP)) (- 1)))
          (ok (* (to-int (+ (/ distance TICK-STEP) u1)) (- 1))))))))

(define-read-only (is-aligned-tick (tick int) (spacing uint))
  (and
    (> spacing u0)
    (is-valid-tick tick)
    (is-eq (mod tick (to-int spacing)) 0)))

;; amount0 = L * Q * (sb-sa) / (sb*sa)
(define-read-only (amount0-delta (sa uint) (sb uint) (liquidity uint) (round-up bool))
  (begin
    (asserts! (and (is-valid-sqrt-price sa) (is-valid-sqrt-price sb) (< sa sb)) ERR-INVALID-RANGE)
    (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INVALID-AMOUNT)
    (let (
      (delta (- sb sa))
      (lq (unwrap! (checked-mul liquidity Q) ERR-OVERFLOW))
      (numerator (unwrap! (checked-mul lq delta) ERR-OVERFLOW))
      (denominator (unwrap! (checked-mul sb sa) ERR-OVERFLOW))
    )
      (if round-up
        (ok (unwrap! (checked-ceil-div numerator denominator) ERR-DIVIDE-BY-ZERO))
        (ok (unwrap! (checked-div numerator denominator) ERR-DIVIDE-BY-ZERO))))))

;; amount1 = L * (sb-sa) / Q
(define-read-only (amount1-delta (sa uint) (sb uint) (liquidity uint) (round-up bool))
  (begin
    (asserts! (and (is-valid-sqrt-price sa) (is-valid-sqrt-price sb) (< sa sb)) ERR-INVALID-RANGE)
    (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INVALID-AMOUNT)
    (let ((numerator (unwrap! (checked-mul liquidity (- sb sa)) ERR-OVERFLOW)))
      (if round-up
        (ok (unwrap! (checked-ceil-div numerator Q) ERR-DIVIDE-BY-ZERO))
        (ok (/ numerator Q))))))

(define-private (liquidity-below (sa uint) (sb uint) (amount0 uint))
  ;; floor(amount0 * sa * sb / (Q * (sb-sa)))
  (let (
    (a-sa (unwrap! (checked-mul amount0 sa) ERR-OVERFLOW))
    (numerator (unwrap! (checked-mul a-sa sb) ERR-OVERFLOW))
    (denominator (unwrap! (checked-mul Q (- sb sa)) ERR-OVERFLOW))
  )
    (ok (/ numerator denominator))))

(define-private (liquidity-above (sa uint) (sb uint) (amount1 uint))
  ;; floor(amount1 * Q / (sb-sa))
  (ok (unwrap! (mul-div-floor amount1 Q (- sb sa)) ERR-OVERFLOW)))

(define-private (liquidity-inside-0 (s uint) (sb uint) (amount0 uint))
  ;; floor(amount0 * s * sb / (Q * (sb-s)))
  (let (
    (a-s (unwrap! (checked-mul amount0 s) ERR-OVERFLOW))
    (numerator (unwrap! (checked-mul a-s sb) ERR-OVERFLOW))
    (denominator (unwrap! (checked-mul Q (- sb s)) ERR-OVERFLOW))
  )
    (ok (/ numerator denominator))))

(define-private (liquidity-inside-1 (sa uint) (s uint) (amount1 uint))
  (ok (unwrap! (mul-div-floor amount1 Q (- s sa)) ERR-OVERFLOW)))

;; Derive the greatest liquidity supported by maxima, then return the exact
;; ceil-rounded debit requirements. This cannot overmint against either side.
(define-read-only (quote-position
    (sqrt-price uint)
    (lower-tick int)
    (upper-tick int)
    (max-amount0 uint)
    (max-amount1 uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (asserts! (and (is-valid-tick lower-tick) (is-valid-tick upper-tick) (< lower-tick upper-tick)) ERR-INVALID-RANGE)
    (asserts! (and (<= max-amount0 MAX-AMOUNT) (<= max-amount1 MAX-AMOUNT)) ERR-INVALID-AMOUNT)
    (let (
      (sa (unwrap! (tick-to-sqrt-price lower-tick) ERR-INVALID-TICK))
      (sb (unwrap! (tick-to-sqrt-price upper-tick) ERR-INVALID-TICK))
      (liquidity
        (if (<= sqrt-price sa)
          (unwrap! (liquidity-below sa sb max-amount0) ERR-OVERFLOW)
          (if (>= sqrt-price sb)
            (unwrap! (liquidity-above sa sb max-amount1) ERR-OVERFLOW)
            (let (
              (l0 (unwrap! (liquidity-inside-0 sqrt-price sb max-amount0) ERR-OVERFLOW))
              (l1 (unwrap! (liquidity-inside-1 sa sqrt-price max-amount1) ERR-OVERFLOW))
            )
              (if (< l0 l1) l0 l1)))))
    )
      (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INSUFFICIENT-AMOUNTS)
      (let (
        (required0
          (if (<= sqrt-price sa)
            (unwrap! (amount0-delta sa sb liquidity true) ERR-OVERFLOW)
            (if (< sqrt-price sb)
              (unwrap! (amount0-delta sqrt-price sb liquidity true) ERR-OVERFLOW)
              u0)))
        (required1
          (if (>= sqrt-price sb)
            (unwrap! (amount1-delta sa sb liquidity true) ERR-OVERFLOW)
            (if (> sqrt-price sa)
              (unwrap! (amount1-delta sa sqrt-price liquidity true) ERR-OVERFLOW)
              u0)))
      )
        (asserts! (and (<= required0 max-amount0) (<= required1 max-amount1)) ERR-INSUFFICIENT-AMOUNTS)
        (ok { liquidity: liquidity, amount0: required0, amount1: required1, sa: sa, sb: sb })))))

(define-read-only (principal-at-price
    (sqrt-price uint)
    (lower-tick int)
    (upper-tick int)
    (liquidity uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (asserts! (and (is-valid-tick lower-tick) (is-valid-tick upper-tick) (< lower-tick upper-tick)) ERR-INVALID-RANGE)
    (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INVALID-AMOUNT)
    (let (
      (sa (unwrap! (tick-to-sqrt-price lower-tick) ERR-INVALID-TICK))
      (sb (unwrap! (tick-to-sqrt-price upper-tick) ERR-INVALID-TICK))
    )
      (if (<= sqrt-price sa)
        (ok { amount0: (unwrap! (amount0-delta sa sb liquidity false) ERR-OVERFLOW), amount1: u0 })
        (if (>= sqrt-price sb)
          (ok { amount0: u0, amount1: (unwrap! (amount1-delta sa sb liquidity false) ERR-OVERFLOW) })
          (ok {
            amount0: (unwrap! (amount0-delta sqrt-price sb liquidity false) ERR-OVERFLOW),
            amount1: (unwrap! (amount1-delta sa sqrt-price liquidity false) ERR-OVERFLOW)
          }))))))

;; token0 in, price down. Net input x excludes the per-step fee.
(define-read-only (next-sqrt-from-token0 (sqrt-price uint) (liquidity uint) (amount0-in uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INVALID-AMOUNT)
    (asserts! (and (> amount0-in u0) (<= amount0-in MAX-AMOUNT)) ERR-INVALID-AMOUNT)
    (let (
      (lq (unwrap! (checked-mul liquidity Q) ERR-OVERFLOW))
      (numerator (unwrap! (checked-mul lq sqrt-price) ERR-OVERFLOW))
      (xs (unwrap! (checked-mul amount0-in sqrt-price) ERR-OVERFLOW))
      (denominator (unwrap! (checked-add lq xs) ERR-OVERFLOW))
      (next (unwrap! (checked-ceil-div numerator denominator) ERR-DIVIDE-BY-ZERO))
    )
      (asserts! (is-valid-sqrt-price next) ERR-INVALID-PRICE)
      (ok next))))

;; token1 in, price up. Net input x excludes the per-step fee.
(define-read-only (next-sqrt-from-token1 (sqrt-price uint) (liquidity uint) (amount1-in uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (asserts! (and (> liquidity u0) (<= liquidity MAX-LIQUIDITY)) ERR-INVALID-AMOUNT)
    (asserts! (and (> amount1-in u0) (<= amount1-in MAX-AMOUNT)) ERR-INVALID-AMOUNT)
    (let (
      (increment (unwrap! (mul-div-floor amount1-in Q liquidity) ERR-OVERFLOW))
      (next (unwrap! (checked-add sqrt-price increment) ERR-OVERFLOW))
    )
      (asserts! (is-valid-sqrt-price next) ERR-INVALID-PRICE)
      (ok next))))

(define-read-only (price-token1-per-token0 (sqrt-price uint))
  (begin
    (asserts! (is-valid-sqrt-price sqrt-price) ERR-INVALID-PRICE)
    (ok (unwrap! (mul-div-floor sqrt-price sqrt-price Q) ERR-OVERFLOW))))

;; Public checked-arithmetic probes are intentional: boundary tests exercise
;; every uint128 guard without relying on pretty-printed source inspection.
(define-read-only (checked-add-public (a uint) (b uint))
  (match (checked-add a b) value (ok value) ERR-OVERFLOW))
(define-read-only (checked-sub-public (a uint) (b uint))
  (match (checked-sub a b) value (ok value) ERR-OVERFLOW))
(define-read-only (checked-mul-public (a uint) (b uint))
  (match (checked-mul a b) value (ok value) ERR-OVERFLOW))
(define-read-only (checked-div-public (a uint) (b uint))
  (match (checked-div a b) value (ok value) ERR-DIVIDE-BY-ZERO))
(define-read-only (checked-ceil-div-public (a uint) (b uint))
  (match (checked-ceil-div a b) value (ok value) ERR-DIVIDE-BY-ZERO))
