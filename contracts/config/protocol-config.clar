;; protocol-config.clar
;; Centralized Protocol Configuration Registry
;;
;; Provides a single source of truth for protocol-wide parameters.
;; All config changes are timelock-gated via conxian-access admin.
;; Modules read their configuration from this registry at runtime.

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_KEY_NOT_FOUND u1001)
(define-constant ERR_INVALID_VALUE u1002)
(define-constant ERR_IMMUTABLE_KEY u1003)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)

;; Configuration key-value store
(define-map config-entries
  (string-ascii 64)
  {
    value: uint,
    updated-at: uint,
    updated-by: principal,
    mutable: bool
  }
)

;; Track config change history for audit
(define-map config-history
  { key: (string-ascii 64), version: uint }
  {
    old-value: uint,
    new-value: uint,
    updated-at: uint,
    updated-by: principal
  }
)

(define-data-var config-version uint u0)

;; --- Initialization ---

(define-public (initialize)
  (begin
    (asserts! (not (var-get initialized)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set initialized true)

    ;; Seed immutable config values
    (map-set config-entries "max-fee-bps" { value: u300, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "min-collateral-pct" { value: u15000, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "protocol-version" { value: u400, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "bitvm2-challenge-window" { value: u144, updated-at: u0, updated-by: tx-sender, mutable: true })
    (map-set config-entries "default-voting-period" { value: u1008, updated-at: u0, updated-by: tx-sender, mutable: true })
    (map-set config-entries "default-quorum-bps" { value: u5000, updated-at: u0, updated-by: tx-sender, mutable: true })
    (map-set config-entries "timelock-min-delay" { value: u100, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "timelock-max-delay" { value: u10000, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "self-launch-phase-1-target" { value: u10000000000, updated-at: u0, updated-by: tx-sender, mutable: false })
    (map-set config-entries "self-launch-phase-5-target" { value: u600000000000, updated-at: u0, updated-by: tx-sender, mutable: false })

    (print { event: "protocol-config-initialized" })
    (ok true)
  )
)

;; --- Config Management ---

;; @desc Set a mutable configuration value (admin only, timelock-gated)
;; @param key: The configuration key name
;; @param value: The new value
(define-public (set-config (key (string-ascii 64)) (value uint))
  (let (
      (entry (unwrap! (map-get? config-entries key) (err ERR_KEY_NOT_FOUND)))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
      (asserts! (var-get initialized) (err ERR_UNAUTHORIZED))
      (asserts! (get mutable entry) (err ERR_IMMUTABLE_KEY))

      (let ((new-version (+ (var-get config-version) u1)))
        (var-set config-version new-version)
        (map-set config-history { key: key, version: new-version } {
          old-value: (get value entry),
          new-value: value,
          updated-at: burn-block-height,
          updated-by: tx-sender
        })
        (map-set config-entries key (merge entry {
          value: value,
          updated-at: burn-block-height,
          updated-by: tx-sender
        }))
        (print {
          event: "config-updated",
          key: key,
          old-value: (get value entry),
          new-value: value,
          version: new-version
        })
        (ok true)
      ))
    )
  )


;; @desc Add a new mutable configuration entry (admin only)
;; @param key: The configuration key name
;; @param value: The initial value
(define-public (add-config-key (key (string-ascii 64)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (var-get initialized) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? config-entries key)) (err ERR_UNAUTHORIZED))
    (map-set config-entries key {
      value: value,
      updated-at: burn-block-height,
      updated-by: tx-sender,
      mutable: true
    })
    (print { event: "config-key-added", key: key, value: value })
    (ok true)
  )
)

;; --- Read-only ---

;; @desc Get a configuration value
(define-read-only (get-config (key (string-ascii 64)))
  (match (map-get? config-entries key)
    entry (ok (get value entry))
    (err ERR_KEY_NOT_FOUND)
  )
)

;; @desc Get full configuration entry with metadata
(define-read-only (get-config-entry (key (string-ascii 64)))
  (match (map-get? config-entries key)
    entry (ok entry)
    (err ERR_KEY_NOT_FOUND)
  )
)

;; @desc Get config change history for a key
(define-read-only (get-config-history (key (string-ascii 64)) (version uint))
  (match (map-get? config-history { key: key, version: version })
    history (ok history)
    (err ERR_KEY_NOT_FOUND)
  )
)

;; @desc Get the current config version
(define-read-only (get-config-version)
  (var-get config-version)
)

;; --- Admin ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (print { event: "config-admin-changed", new-admin: new-admin })
    (ok true)
  )
)
