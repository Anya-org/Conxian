;; gamification-manager.clar
;; User Engagement & XP System for Governance
;; Tracks user activity and awards XP

(define-constant ERR_UNAUTHORIZED (err u1000))

;; Data Storage
(define-map user-xp
    principal
    uint
)

(define-data-var admin principal tx-sender)

;; Read Only
(define-read-only (get-user-xp (user principal))
    (default-to u0 (map-get? user-xp user))
)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

;; Admin Functions
(define-public (award-xp (user principal) (amount uint))
    (let (
        (current-xp (get-user-xp user))
        (new-xp (+ current-xp amount))
    )
        (asserts! (is-admin) ERR_UNAUTHORIZED)
        (map-set user-xp user new-xp)
        (print { event: "xp-awarded", user: user, amount: amount, total: new-xp })
        (ok new-xp)
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin) ERR_UNAUTHORIZED)
        (var-set admin new-admin)
        (ok true)
    )
)
