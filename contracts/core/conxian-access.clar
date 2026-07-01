;; conxian-access.clar
;; Conxian Protocol: Core Role-Based Access Control (RBAC)
;; Aligned with Apex CSF (v1.1.0) and Nakamoto Standard.

(impl-trait .core-traits.conxian-access-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PASSKEY_NOT_SUPPORTED (err u1001))

(define-constant ROLE_ADMIN u1)
(define-constant ROLE_OPERATOR u2)
(define-constant ROLE_AGENT u3)

;; --- State ---
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)
(define-data-var timelock-principal principal tx-sender)

(define-map roles { user: principal, role: uint } bool)

;; --- Internal ---

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Public ---

(define-public (initialize (new-owner principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (var-set initialized true)
    ;; Grant admin role to owner
    (map-set roles { user: new-owner, role: ROLE_ADMIN } true)
    (ok true)
  )
)

(define-public (has-role (user principal) (role uint))
  (ok (or
    (is-eq user (var-get contract-owner))
    (default-to false (map-get? roles { user: user, role: role }))
  ))
)

(define-public (grant-role (user principal) (role uint) (msg (buff 32)) (sig (buff 64)) (pub (buff 33)))
  (begin
    (asserts! (unwrap-panic (has-role tx-sender ROLE_ADMIN)) ERR_UNAUTHORIZED)
    (map-set roles { user: user, role: role } true)
    (ok true)
  )
)

(define-public (revoke-role (user principal) (role uint) (msg (buff 32)) (sig (buff 64)) (pub (buff 33)))
  (begin
    (asserts! (unwrap-panic (has-role tx-sender ROLE_ADMIN)) ERR_UNAUTHORIZED)
    (map-delete roles { user: user, role: role })
    (ok true)
  )
)

(define-public (verify-passkey-signature (msg (buff 32)) (sig (buff 64)) (pub (buff 33)))
  (err u1001)
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-contract-owner) (ok (var-get contract-owner)))
(define-read-only (is-global-admin)
  (is-eq tx-sender (var-get contract-owner))
)
