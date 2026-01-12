;; emergency-governance.clar
;; "Break Glass" Emergency Protocol
;; Allows specific roles to pause the protocol in crisis

(use-trait pausable-trait .traits.pausable-trait .pausable-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ACTION_PAUSE_PROTOCOL u1)
(define-constant ACTION_UNPAUSE_PROTOCOL u2)

;; Data Vars
(define-data-var emergency-admin principal tx-sender)

;; Authorization
(define-read-only (is-emergency-admin)
    (is-eq tx-sender (var-get emergency-admin))
)

(define-public (set-emergency-admin (new-admin principal))
    (begin
        (asserts! (is-emergency-admin) ERR_UNAUTHORIZED)
        (var-set emergency-admin new-admin)
        (ok true)
    )
)

;; Emergency Actions
(define-public (activate-emergency-pause (contract <pausable-trait>))
    (begin
        (asserts! (is-emergency-admin) ERR_UNAUTHORIZED)
        (contract-call? contract set-paused true)
    )
)

(define-public (deactivate-emergency-pause (contract <pausable-trait>))
    (begin
        (asserts! (is-emergency-admin) ERR_UNAUTHORIZED)
        (contract-call? contract set-paused false)
    )
)

;; Global Circuit Breaker (Signal only)
(define-data-var global-circuit-breaker bool false)

(define-read-only (is-circuit-breaker-active)
    (ok (var-get global-circuit-breaker))
)

(define-public (trigger-circuit-breaker)
    (begin
        (asserts! (is-emergency-admin) ERR_UNAUTHORIZED)
        (var-set global-circuit-breaker true)
        (print { event: "circuit-breaker-triggered", sender: tx-sender })
        (ok true)
    )
)

(define-public (reset-circuit-breaker)
    (begin
        (asserts! (is-emergency-admin) ERR_UNAUTHORIZED)
        (var-set global-circuit-breaker false)
        (print { event: "circuit-breaker-reset", sender: tx-sender })
        (ok true)
    )
)
