;; autonomous-registry.clar
;; @desc Autonomous Module Registry for CSF Autonomous Launch
;; @dev Manages registration, activation, and lifecycle of autonomous protocol modules
;; @dev Part of CSF Autonomous Launch (CON-???)
;; @constant ERR_UNAUTHORIZED Error code for unauthorized access
;; @constant ERR_MODULE_NOT_FOUND Error code for module not found
;; @constant ERR_MODULE_ALREADY_REGISTERED Error code for module already registered
;; @constant ERR_INVALID_STATE Transition Error code for invalid state transition

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_MODULE_NOT_FOUND (err u1001))
(define-constant ERR_MODULE_ALREADY_REGISTERED (err u1002))
(define-constant ERR_INVALID_STATE (err u1003))
(define-constant ERR_NOT_SELF_GOVERNED (err u1004))

;; Module States
(define-constant STATE_PROPOSED u0)
(define-constant STATE_APPROVED u1)
(define-constant STATE_ACTIVE u2)
(define-constant STATE_SUSPENDED u3)
(define-constant STATE_DEPRECATED u4)

;; Module Types
(define-constant TYPE_CORE u0)
(define-constant TYPE_AGENT u1)
(define-constant TYPE_ORACLE u2)
(define-constant TYPE_TREASURY u3)
(define-constant TYPE_GOVERNANCE u4)
(define-constant TYPE_EXTERNAL u5)

;; Admin (initialized to tx-sender, configurable via governance)
(define-data-var admin principal tx-sender)
(define-data-var governance principal tx-sender)

;; Module Registry
(define-map module-registry
    principal
    {
        name: (string-ascii 64),
        version: (string-ascii 16),
        module-type: uint,
        state: uint,
        self-governed: bool,
        activation-block: uint,
        metadata-hash: (buff 32)
    }
)

;; Module Dependencies (module -> list of dependent modules)
(define-map module-dependencies
    principal
    (list 100 principal)
)

;; Active Module Count by Type
(define-map module-count-by-type
    uint
    uint
)

;; Read-only Functions

;; @desc Get module info
(define-read-only (get-module-info (module principal))
    (ok (map-get? module-registry module))
)

;; @desc Get module state
(define-read-only (get-module-state (module principal))
    (match (map-get? module-registry module)
        info (ok (get state info))
        (err ERR_MODULE_NOT_FOUND)
    )
)

;; @desc Check if module is active
(define-read-only (is-module-active (module principal))
    (match (map-get? module-registry module)
        info (is-eq (get state info) STATE_ACTIVE)
        (err false)
    )
)

;; @desc Get all active modules of a given type
(define-read-only (get-active-modules-by-type (module-type uint))
    (ok (map-get? module-count-by-type module-type))
)

;; @desc Check if a module can transition to a new state
(define-read-only (can-transition-state (current-state uint) (new-state uint))
    (ok (and
        (< current-state STATE_DEPRECATED)
        (or
            (and (is-eq current-state STATE_PROPOSED) (is-eq new-state STATE_APPROVED))
            (and (is-eq current-state STATE_APPROVED) (is-eq new-state STATE_ACTIVE))
            (and (is-eq current-state STATE_ACTIVE) (is-eq new-state STATE_SUSPENDED))
            (and (is-eq current-state STATE_SUSPENDED) (is-eq new-state STATE_ACTIVE))
            (and (>= current-state STATE_APPROVED) (is-eq new-state STATE_DEPRECATED))
        )
    ))
)

;; Admin Functions

;; @desc Set admin
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set admin new-admin)
        (ok true)
    )
)

;; @desc Set governance
(define-public (set-governance (new-governance principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set governance new-governance)
        (ok true)
    )
)

;; Public Functions

;; @desc Register a new autonomous module
(define-public (register-module
    (module principal)
    (name (string-ascii 64))
    (version (string-ascii 16))
    (module-type uint)
    (self-governed bool)
    (metadata-hash (buff 32))
)
    (begin
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
        ) ERR_UNAUTHORIZED)

        (asserts! (is-none (map-get? module-registry module)) ERR_MODULE_ALREADY_REGISTERED)

        (map-set module-registry module {
            name: name,
            version: version,
            module-type: module-type,
            state: STATE_PROPOSED,
            self-governed: self-governed,
            activation-block: u0,
            metadata-hash: metadata-hash
        })

        (var-set module-count-by-type module-type
            (+ (default-to u0 (map-get? module-count-by-type module-type)) u1))

        (print { event: "module-registered", module: module, name: name, module-type: module-type })
        (ok true)
    )
)

;; @desc Approve a proposed module
(define-public (approve-module (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
        ) ERR_UNAUTHORIZED)

        (asserts! (is-eq (get state info) STATE_PROPOSED) ERR_INVALID_STATE)

        (map-set module-registry module (merge info { state: STATE_APPROVED }))

        (print { event: "module-approved", module: module })
        (ok true)
    )
)

;; @desc Activate an approved module
(define-public (activate-module (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
            (and (get self-governed info) (is-eq tx-sender module))
        ) ERR_UNAUTHORIZED)

        (asserts! (is-eq (get state info) STATE_APPROVED) ERR_INVALID_STATE)

        (map-set module-registry module (merge info {
            state: STATE_ACTIVE,
            activation-block: block-height
        }))

        (print { event: "module-activated", module: module })
        (ok true)
    )
)

;; @desc Suspend an active module
(define-public (suspend-module (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
            (and (get self-governed info) (is-eq tx-sender module))
        ) ERR_UNAUTHORIZED)

        (asserts! (is-eq (get state info) STATE_ACTIVE) ERR_INVALID_STATE)

        (map-set module-registry module (merge info { state: STATE_SUSPENDED }))

        (print { event: "module-suspended", module: module })
        (ok true)
    )
)

;; @desc Resume a suspended module
(define-public (resume-module (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
            (and (get self-governed info) (is-eq tx-sender module))
        ) ERR_UNAUTHORIZED)

        (asserts! (is-eq (get state info) STATE_SUSPENDED) ERR_INVALID_STATE)

        (map-set module-registry module (merge info { state: STATE_ACTIVE }))

        (print { event: "module-resumed", module: module })
        (ok true)
    )
)

;; @desc Deprecate a module (permanent)
(define-public (deprecate-module (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
        ) ERR_UNAUTHORIZED)

        (asserts! (>= (get state info) STATE_APPROVED) ERR_INVALID_STATE)

        (map-set module-registry module (merge info { state: STATE_DEPRECATED }))

        (var-set module-count-by-type (get module-type info)
            (- (default-to u0 (map-get? module-count-by-type (get module-type info))) u1))

        (print { event: "module-deprecated", module: module })
        (ok true)
    )
)

;; @desc Register module dependencies
(define-public (register-dependencies (module principal) (dependencies (list 100 principal)))
    (begin
        (asserts! (or
            (is-eq tx-sender (var-get admin))
            (is-eq tx-sender (var-get governance))
            (is-some (map-get? module-registry module))
        ) ERR_UNAUTHORIZED)

        (map-set module-dependencies module dependencies)
        (print { event: "dependencies-registered", module: module, count: (len dependencies) })
        (ok true)
    )
)

;; @desc Self-governed activation (for self-governed modules)
(define-public (self-activate (module principal))
    (let ((info (unwrap! (map-get? module-registry module) ERR_MODULE_NOT_FOUND)))
        (asserts! (and
            (get self-governed info)
            (is-eq tx-sender module)
            (is-eq (get state info) STATE_APPROVED)
        ) ERR_UNAUTHORIZED)

        (map-set module-registry module (merge info {
            state: STATE_ACTIVE,
            activation-block: block-height
        }))

        (print { event: "module-self-activated", module: module })
        (ok true)
    )
)

;; @desc Get contract info
(define-read-only (get-contract-info)
    (ok {
        admin: (var-get admin),
        governance: (var-get governance),
        total-modules: (+ (+ (+ (+ (+ (default-to u0 (map-get? module-count-by-type TYPE_CORE))
            (default-to u0 (map-get? module-count-by-type TYPE_AGENT)))
            (default-to u0 (map-get? module-count-by-type TYPE_ORACLE)))
            (default-to u0 (map-get? module-count-by-type TYPE_TREASURY)))
            (default-to u0 (map-get? module-count-by-type TYPE_GOVERNANCE)))
            (default-to u0 (map-get? module-count-by-type TYPE_EXTERNAL)))
    })
)
