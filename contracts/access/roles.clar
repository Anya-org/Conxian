;; roles.clar
;; Role Based Access Control (RBAC) System for Conxian
;; Centralized role management for the entire protocol

;; Constants
(define-constant OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ROLE_EXISTS (err u1001))
(define-constant ERR_ROLE_NOT_FOUND (err u1002))

;; Role Definitions
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_GOVERNANCE u2)
(define-constant ROLE_EMERGENCY u3)
(define-constant ROLE_OPERATOR u4)
(define-constant ROLE_ORACLE u5)
(define-constant ROLE_KEEPER u6)

;; Data Maps
(define-map roles 
    { user: principal, role: uint } 
    bool
)

;; Authorization Check
(define-read-only (has-role (user principal) (role-id uint))
    (default-to false (map-get? roles { user: user, role: role-id }))
)

(define-read-only (is-admin (user principal))
    (or (is-eq user OWNER) (has-role user ROLE_ADMIN))
)

;; Role Management
(define-public (grant-role (user principal) (role-id uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-set roles { user: user, role: role-id } true)
        (ok true)
    )
)

(define-public (revoke-role (user principal) (role-id uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-delete roles { user: user, role: role-id })
        (ok true)
    )
)
