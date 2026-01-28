;; conxian-protocol.clar
;; Core Facade for Conxian Protocol
;; Manages global state, pausing, and module registry

;; Traits
(use-trait compliance-trait .compliance-trait.compliance-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))
(define-constant ERR_MODULE_EXISTS (err u1002))
(define-constant ERR_MODULE_NOT_FOUND (err u1003))

(define-constant ROLE_EMERGENCY u3)
(define-constant ROLE_PROTOCOL_ADMIN u2)

;; Data Vars
(define-data-var paused bool false)
(define-data-var contract-owner principal deployer)

;; Maps
(define-map modules
  { name: (string-ascii 32) }
  {
    contract: principal,
    active: bool,
  }
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Administrative Functions

(define-public (set-paused (admin-facade <rbac-trait>) (new-paused bool))
  (begin
    (asserts! (unwrap! (contract-call? admin-facade is-authorized-to-pause tx-sender) ERR_UNAUTHORIZED)
      ERR_UNAUTHORIZED
    )
    (var-set paused new-paused)
    (print {
      event: "protocol-pause-status",
      paused: new-paused,
      sender: tx-sender,
    })
    (ok true)
  )
)

(define-public (batch-register-modules (admin-facade <rbac-trait>) (modules-list (list 20 { name: (string-ascii 32), contract: principal })))
  (begin
    (asserts! (unwrap! (contract-call? admin-facade is-authorized ROLE_PROTOCOL_ADMIN) ERR_UNAUTHORIZED) ERR_UNAUTHORIZED)
    (fold (lambda (module-data accumulator)
      (begin
        (map-set modules { name: (get name module-data) } { contract: (get contract module-data), active: true })
        (ok true)
      )
    ) modules-list (ok true))
  )
)

(define-public (register-module (admin-facade <rbac-trait>)
    (name (string-ascii 32))
    (contract principal)
  )
  (begin
    (asserts!
      (unwrap! (contract-call? admin-facade is-authorized
        ROLE_PROTOCOL_ADMIN
      ) ERR_UNAUTHORIZED)
      ERR_UNAUTHORIZED
    )
    (map-set modules { name: name } {
      contract: contract,
      active: true,
    })
    (ok true)
  )
)

(define-public (set-module-active (admin-facade <rbac-trait>)
    (name (string-ascii 32))
    (active bool)
  )
  (let ((module (unwrap! (map-get? modules { name: name }) ERR_MODULE_NOT_FOUND)))
    (begin
      (asserts!
        (unwrap! (contract-call? admin-facade is-authorized
          ROLE_PROTOCOL_ADMIN
        ) ERR_UNAUTHORIZED)
        ERR_UNAUTHORIZED
      )
      (map-set modules { name: name } (merge module { active: active }))
      (ok true)
    )
  )
)

(define-public (batch-set-module-active (admin-facade <rbac-trait>) (updates (list 20 { name: (string-ascii 32), active: bool })))
  (begin
    (asserts! (unwrap! (contract-call? admin-facade is-authorized ROLE_PROTOCOL_ADMIN) ERR_UNAUTHORIZED) ERR_UNAUTHORIZED)
    (fold (lambda (update accumulator)
      (let ((module (unwrap! (map-get? modules { name: (get name update) }) ERR_MODULE_NOT_FOUND)))
        (begin
          (map-set modules { name: (get name update) } (merge module { active: (get active update) }))
          (ok true)
        )
      )
    ) updates (ok true))
  )
)

(define-public (set-contract-owner (admin-facade <rbac-trait>) (new-owner principal))
  (begin
    (asserts! (contract-call? admin-facade is-global-admin)
      ERR_UNAUTHORIZED
    )
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read Only

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-admin)
  (ok (var-get contract-owner))
)

(define-read-only (is-contract-owner (principal principal))
  (is-eq principal (var-get contract-owner))
)

(define-read-only (get-protocol-admin)
  (var-get contract-owner)
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-module (name (string-ascii 32)))
  (map-get? modules { name: name })
)

(define-read-only (get-protocol-status (block-utils principal) (regulatory-adapter <compliance-trait>))
  (ok {
    paused: (var-get paused),
    tenure-id: (contract-call? block-utils get-current-tenure-id),
    compliant: (is-ok (contract-call? regulatory-adapter check-clean-hands-compliance tx-sender))
  })
)