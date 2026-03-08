;; Standard RBAC Contract
(define-constant ROLE_ADMIN u1)
(define-map roles { user: principal, role: uint } bool)
(define-public (has-role (user principal) (role uint)) (ok (default-to false (map-get? roles { user: user, role: role }))))
(define-public (grant-role (user principal) (role uint)) (begin (map-set roles { user: user, role: role } true) (ok true)))
