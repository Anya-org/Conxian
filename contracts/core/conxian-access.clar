;; conxian-access.clar
;; Unified Role-Based Access Control (RBAC) Backend
;; Centralizes all permissioning for the Conxian Protocol
;; Dual-Mode: Compatibility and Clarity 4

(impl-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ROLE_EXISTS u1001)
(define-constant ERR_ROLE_NOT_FOUND u1002)
(define-constant ERR_INVALID_SIGNATURE u1003)

;; Roles
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_GOVERNANCE u2)
(define-constant ROLE_EMERGENCY u3)
(define-constant ROLE_OPERATOR u4)
(define-constant ROLE_KEEPER u5)

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var timelock-principal principal tx-sender)
(define-map roles
  {
    user: principal,
    role: uint,
  }
  bool
)

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin (user principal))
  (or (is-eq user (var-get contract-owner)) (default-to false (map-get? roles {
    user: user,
    role: ROLE_ADMIN,
  })
  ))
)

;; Trait Implementation
(define-public (has-role
    (user principal)
    (role-id uint)
  )
  (ok (default-to false (map-get? roles {
    user: user,
    role: role-id,
  })
  ))
)

(define-public (grant-role
    (user principal)
    (role-id uint)
    (message (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
  )
  (begin
    (asserts! (is-admin tx-sender) (err ERR_UNAUTHORIZED))
    ;; Verify signature for sensitive role changes (Safe Wrapper)
    (asserts! (secp256r1-verify message signature public-key) (err ERR_INVALID_SIGNATURE))
    (map-set roles {
      user: user,
      role: role-id,
    } true
    )
    (ok true)
  )
)

(define-public (revoke-role
    (user principal)
    (role-id uint)
    (message (buff 32))
    (signature (buff 64))
    (public-key (buff 33))
  )
  (begin
    (asserts! (is-admin tx-sender) (err ERR_UNAUTHORIZED))
    ;; Verify signature for sensitive role changes (Safe Wrapper)
    (asserts! (secp256r1-verify message signature public-key) (err ERR_INVALID_SIGNATURE))
    (map-delete roles {
      user: user,
      role: role-id,
    })
    (ok true)
  )
)

;; Admin
(define-public (set-contract-owner (new-owner principal) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (secp256r1-verify message signature public-key) (err ERR_INVALID_SIGNATURE))
    (var-set contract-owner new-owner)
    (print {
      event: "owner-changed",
      old-owner: tx-sender,
      new-owner: new-owner,
      timestamp: block-height
    })
    (ok true)
  )
)

;; Sovereign Handoff: Transfer ownership to timelock
(define-public (transfer-ownership-to-timelock (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (secp256r1-verify message signature public-key) (err ERR_INVALID_SIGNATURE))
    (var-set contract-owner (var-get timelock-principal))
    (print {
      event: "sovereign-handoff",
      module: "conxian-access",
      new-owner: (var-get timelock-principal),
      timestamp: block-height
    })
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Read-only: Verify Passkey/Biometric Signature (Safe Wrapper)
(define-read-only (verify-passkey-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

;; Read-only: Global Admin Check
(define-read-only (is-global-admin)
  (is-admin tx-sender)
)

(define-public (set-timelock-principal (new-timelock principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set timelock-principal new-timelock)
    (ok true)
  )
)
