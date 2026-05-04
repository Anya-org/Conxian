;; Deprecated in favor of cxd-treasury.clar
(define-read-only (get-allocation-percentages)
  (ok {
    lp: u6000,
    treasury: u2000,
    insurance: u2000
  })
)
