;; core-traits.clar
(define-trait conxian-access-trait (
  (has-role (principal uint) (response bool uint))
  (grant-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint))
  (revoke-role (principal uint (buff 32) (buff 64) (buff 33)) (response bool uint))
  (verify-passkey-signature ({hash: (buff 32)  sig: (buff 64)  key: (buff 33)}) (response bool uint))
))
(define-trait regulatory-adapter-trait (
  (check-clean-hands-compliance (principal) (response bool uint))
))
