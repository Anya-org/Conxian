;; protocol-invariant-monitor.clar
;; Conxian Protocol: pure solvency and AMM invariant checks.

(define-constant BASIS_POINTS u10000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_TOLERANCE_BPS u10000)

(define-constant ERR_INVALID_TOLERANCE (err u2001))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u2002))

;; @desc Check protocol solvency. Equal assets and liabilities are solvent.
(define-read-only (check-invariants (total-assets uint) (total-liabilities uint))
  (ok (>= total-assets total-liabilities))
)

;; @desc Verify reserve-a * reserve-b against an expected constant product.
;; @param tolerance-bps Allowed absolute deviation from expected-product.
;; @dev Equality at the tolerance boundary passes. A zero reserve is treated
;;      as a zero product: it is valid only when expected-product is zero.
;;      Products that cannot be represented by a uint fail with an error.
(define-read-only (check-constant-product
    (reserve-a uint)
    (reserve-b uint)
    (expected-product uint)
    (tolerance-bps uint))
  (if (> tolerance-bps MAX_TOLERANCE_BPS)
    ERR_INVALID_TOLERANCE
    (if (or (is-eq reserve-a u0) (is-eq reserve-b u0))
      (ok (is-eq expected-product u0))
      (if (> reserve-a (/ MAX_UINT reserve-b))
        ERR_ARITHMETIC_OVERFLOW
        (let (
            (actual-product (* reserve-a reserve-b))
            (allowed-deviation (calculate-tolerance expected-product tolerance-bps))
            )
          (if (>= actual-product expected-product)
            (ok (<= (- actual-product expected-product) allowed-deviation))
            (ok (<= (- expected-product actual-product) allowed-deviation))
          )
        )
      )
    )
  )
)

;; Compute value * bps / 10,000 without multiplying value by bps first.
;; With bps <= 10,000, both products below remain within uint bounds.
(define-private (calculate-tolerance (value uint) (tolerance-bps uint))
  (let (
      (whole (/ value BASIS_POINTS))
      (remainder (mod value BASIS_POINTS))
      )
    (+
      (* whole tolerance-bps)
      (/ (* remainder tolerance-bps) BASIS_POINTS)
    )
  )
)
