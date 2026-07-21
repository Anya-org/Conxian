;; predictive-scaling-system.clar
;; Conxian Protocol: bounded, deterministic DEX policy helpers.

;; Ratios returned by get-scaling-factor use percentage points (100 = 1.0x).
;; The newer fee/depth helpers use basis points (10,000 = 100%).
(define-constant PERCENT_SCALE u100)
(define-constant BASIS_POINTS u10000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_VOLATILITY_BPS u10000)
(define-constant MAX_FEE_BPS u10000)

;; Error codes are scoped to this policy contract.
(define-constant ERR_ZERO_BASELINE (err u1001))
(define-constant ERR_INVALID_BOUNDS (err u1002))
(define-constant ERR_ZERO_DEPTH (err u1003))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u1004))

;; @desc Return activity relative to a baseline in percentage points.
;; @dev The legacy 100-point scale is retained for compatibility. A zero
;;      baseline and multiplication overflow fail closed with an error.
(define-read-only (get-scaling-factor (current-activity uint) (baseline uint))
  (if (is-eq baseline u0)
    ERR_ZERO_BASELINE
    (if (> current-activity (/ MAX_UINT PERCENT_SCALE))
      ERR_ARITHMETIC_OVERFLOW
      (ok (/ (* current-activity PERCENT_SCALE) baseline))
    )
  )
)

;; @desc Adjust a base fee by volatility expressed in basis points.
;; @dev Volatility is capped at 10,000 bps. The result is clamped inclusively
;;      to [min-fee-bps, max-fee-bps], and max-fee-bps cannot exceed 100%.
(define-read-only (get-volatility-adjusted-fee-bps
    (base-fee-bps uint)
    (volatility-bps uint)
    (min-fee-bps uint)
    (max-fee-bps uint))
  (if (or (> min-fee-bps max-fee-bps) (> max-fee-bps MAX_FEE_BPS))
    ERR_INVALID_BOUNDS
    (let (
        (bounded-base-fee (if (> base-fee-bps MAX_FEE_BPS) MAX_FEE_BPS base-fee-bps))
        (bounded-volatility (if (> volatility-bps MAX_VOLATILITY_BPS) MAX_VOLATILITY_BPS volatility-bps))
        )
      (let (
          (scaled-fee (+ bounded-base-fee (/ (* bounded-base-fee bounded-volatility) BASIS_POINTS)))
          )
        (ok (if (< scaled-fee min-fee-bps)
          min-fee-bps
          (if (> scaled-fee max-fee-bps) max-fee-bps scaled-fee)
        ))
      )
    )
  )
)

;; @desc Scale current liquidity by target depth / observed depth.
;; @param target-depth-bps Desired depth, in basis points.
;; @param observed-depth-bps Observed depth, in basis points.
;; @dev Both depth values are bounded to [0, 10,000]. An observed depth of
;;      zero is invalid. Multiplication overflow returns an error instead of
;;      aborting the read-only call.
(define-read-only (get-depth-adjusted-liquidity
    (current-liquidity uint)
    (target-depth-bps uint)
    (observed-depth-bps uint))
  (if (is-eq observed-depth-bps u0)
    ERR_ZERO_DEPTH
    (if (or (> target-depth-bps BASIS_POINTS) (> observed-depth-bps BASIS_POINTS))
      ERR_INVALID_BOUNDS
      (if (is-eq target-depth-bps u0)
        (ok u0)
        (if (is-eq target-depth-bps observed-depth-bps)
          (ok current-liquidity)
          (if (> current-liquidity (/ MAX_UINT target-depth-bps))
            ERR_ARITHMETIC_OVERFLOW
            (ok (/ (* current-liquidity target-depth-bps) observed-depth-bps))
          )
        )
      )
    )
  )
)
