;; conxian-protocol.clar
;; Core Facade for Conxian Protocol
;; Dual-Mode: Compatibility and Clarity 4

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
(define-data-var admin-contract principal .admin-facade)

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
(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    paused: (var-get paused),
    tenure-id: (some (/ block-height u10)),
    timestamp: block-height,
    version: "06"
  })
)

(define-read-only (get-admin)
  (ok (var-get contract-owner))
)

(define-read-only (get-protocol-admin)
  (ok (var-get contract-owner))
)

;; Administrative Functions

;; @desc Pauses or unpauses all state-changing protocol functions.
;; @param new-paused bool - The new pause status.
;; @returns (response bool uint)
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (contract-call? admin-contract is-authorized-to-pause tx-sender)
      (err ERR_UNAUTHORIZED)
    )
    (var-set paused new-paused)
    (print { event: "protocol-pause-status", paused: new-paused, timestamp: block-height })
    (ok true)
  )
)

;; @desc Convenience function to pause the protocol.
;; @returns (response bool uint)
(define-public (pause)
  (begin
    (asserts! (contract-call? admin-contract is-authorized-to-pause tx-sender)
      (err ERR_UNAUTHORIZED)
    )
    (var-set paused true)
    (ok true)
  )
)

;; @desc Convenience function to unpause the protocol.
;; @returns (response bool uint)
(define-public (unpause)
  (begin
    (asserts! (contract-call? admin-contract is-authorized-to-pause tx-sender)
      (err ERR_UNAUTHORIZED)
    )
    (var-set paused false)
    (ok true)
  )
)

;; Module Management

;; @desc Registers a new module in the protocol.
;; @param name (string-ascii 32) - The unique name for the module.
;; @param contract principal - The contract address of the module.
;; @returns (response bool uint)
(define-public (register-module (name (string-ascii 32)) (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set modules { name: name } {
      contract: contract,
      active: true,
      hash: none ;; Removing invalid contract-hash? for now
    })
    (ok true)
  )
)

(define-read-only (get-module (name (string-ascii 32)))
  (map-get? modules { name: name })
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)


(define-read-only (get-protocol-owner)
  (var-get contract-owner)
)

;; @desc Update the admin contract principal (Principal Injection)
(define-public (set-admin-contract (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set admin-contract new-admin)
    (ok true)
  )
)