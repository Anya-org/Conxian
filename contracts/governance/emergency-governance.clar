;; emergency-governance.clar
;; "Break Glass" Emergency Protocol
;; Allows specific roles to pause the protocol in crisis

(use-trait pausable-trait .pausable-trait.pausable-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ACTION_PAUSE_PROTOCOL u1)
(define-constant ACTION_UNPAUSE_PROTOCOL u2)

;; Data Vars
(define-data-var emergency-admin principal tx-sender)

;; Authorization
(define-read-only (is-emergency-admin)
    (is-eq tx-sender (var-get emergency-admin))
)


;; @desc Updates the emergency admin principal.
;; @param new-admin: The new admin principal.
;; @return (response bool uint)
(define-public (set-emergency-admin (new-admin principal))
    (begin
        (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
        (var-set emergency-admin new-admin)
        (ok true)
    )
)

;; Emergency Actions

;; @desc Activates emergency pause on a target contract.
;; @param contract: The contract implementing the pausable-trait.
;; @return (response bool uint)
(define-public (activate-emergency-pause (contract <pausable-trait>))
    (begin
        (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
        (contract-call? contract set-paused true)
    )
)


;; @desc Deactivates emergency pause on a target contract.
;; @param contract: The contract implementing the pausable-trait.
;; @return (response bool uint)
(define-public (deactivate-emergency-pause (contract <pausable-trait>))
    (begin
        (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
        (contract-call? contract set-paused false)
    )
)

;; Global Circuit Breaker (Signal only)
(define-data-var global-circuit-breaker bool false)

;; @desc Returns whether the global circuit breaker is active.
;; @return (response bool uint)
(define-read-only (is-circuit-breaker-active)
    (ok (var-get global-circuit-breaker))
)


;; @desc Manually triggers the global circuit breaker.
;; @return (response bool uint)
(define-public (trigger-circuit-breaker)
    (begin
        (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
        (var-set global-circuit-breaker true)
        (print { event: "circuit-breaker-triggered", sender: tx-sender })
        (ok true)
    )
)


;; @desc Resets the global circuit breaker.
;; @return (response bool uint)
(define-public (reset-circuit-breaker)
    (begin
        (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
        (var-set global-circuit-breaker false)
        (print { event: "circuit-breaker-reset", sender: tx-sender })
        (ok true)
    )
)
