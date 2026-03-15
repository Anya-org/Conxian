;; admin-facade.clar
;; Conxian Protocol Standard Contract

;; admin-facade.clar
;; Centralized Admin Facade for Gas Optimization

;; Traits
(use-trait rbac-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_NOT_AUTHORIZED u1000)

;; State
(define-data-var global-admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

(define-map role-cache { user: principal, role: uint } bool)

;; Authorization
(define-read-only (is-global-admin)
  (is-eq tx-sender (var-get global-admin))
)


;; @desc Is authorized
;; @returns (response bool uint)
(define-public (is-authorized (role uint))
  (ok (or (is-global-admin) (default-to false (map-get? role-cache { user: tx-sender, role: role }))))
)

(define-read-only (is-authorized-to-pause (sender principal))
  (or (is-eq sender (var-get global-admin))
      (default-to false (map-get? role-cache { user: sender, role: u1 })))
)


;; @desc Set role
;; @returns (response bool uint)
(define-public (set-role (user principal) (role uint) (enabled bool))
  (begin
    (asserts! (is-global-admin) (err ERR_NOT_AUTHORIZED))
    (if enabled
      (map-set role-cache { user: user, role: role } true)
      (map-delete role-cache { user: user, role: role })
    )
    (ok true)
  )
)


;; @desc Transfer global admin to timelock
;; @returns (response bool uint)
(define-public (transfer-global-admin-to-timelock)
  (begin
    (asserts! (is-global-admin) (err ERR_NOT_AUTHORIZED))
    (var-set global-admin .timelock)
    (ok true)
  )
)


;; @desc Initialize
;; @returns (response bool uint)
(define-public (initialize (admin principal))
  (begin
    (asserts! (is-eq tx-sender 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P) (err ERR_NOT_AUTHORIZED))
    (var-set global-admin admin)
    (ok true)
  )
)
