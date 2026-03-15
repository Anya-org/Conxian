;; gamification-manager.clar
;; Conxian Protocol Standard Contract

;; gamification-manager.clar
;; User Engagement & XP System for Governance
;; Tracks user activity and awards XP

(define-constant ERR_UNAUTHORIZED u1000)

;; Data Storage
(define-map user-xp
    principal
    uint
)

(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

;; Read Only
(define-read-only (get-user-xp (user principal))
    (default-to u0 (map-get? user-xp user))
)

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

;; Admin Functions

;; @desc Award xp
;; @returns (response bool uint)
(define-public (award-xp (user principal) (amount uint))
    (let (
        (current-xp (get-user-xp user))
        (new-xp (+ current-xp amount))
    )
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (map-set user-xp user new-xp)
        (print { event: "xp-awarded" user: user amount: amount total: new-xp })
        (ok new-xp)
    )
)


;; @desc Set admin
;; @returns (response bool uint)
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set admin new-admin)
        (ok true)
    )
)
