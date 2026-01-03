;; concentrated-math.clar
;; Conxian Standard: Q64.64 Fixed Point Math
;; Essential for SqrtPriceX96 and Tick calculations

(define-constant Q96 u79228162514264337593543950336) ;; 2^96
(define-constant ERR_OVERFLOW (err u3000))
(define-constant ERR_DIV_ZERO (err u3001))

;; @desc Multiplies two numbers and divides by a third with full precision
;; @param a uint
;; @param b uint
;; @param denominator uint
;; @returns (response uint uint)
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

;; @desc Converts a price to a sqrt-price X96 (Simplified for prototype)
;; @param price uint
;; @returns (uint)
(define-read-only (get-sqrt-price-x96 (price uint))
    ;; Placeholder: In real implementation this implements Babylonian sqrt
    ;; For now, we wrap a basic sqrt and shift for X96
    ;; Note: pure Clarity sqrt limited to uint128 range effectively
    (* (sqrti price) Q96)
)

;; @desc Computes the next square root price given a liquidity and amount
;; @param sqrt-price-current uint
;; @param liquidity uint
;; @param amount uint
;; @param add bool
;; @returns (uint)
(define-read-only (get-next-sqrt-price
        (sqrt-price-current uint)
        (liquidity uint)
        (amount uint)
        (add bool)
    )
    ;; Simplified linear approximation for prototype structure
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
        (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower))
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