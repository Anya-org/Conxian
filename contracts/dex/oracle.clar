;; oracle.clar
;; Conxian Protocol: DEX oracle facade.
;;
;; Canonical spot prices come from oracle-aggregator and canonical TWAP prices
;; come from twap-oracle. The legacy set-price API is retained only as
;; advisory metadata for compatibility; it is never used by the oracle trait
;; implementation or validation paths.

(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant BASIS_POINTS u10000)
(define-constant DEFAULT_MAX_TWAP_DEVIATION_BPS u500)
(define-constant ERR_ZERO_PRICE (err u7001))
(define-constant ERR_INVALID_DEVIATION (err u7002))
(define-constant ERR_ZERO_SPOT_PRICE (err u7003))
(define-constant ERR_ZERO_TWAP_PRICE (err u7004))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u7005))
(define-constant ERR_DEVIATION_TOO_HIGH (err u7006))

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var max-twap-deviation-bps uint DEFAULT_MAX_TWAP_DEVIATION_BPS)
(define-map legacy-prices principal { price: uint, updated-at: uint })

;; Private helpers

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Preserve upstream response errors while rejecting successful zero prices.
(define-private (require-nonzero-price (price-result (response uint uint)))
  (match price-result
    price (if (> price u0) (ok price) ERR_ZERO_PRICE)
    error (err error)
  )
)

;; Compute ceil(reference * bps / 10,000) without multiplying the full
;; reference by bps. bps is bounded to 10,000, so both products are safe.
(define-private (ceil-reference-times-bps (reference uint) (bps uint))
  (let (
      (whole-part (* (/ reference BASIS_POINTS) bps))
      (remainder-part (* (mod reference BASIS_POINTS) bps))
    )
    (+ whole-part
      (if (is-eq remainder-part u0)
        u0
        (if (is-eq (mod remainder-part BASIS_POINTS) u0)
          (/ remainder-part BASIS_POINTS)
          (+ (/ remainder-part BASIS_POINTS) u1)
        )
      )
    )
  )
)

;; Find floor(remainder * 10,000 / reference), where remainder < reference.
;; The fixed binary steps avoid an overflow-prone remainder * 10,000.
(define-private (accumulate-fractional-bps
    (step uint)
    (acc { candidate: uint, difference: uint, reference: uint }))
  (let ((candidate (+ (get candidate acc) step)))
    (if (and
        (<= candidate BASIS_POINTS)
        (>=
          (get difference acc)
          (ceil-reference-times-bps (get reference acc) candidate)
        )
      )
      {
        candidate: candidate,
        difference: (get difference acc),
        reference: (get reference acc)
      }
      acc
    )
  )
)

(define-private (calculate-fractional-bps (difference uint) (reference uint))
  (get candidate
    (fold accumulate-fractional-bps
      (list u8192 u4096 u2048 u1024 u512 u256 u128 u64 u32 u16 u8 u4 u2 u1)
      { candidate: u0, difference: difference, reference: reference }
    )
  )
)

;; Compute floor(difference * 10,000 / reference) without an overflowing
;; multiplication. The integral portion is checked explicitly; the remainder
;; portion is solved with the bounded binary helper above. At the quotient
;; boundary, the fractional portion must also fit in MAX_UINT.
(define-private (calculate-deviation-bps (difference uint) (reference uint))
  (if (is-eq reference u0)
    ERR_ZERO_TWAP_PRICE
    (let (
        (whole-part (/ difference reference))
        (fractional-part (calculate-fractional-bps (mod difference reference) reference))
      )
      (if (> whole-part (/ MAX_UINT BASIS_POINTS))
        ERR_ARITHMETIC_OVERFLOW
        (if (and
            (is-eq whole-part (/ MAX_UINT BASIS_POINTS))
            (> fractional-part (mod MAX_UINT BASIS_POINTS))
          )
          ERR_ARITHMETIC_OVERFLOW
          (ok (+ (* whole-part BASIS_POINTS) fractional-part))
        )
      )
    )
  )
)

;; Read and validate both canonical sources while preserving upstream errors.
(define-private (get-spot-twap (token principal))
  (match (contract-call? .oracle-aggregator get-price token)
    spot
      (if (is-eq spot u0)
        ERR_ZERO_SPOT_PRICE
        (match (contract-call? .twap-oracle get-price token)
          twap
            (if (is-eq twap u0)
              ERR_ZERO_TWAP_PRICE
              (ok { spot: spot, twap: twap })
            )
          error (err error)
        )
      )
    error (err error)
  )
)

(define-private (get-price-diagnostics-internal (token principal))
  (match (get-spot-twap token)
    prices
      (let (
          (spot (get spot prices))
          (twap (get twap prices))
          (difference (if (> spot twap) (- spot twap) (- twap spot)))
        )
        (match (calculate-deviation-bps difference twap)
          deviation
            (ok {
              spot: spot,
              twap: twap,
              deviation-bps: deviation
            })
          error (err error)
        )
      )
    error (err error)
  )
)

;; Public Functions

;; @desc Set advisory legacy metadata for a specific token.
;; @deprecated Canonical get-price/fetch-price never read this value.
(define-public (set-price (token principal) (price uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (> price u0) ERR_ZERO_PRICE)
    (map-set legacy-prices token { price: price, updated-at: burn-block-height })
    (print {
      event: "legacy-price-set",
      token: token,
      price: price,
      updated-at: burn-block-height
    })
    (ok true)
  )
)

;; @desc Set the inclusive maximum spot-vs-TWAP deviation in basis points.
(define-public (set-max-twap-deviation-bps (new-deviation-bps uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-deviation-bps BASIS_POINTS) ERR_INVALID_DEVIATION)
    (var-set max-twap-deviation-bps new-deviation-bps)
    (print {
      event: "max-twap-deviation-updated",
      deviation-bps: new-deviation-bps
    })
    (ok true)
  )
)

;; Read-only Functions

;; @desc Get the canonical multi-source aggregate price.
(define-read-only (get-price (token principal))
  (require-nonzero-price (contract-call? .oracle-aggregator get-price token))
)

;; @desc Fetch the canonical multi-source aggregate price.
(define-public (fetch-price (token principal))
  (require-nonzero-price (contract-call? .oracle-aggregator get-price token))
)

;; @desc Get the canonical TWAP price.
(define-read-only (get-twap-price (token principal))
  (require-nonzero-price (contract-call? .twap-oracle get-price token))
)

;; @desc Return the advisory legacy price and its update height, if present.
(define-read-only (get-legacy-price (token principal))
  (map-get? legacy-prices token)
)

;; @desc Return the configured maximum TWAP deviation in basis points.
(define-read-only (get-max-twap-deviation-bps)
  (var-get max-twap-deviation-bps)
)

;; @desc Return spot, TWAP, and absolute deviation in basis points.
(define-read-only (get-price-diagnostics (token principal))
  (get-price-diagnostics-internal token)
)

;; @desc Return canonical spot only when it passes the inclusive TWAP bound.
(define-read-only (get-validated-price (token principal))
  (match (get-price-diagnostics-internal token)
    diagnostics
      (if (<=
          (get deviation-bps diagnostics)
          (var-get max-twap-deviation-bps)
        )
        (ok (get spot diagnostics))
        ERR_DEVIATION_TOO_HIGH
      )
    error (err error)
  )
)

;; @desc Transfer contract ownership to a new principal
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Return the current contract owner.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)
