;; reputation-engine-trait.clar
;; Defines the standard interface for a reputation and dynamic voting weight system.

(define-trait reputation-engine-trait
  (
    ;; @desc Retrieves the dynamically weighted voting power for a given principal.
    ;; @param principal: The user whose voting power is being queried.
    ;; @param balance: The user's current raw token balance.
    ;; @returns (response uint) The calculated, decayed voting power.
    (get-weighted-voting-power (principal principal) (balance uint) (response uint uint))

    ;; @desc Updates the activity score for a principal after a governance action.
    ;; @param principal: The user who performed the action.
    ;; @returns (response bool)
    (update-activity-score (principal principal) (response bool bool))
  )
)
