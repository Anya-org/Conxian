;; lending-manager-trait.clar
;;
;; This trait defines the standard interface for a lending manager contract.
;; It outlines the core functionalities required for managing lending and
;; borrowing operations, which will be implemented by the lending-manager
;; contract and called by the lending facade.

(use-trait ft-trait .sip-standards.sip-010-ft-trait)

(define-trait lending-manager-trait
  (
    ;; Public Functions
    (supply (<ft-trait> uint) (response bool uint))
    (withdraw (<ft-trait> uint) (response bool uint))
    (borrow (<ft-trait> uint) (response bool uint))
    (repay (<ft-trait> uint) (response bool uint))

    ;; Read-Only Functions
    (get-user-borrow-balance (principal principal) (response (optional uint) uint))
    (get-user-supply-balance (principal principal) (response (optional uint) uint))
  )
)
