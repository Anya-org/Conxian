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

(define-trait protocol-manager-trait (
  (is-paused () (response bool uint))
  (get-protocol-admin () (response principal uint))
))
