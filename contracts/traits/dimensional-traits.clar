;; dimensional-traits.clar
;; Traits for Dimensional Market logic

(define-trait dimensional-market-trait (
  (open-position
    (uint uint (string-ascii 20) uint principal (string-ascii 20))
    (response uint uint)
  )
  (close-position
    (uint uint)
    (response bool uint)
  )
  (liquidate-position
    (principal uint)
    (response bool uint)
  )
))
