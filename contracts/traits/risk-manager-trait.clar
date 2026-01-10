;; risk-manager-trait.clar
;; Centralized trait for risk management

(define-trait risk-manager-trait
  (
    (get-health-factor (uint) (response uint uint))
    (update-position-health (uint uint uint principal) (response uint uint))
    (liquidate (uint) (response bool uint))
    (set-asset-collateral-factor (principal uint uint) (response bool uint))
    (get-asset-factor (principal) (response uint uint))
    (get-global-collateral-factor () (response uint uint))
    (is-liquidatable (uint) (response bool uint))
  )
)
