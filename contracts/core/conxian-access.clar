;; conxian-access.clar
;; Unified Role-Based Access Control (RBAC) Backend
;; Centralizes all permissioning for the Conxian Protocol

(impl-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ROLE_EXISTS (err u1001))
(define-constant ERR_ROLE_NOT_FOUND (err u1002))

;; Roles
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_GOVERNANCE u2)
(define-constant ROLE_EMERGENCY u3)
(define-constant ROLE_OPERATOR u4)
(define-constant ROLE_KEEPER u5)

;; State
(define-data-var contract-owner principal tx-sender)
(define-map roles { user: principal, role: uint } bool)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin (user principal))
    (or (is-eq user (var-get contract-owner)) (default-to false (map-get? roles { user: user, role: ROLE_ADMIN })))
)

;; Trait Implementation
(define-public (has-role (user principal) (role-id uint))
    (ok (default-to false (map-get? roles { user: user, role: role-id })))
)

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

;; Admin
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-read-only (get-contract-owner)
    (ok (var-get contract-owner))
)
