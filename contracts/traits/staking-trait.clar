;; staking-trait.clar
;; Minimal staking interface used by monitors and distributors

(define-trait staking-trait
  (
    ;; Returns key staking protocol statistics in a single call
    ;; Tuple keys chosen to align with existing consumers in the codebase
    (get-protocol-info () (response (tuple (total-supply uint)
                                          (total-staked-cxd uint)
                                          (total-revenue-distributed uint)
                                          (current-epoch uint)) uint))

    ;; Optional distribution entrypoint some systems may expect
    ;; Kept generic and trait-typed to avoid concrete token coupling
    (distribute-revenue (uint <sip-010-trait>) (response bool uint))
  )
)
