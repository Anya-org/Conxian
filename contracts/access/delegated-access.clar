;; delegated-access.clar
;; Advanced Access Control Patterns for Conxian Protocol
;;
;; Extends conxian-access RBAC with:
;;   - Time-bound access grants
;;   - Delegated authority with revocation
;;   - Emergency access escalation
;;   - Access expiry windows

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_GRANT_NOT_FOUND u1001)
(define-constant ERR_GRANT_EXPIRED u1002)
(define-constant ERR_GRANT_NOT_ACTIVE u1003)
(define-constant ERR_ALREADY_DELEGATED u1004)
(define-constant ERR_SELF_DELEGATE u1005)
(define-constant ERR_MAX_DELEGATES u1006)

(define-constant MAX_DELEGATES u10)
(define-constant MAX_GRANT_DURATION u100000) ;; ~5.8 days of blocks

;; --- State ---
(define-data-var admin principal tx-sender)

;; Time-bound access grants: (granter, grantee, role) → expiry-block
(define-map time-bound-grants
  { granter: principal, grantee: principal, role: uint }
  {
    granted-at: uint,
    expires-at: uint,
    active: bool
  }
)

;; Delegated authority: delegator → delegate (one level deep)
(define-map delegations
  principal
  {
    delegate: principal,
    since: uint,
    active: bool
  }
)

;; Emergency escalation window tracking
(define-map emergency-escalations
  principal
  {
    escalated-at: uint,
    expires-at: uint,
    reason: (string-ascii 64),
    active: bool
  }
)

(define-data-var emergency-window uint u1008) ;; ~1.4 days

;; --- Time-Bound Grants ---

;; @desc Grant time-bound access to a principal for a specific role.
;; The grant automatically expires after the specified duration.
;; @param grantee: The principal receiving the grant
;; @param role: The role ID to grant
;; @param duration: Duration in blocks before the grant expires
(define-public (grant-time-bound-access (grantee principal) (role uint) (duration uint))
  (begin
    (asserts! (not (is-eq tx-sender grantee)) (err ERR_SELF_DELEGATE))
    (asserts! (<= duration MAX_GRANT_DURATION) (err ERR_UNAUTHORIZED))
    (asserts! (contract-call? .conxian-access has-role tx-sender role) (err ERR_UNAUTHORIZED))

    (map-set time-bound-grants { granter: tx-sender, grantee: grantee, role: role } {
      granted-at: burn-block-height,
      expires-at: (+ burn-block-height duration),
      active: true
    })
    (print {
      event: "time-bound-grant-created",
      granter: tx-sender,
      grantee: grantee,
      role: role,
      expires-at: (+ burn-block-height duration)
    })
    (ok true)
  )
)

;; @desc Revoke an active time-bound grant
;; @param grantee: The principal whose grant is being revoked
;; @param role: The role ID
(define-public (revoke-time-bound-grant (grantee principal) (role uint))
  (let (
      (grant (unwrap! (map-get? time-bound-grants { granter: tx-sender, grantee: grantee, role: role })
        (err ERR_GRANT_NOT_FOUND)))
    )
    (begin
      (map-set time-bound-grants { granter: tx-sender, grantee: grantee, role: role }
        (merge grant { active: false }))
      (print {
        event: "time-bound-grant-revoked",
        granter: tx-sender,
        grantee: grantee,
        role: role
      })
      (ok true)
    )
  )
)

;; @desc Check if a time-bound grant is valid (not expired, still active)
(define-read-only (check-time-bound-grant (granter principal) (grantee principal) (role uint))
  (match (map-get? time-bound-grants { granter: granter, grantee: grantee, role: role })
    grant (and
      (get active grant)
      (< burn-block-height (get expires-at grant))
    )
    false
  )
)

;; --- Delegated Authority ---

;; @desc Delegate your authority to another principal.
;; Only one active delegation per delegator.
;; @param delegate: The principal receiving delegated authority
(define-public (delegate-authority (delegate principal))
  (let (
      (existing (map-get? delegations tx-sender))
    )
    (begin
      (asserts! (not (is-eq tx-sender delegate)) (err ERR_SELF_DELEGATE))
      (asserts! (or
        (is-none existing)
        (not (get active (unwrap-panic existing)))
      ) (err ERR_ALREADY_DELEGATED))

      (map-set delegations tx-sender {
        delegate: delegate,
        since: burn-block-height,
        active: true
      })
      (print {
        event: "authority-delegated",
        delegator: tx-sender,
        delegate: delegate
      })
      (ok true)
    )
  )
)

;; @desc Revoke your delegated authority
(define-public (revoke-delegation)
  (let (
      (existing (unwrap! (map-get? delegations tx-sender) (err ERR_GRANT_NOT_FOUND)))
    )
    (begin
      (map-set delegations tx-sender (merge existing { active: false }))
      (print { event: "delegation-revoked", delegator: tx-sender })
      (ok true)
    )
  )
)

;; @desc Get the active delegate for a principal
(define-read-only (get-delegate (principal principal))
  (match (map-get? delegations principal)
    delegation (if (get active delegation)
      (some (get delegate delegation))
      none
    )
    none
  )
)

;; --- Emergency Escalation ---

;; @desc Activate emergency escalation for the caller.
;; Grants temporary elevated access during crisis.
;; @param reason: Justification for the escalation
(define-public (activate-emergency-escalation (reason (string-ascii 64)))
  (begin
    (asserts! (or
      (contract-call? .conxian-access has-role tx-sender u2)
      (contract-call? .conxian-access has-role tx-sender u3)
    ) (err ERR_UNAUTHORIZED))

    (map-set emergency-escalations tx-sender {
      escalated-at: burn-block-height,
      expires-at: (+ burn-block-height (var-get emergency-window)),
      reason: reason,
      active: true
    })
    (print {
      event: "emergency-escalation-activated",
      principal: tx-sender,
      reason: reason,
      expires-at: (+ burn-block-height (var-get emergency-window))
    })
    (ok true)
  )
)

;; @desc Deactivate the caller's emergency escalation
(define-public (deactivate-emergency-escalation)
  (let (
      (esc (unwrap! (map-get? emergency-escalations tx-sender) (err ERR_GRANT_NOT_FOUND)))
    )
    (begin
      (map-set emergency-escalations tx-sender (merge esc { active: false }))
      (print { event: "emergency-escalation-deactivated", principal: tx-sender })
      (ok true)
    )
  )
)

;; @desc Check if a principal has an active emergency escalation
(define-read-only (is-emergency-escalated (principal principal))
  (match (map-get? emergency-escalations principal)
    esc (and
      (get active esc)
      (< burn-block-height (get expires-at esc))
    )
    false
  )
)

;; --- Admin ---

(define-public (set-emergency-window (blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (> blocks u0) (err ERR_UNAUTHORIZED))
    (var-set emergency-window blocks)
    (print { event: "emergency-window-updated", blocks: blocks })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (print { event: "delegated-access-admin-changed", new-admin: new-admin })
    (ok true)
  )
)
