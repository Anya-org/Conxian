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

;; Data Vars
(define-data-var paused bool false)
(define-data-var contract-owner principal tx-sender) ;; Replaces protocol-admin
(define-data-var access-control principal .conxian-access)
(define-data-var admin-facade-contract principal .admin-facade)

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

;; @desc Pauses the protocol globally
;; @param new-paused bool
;; @returns (response bool uint)
(define-public (set-paused (new-paused bool))
  (begin
    ;; Use centralized admin facade for ultra-low gas authorization
    (asserts!
      (or
        (contract-call? (var-get admin-facade-contract) is-global-admin)
(contract-call? (var-get admin-facade-contract) has-role tx-sender
          ROLE_EMERGENCY_PAUSE
        )
      )
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

;; @desc registers a new module
;; @param name (string-ascii 32)
;; @param contract principal
;; @returns (response bool uint)
(define-public (register-module
    (name (string-ascii 32))
    (contract principal)
  )
  (begin
    (asserts!
      (contract-call? (var-get admin-facade-contract) has-role tx-sender
        ROLE_PROTOCOL_ADMIN
      )
      ERR_UNAUTHORIZED
    )
    (map-set modules { name: name } {
      contract: contract,
      active: true,
    })
    (ok true)
  )
)

;; @desc update module status
;; @param name (string-ascii 32)
;; @param active bool
;; @returns (response bool uint)
(define-public (set-module-active
    (name (string-ascii 32))
    (active bool)
  )
  (let ((module (unwrap! (map-get? modules { name: name }) ERR_MODULE_NOT_FOUND)))
    (begin
      (asserts!
        (contract-call? (var-get admin-facade-contract) has-role tx-sender
          ROLE_PROTOCOL_ADMIN
        )
        ERR_UNAUTHORIZED
      )
      (map-set modules { name: name } (merge module { active: active }))
      (ok true)
    )
  )
)

;; Admin Handover
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (contract-call? (var-get admin-facade-contract) is-global-admin)
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

;; @desc Gets the global pause status and the current Nakamoto tenure ID in a single call.
;; @returns (response { paused: bool, tenure-id: (optional (buff 32)) } uint)
(define-read-only (get-protocol-status)
  (ok {
    paused: (var-get paused),
    tenure-id: (contract-call? .block-utils get-current-tenure-id),
  })
)
