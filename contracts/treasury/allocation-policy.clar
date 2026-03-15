;; Deprecated in favor of cxd-treasury.clar
(define-read-only (get-allocation-percentages)
  (ok {
    staking: u6000
    dev: u2000
    insurance: u2000
  })
)
