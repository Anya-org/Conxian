;; audit-trail.clar
;; On-Chain Audit Trail & Compliance Registry
;;
;; Provides immutable audit logging for protocol state changes:
;;   - Administrative actions (owner changes, role grants)
;;   - Financial events (fee collection, treasury movements)
;;   - Security events (pause/unpause, circuit breaker)
;;   - Governance events (proposal creation, execution)
;;
;; Audit entries are append-only and never deleted.

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ENTRY_NOT_FOUND u1001)

;; Event categories
(define-constant CATEGORY_ADMIN u1)
(define-constant CATEGORY_FINANCIAL u2)
(define-constant CATEGORY_SECURITY u3)
(define-constant CATEGORY_GOVERNANCE u4)
(define-constant CATEGORY_TREASURY u5)
(define-constant CATEGORY_BRIDGE u6)
(define-constant CATEGORY_CONFIG u7)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var entry-count uint u0)

;; Audit trail: entry-id → immutable audit record
(define-map audit-entries
  uint
  {
    category: uint,
    actor: principal,
    action: (string-ascii 64),
    target: principal,
    details: (string-ascii 256),
    block: uint,
    timestamp: uint
  }
)

;; Category index for efficient queries
(define-map category-index
  { category: uint, entry-id: uint }
  bool
)

;; Actor index for accountability queries
(define-map actor-index
  { actor: principal, entry-id: uint }
  bool
)

;; --- Audit Logging ---

;; @desc Record an audit entry. Only authorized contracts may call.
;; @param category: The event category
;; @param actor: The principal performing the action
;; @param action: Human-readable action name
;; @param target: The target principal or contract
;; @param details: Additional context (max 256 chars)
(define-public (record-audit-entry
    (category uint)
    (actor principal)
    (action (string-ascii 64))
    (target principal)
    (details (string-ascii 256))
  )
  (let ((entry-id (+ (var-get entry-count) u1)))
    (begin
      ;; Only authorized contracts can write audit entries
      (asserts! (or
        (is-eq tx-sender (var-get admin))
        (is-eq tx-sender .conxian-protocol)
        (is-eq tx-sender .timelock)
        (is-eq tx-sender .operational-treasury)
        (is-eq tx-sender .dao-treasury)
        (is-eq tx-sender .conxian-access)
        (is-eq tx-sender .upgrade-controller)
        (is-eq tx-sender .emergency-governance)
      ) (err ERR_UNAUTHORIZED))

      (var-set entry-count entry-id)
      (map-set audit-entries entry-id {
        category: category,
        actor: actor,
        action: action,
        target: target,
        details: details,
        block: burn-block-height,
        timestamp: burn-block-height
      })
      (map-set category-index { category: category, entry-id: entry-id } true)
      (map-set actor-index { actor: actor, entry-id: entry-id } true)
      (print {
        event: "audit-entry-recorded",
        entry-id: entry-id,
        category: category,
        actor: actor,
        action: action
      })
      (ok entry-id)
    )
  )
)

;; --- Read-only ---

;; @desc Get a specific audit entry by ID
(define-read-only (get-audit-entry (entry-id uint))
  (match (map-get? audit-entries entry-id)
    entry (ok entry)
    (err ERR_ENTRY_NOT_FOUND)
  )
)

;; @desc Get the total number of audit entries
(define-read-only (get-entry-count)
  (var-get entry-count)
)

;; @desc Get the most recent audit entries (returns last N, up to 50)
(define-read-only (get-recent-entries (count uint))
  (let ((total (var-get entry-count)))
    (if (> count u50)
      (err ERR_UNAUTHORIZED)
      (ok {
        total: total,
        from: (if (> total count) (- total count) u1),
        to: total
      })
    )
  )
)

;; @desc Check if an audit entry exists at a given ID
(define-read-only (entry-exists (entry-id uint))
  (is-some (map-get? audit-entries entry-id))
)

;; --- Admin ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
