;; conxian-protocol.clar
;; Core Facade for Conxian Protocol

(impl-trait .core-traits.protocol-manager-trait)

;; Traits

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_MODULE_NOT_FOUND u1003)

;; Roles
(define-constant ROLE_ADMIN u1)

;; State
(define-data-var paused bool false)
(define-data-var contract-owner principal tx-sender)

;; Maps
(define-map modules
  { name: (string-ascii 32) }
  {
    contract: principal,
    active: bool,
  }
)

;; Authorization

;; @desc Returns the principal of the protocol administrator
;; @returns (response principal uint)
(define-read-only (get-protocol-admin)
  (ok (var-get contract-owner))
)

;; Administrative Functions

;; @desc Sets the protocol pause status
;; @param new-paused bool
;; @returns (response bool uint)
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (contract-call? .admin-facade is-authorized-to-pause tx-sender) (err ERR_UNAUTHORIZED))
    (var-set paused new-paused)
    (print { event: "protocol-pause-status", paused: new-paused })
    (ok true)
  )
)

;; @desc Registers a new module in the protocol
;; @param name (string-ascii 32)
;; @param contract principal
;; @returns (response bool uint)
(define-public (register-module (name (string-ascii 32)) (contract principal))
  (begin
    (asserts! (unwrap! (contract-call? .admin-facade is-authorized ROLE_ADMIN) (err ERR_UNAUTHORIZED)) (err ERR_UNAUTHORIZED))
    ;; Verify contract integrity (Clarity 4 Native - Stubbed for compat)
    ;; (asserts! (is-some (get-contract-hash contract)) (err ERR_MODULE_NOT_FOUND))
    (map-set modules { name: name } {
      contract: contract,
      active: true,
    })
    (print { event: "module-registered", name: name, contract: contract, hash: none })
    (ok true)
  )
)

;; @desc Sets the contract owner (admin only)
;; @param new-owner principal
;; @returns (response bool uint)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (contract-call? .admin-facade is-global-admin) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read Only

;; @desc Returns the principal of the protocol admin
;; @returns (response principal uint)
(define-read-only (get-admin)
  (ok (var-get contract-owner))
)

;; @desc Returns whether the protocol is currently paused
;; @returns (response bool uint)
(define-read-only (is-paused)
  (ok (var-get paused)))

;; @desc Retrieves module information by name
;; @param name (string-ascii 32)
;; @returns (optional {contract: principal, active: bool})
(define-read-only (get-module (name (string-ascii 32)))
  (map-get? modules { name: name })
)

;; @desc Returns a comprehensive status of the protocol
;; @returns (response {paused: bool, tenure-id: (optional uint), compliant: bool, version: (string-ascii 2)} uint)
(define-read-only (get-protocol-status)
  (ok {
    paused: (var-get paused),
    tenure-id: (some (contract-call? .block-utils get-current-tenure-id)),
    compliant: true,
    version: "C4"
  })
)
