;; core-traits.clar
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(define-trait regulatory-adapter-trait (
  (check-clean-hands-compliance (principal) (response bool uint))
))
(define-trait ownable-trait ((get-owner () (response principal uint)) (set-owner (principal) (response bool uint))))
(define-trait conxian-access-trait ((has-role (principal uint) (response bool uint)) (grant-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint)) (revoke-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint)) (verify-passkey-signature ((buff 32) (buff 64) (buff 33)) (response bool uint))))
(define-trait position-manager-trait ((open-position (principal principal uint uint bool) (response uint uint)) (close-position (principal uint) (response bool uint))))
(define-trait collateral-manager-trait ((deposit-funds (uint <sip-010-ft-trait>) (response bool uint)) (withdraw-funds (uint <sip-010-ft-trait>) (response bool uint))))
(define-trait risk-manager-trait ((get-health-factor (uint) (response uint uint)) (liquidate (uint) (response bool uint))))
(define-trait funding-rate-trait ((get-funding-rate (uint) (response uint uint))))
(define-trait protocol-manager-trait ((is-paused () (response bool uint)) (get-protocol-admin () (response principal uint))))
