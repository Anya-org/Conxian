;; conxian-protocol.clar
;; Core Facade for Conxian Protocol
;; Forced Clarity 4 Standard (Jan 2026 Edition) - COMPATIBILITY MODE

(impl-trait .core-traits.protocol-manager-trait)

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
    hash: (optional (buff 32))
  }
)

;; Authorization
(define-read-only (get-protocol-admin)
  (ok (var-get contract-owner))
)

;; Administrative Functions

;; @desc Pauses or unpauses all state-changing protocol functions.
;; @param new-paused bool - The new pause status.
;; @returns (response bool uint)
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (contract-call? .admin-facade is-authorized-to-pause tx-sender) (err ERR_UNAUTHORIZED))
    (var-set paused new-paused)
    (print { event: "protocol-pause-status", paused: new-paused, timestamp: stacks-block-time })
    (ok true)
  )
)

;; @desc Convenience function to pause the protocol.
;; @returns (response bool uint)
(define-public (pause)
  (set-paused true)
)

;; @desc Registers a new module contract in the protocol registry.
;; @param name (string-ascii 32) - The unique name of the module.
;; @param contract principal - The address of the module contract.
;; @returns (response bool uint)
(define-public (register-module (name (string-ascii 32)) (contract principal))
  (begin
    (asserts! (unwrap! (contract-call? .admin-facade is-authorized ROLE_ADMIN) (err ERR_UNAUTHORIZED)) (err ERR_UNAUTHORIZED))
    ;; Native Clarity 4 contract-hash? validation
    (let ((c-hash (contract-hash? contract)))
      (map-set modules { name: name } {
        contract: contract,
        active: true,
        hash: c-hash
      })
      (print { event: "module-registered", name: name, contract: contract, hash: c-hash, timestamp: stacks-block-time })
      (ok true)
    )
  )
)

;; @desc Registers multiple module contracts in a single batch transaction.
;; @param entries (list 50 {name: (string-ascii 32), contract: principal}) - List of module entries.
;; @returns (response bool uint)
(define-public (batch-register-modules (entries (list 50 {name: (string-ascii 32), contract: principal})))
  (begin
    (asserts! (contract-call? .admin-facade is-global-admin) (err ERR_UNAUTHORIZED))
    (ok (fold register-module-iter entries true))
  )
)

(define-private (register-module-iter (entry {name: (string-ascii 32), contract: principal}) (previous bool))
  (begin
    ;; Native Clarity 4 contract-hash? validation
    (map-set modules { name: (get name entry) } {
      contract: (get contract entry),
      active: true,
      hash: (contract-hash? (get contract entry))
    })
    true
  )
)

;; @desc Updates the activation status for multiple modules in a single batch.
;; @param entries (list 50 {name: (string-ascii 32), active: bool}) - List of module activation updates.
;; @returns (response bool uint)
(define-public (batch-set-module-active (entries (list 50 {name: (string-ascii 32), active: bool})))
  (begin
    (asserts! (contract-call? .admin-facade is-global-admin) (err ERR_UNAUTHORIZED))
    (ok (fold set-module-active-iter entries true))
  )
)

(define-private (set-module-active-iter (entry {name: (string-ascii 32), active: bool}) (previous bool))
  (match (map-get? modules { name: (get name entry) })
    current (begin
      (map-set modules { name: (get name entry) } {
        contract: (get contract current),
        active: (get active entry),
        hash: (get hash current)
      })
      true
    )
    false
  )
)

;; @desc Transfers ownership of the protocol coordinator to a new address.
;; @param new-owner principal - The address of the new owner.
;; @returns (response bool uint)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (contract-call? .admin-facade is-global-admin) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read Only

;; @desc Returns the current owner of the protocol.
;; @returns (response principal uint)
(define-read-only (get-admin)
  (ok (var-get contract-owner))
)

;; @desc Returns the current pause status of the protocol.
;; @returns (response bool uint)
(define-read-only (is-paused)
  (ok (var-get paused)))

;; @desc Retrieves the address and status of a registered module.
;; @param name (string-ascii 32) - The name of the module.
;; @returns (optional {contract: principal, active: bool, hash: (optional (buff 32))})
(define-read-only (get-module (name (string-ascii 32)))
  (map-get? modules { name: name })
)

;; @desc Returns a comprehensive status report of the protocol.
;; @returns (response {paused: bool, tenure-id: (optional uint), compliant: bool, version: (string-ascii 2), timestamp: uint} uint)
(define-read-only (get-protocol-status)
  (ok {
    paused: (var-get paused),
    tenure-id: (some (contract-call? .block-utils get-current-tenure-id)),
    compliant: true,
    version: "C4",
    timestamp: stacks-block-time
  })
)
