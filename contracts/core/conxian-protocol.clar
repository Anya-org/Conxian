;; conxian-protocol.clar
;; Core Facade for Conxian Protocol
;; Manages global state, pausing, and module registry

;; Traits
(use-trait compliance-trait .compliance-trait.compliance-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))
(define-constant ERR_MODULE_EXISTS (err u1002))
(define-constant ERR_MODULE_NOT_FOUND (err u1003))

;; Data Vars
(define-data-var paused bool false)
(define-data-var protocol-admin principal tx-sender)

;; Maps
(define-map modules
    { name: (string-ascii 32) }
    {
        contract: principal,
        active: bool,
    }
)

;; Authorization
(define-read-only (is-contract-owner)
    (is-eq tx-sender (var-get protocol-admin))
)

;; Administrative Functions

(define-constant ROLE_EMERGENCY u3)

;; @desc Pauses the protocol globally
;; @param new-paused bool
;; @returns (response bool uint)
(define-public (set-paused (new-paused bool))
    (begin
        (asserts!
            (or (is-contract-owner) (contract-call? .rbac has-role tx-sender ROLE_EMERGENCY))
            ERR_UNAUTHORIZED
        )
        (var-set paused new-paused)
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
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (map-set modules { name: name } {
            contract: contract,
            active: true,
        })
        (ok true)
    )
)

;; @desc update module status
(define-public (set-module-active
        (name (string-ascii 32))
        (active bool)
    )
    (let ((module (unwrap! (map-get? modules { name: name }) ERR_MODULE_NOT_FOUND)))
        (begin
            (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
            (map-set modules { name: name } (merge module { active: active }))
            (ok true)
        )
    )
)

;; Read Only

(define-read-only (is-paused)
    (var-get paused)
)

(define-read-only (get-module (name (string-ascii 32)))
    (map-get? modules { name: name })
)