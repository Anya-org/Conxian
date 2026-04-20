;; core-traits.clar
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-trait regulatory-adapter-trait (
  (check-clean-hands-compliance (principal) (response bool uint))
))

(define-trait ownable-trait (
  (get-owner () (response principal uint))
  (set-owner (principal) (response bool uint))
))

(define-trait conxian-access-trait (
  (has-role (principal uint) (response bool uint))
  (grant-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint))
  (revoke-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint))
  (verify-passkey-signature ((buff 32) (buff 64) (buff 33)) (response bool uint))
))

(define-trait protocol-orchestrator-trait (
  (is-paused () (response bool uint))
  (get-protocol-admin () (response principal uint))
))

(define-trait position-orchestrator-trait (
  (open-position (principal principal uint uint bool) (response uint uint))
  (close-position (principal uint) (response bool uint))
  (liquidate-position (principal uint) (response bool uint))
))

(define-trait collateral-orchestrator-trait (
  (deposit-funds (uint <sip-010-ft-trait>) (response bool uint))
  (withdraw-funds (uint <sip-010-ft-trait>) (response bool uint))
  (add-collateral (principal principal uint) (response bool uint))
  (remove-collateral (principal principal uint) (response bool uint))
))

(define-trait risk-unit-trait (
  (get-health-factor (uint) (response uint uint))
  (is-liquidatable (uint) (response bool uint))
  (liquidate (uint) (response bool uint))
))

(define-trait funding-rate-trait (
  (update-funding-rate (principal) (response bool uint))
  (apply-funding (principal uint) (response bool uint))
))
