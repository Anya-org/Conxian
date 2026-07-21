;; rebalancing-rules.clar
;; Conxian Protocol: pure, deterministic rebalance policy helpers.

;; @desc Determine if rebalancing is required based on current and target ratios.
;; @dev Threshold equality does not trigger a rebalance; the comparison is
;;      strictly greater-than for compatibility with the original helper.
(define-read-only (should-rebalance (current-ratio uint) (target-ratio uint) (threshold uint))
  (let ((diff (if (> current-ratio target-ratio)
    (- current-ratio target-ratio)
    (- target-ratio current-ratio)
  )))
    (ok (> diff threshold))
  )
)

;; @desc Return the absolute ratio delta without unsigned underflow.
(define-read-only (get-rebalance-delta (current-ratio uint) (target-ratio uint))
  (ok (if (> current-ratio target-ratio)
    (- current-ratio target-ratio)
    (- target-ratio current-ratio)
  ))
)

;; @desc Return +1 when the target is above current, -1 when below, or 0.
;; @dev The signed direction is bounded to {-1, 0, +1}; no uint-to-int cast is
;;      needed, so arbitrary uint ratios remain safe.
(define-read-only (get-rebalance-direction (current-ratio uint) (target-ratio uint))
  (ok (if (> target-ratio current-ratio)
    1
    (if (< target-ratio current-ratio) (- 1) 0)
  ))
)
