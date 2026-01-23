;; rbac.clar
;; Role-Based Access Control Module
;; Centralized access control for Conxian Protocol

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ROLE_EXISTS (err u1001))
(define-constant ERR_ROLE_NOT_FOUND (err u1002))

;; Role Definitions
(define-constant ROLE_OWNER u0) ;; Super admin
(define-constant ROLE_GOVERNANCE u1) ;; DAO / Voting
(define-constant ROLE_PROTOCOL u2) ;; Protocol automated actions
(define-constant ROLE_EMERGENCY u3) ;; Pause/Unpause
(define-constant ROLE_OPERATIONAL u4) ;; Daily ops

;; Data Maps
(define-map roles
    {
        user: principal,
        role-id: uint,
    }
    bool
)

;; Authorization Check
(define-read-only (has-role
        (user principal)
        (role-id uint)
    )
    (default-to false
        (map-get? roles {
            user: user,
            role-id: role-id,
        })
    )
)

(define-read-only (is-authorized
        (user principal)
        (role-id uint)
    )
    (if (or (is-eq user (var-get contract-owner)) (has-role user role-id))
        true
        false
    )
)

;; Owner Management
(define-data-var contract-owner principal tx-sender)

(define-read-only (get-owner)
    (var-get contract-owner)
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; Role Management
(define-public (grant-role
        (user principal)
        (role-id uint)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set roles {
            user: user,
            role-id: role-id,
        }
            true
        )
        (ok true)
    )
)

(define-public (revoke-role
        (user principal)
        (role-id uint)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-delete roles {
            user: user,
            role-id: role-id,
        })
        (ok true)
    )
)