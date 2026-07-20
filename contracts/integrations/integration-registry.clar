;; integration-registry.clar
;; Approved integration configuration and API-key commitment lifecycle.
;; Raw API keys are authenticated off-chain. Only SHA-256 key hashes are
;; stored here; the hash is never accepted as a usage transaction credential.

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INTEGRATION_EXISTS (err u1001))
(define-constant ERR_INTEGRATION_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_BILLING_MODE (err u1003))
(define-constant ERR_INVALID_FEE (err u1004))
(define-constant ERR_DUPLICATE_KEY_HASH (err u1005))
(define-constant ERR_KEY_NOT_FOUND (err u1006))
(define-constant ERR_NOT_OWNER_OR_PAYER (err u1008))

;; Billing modes: u1 = per-use, u2 = monthly fixed fee.
(define-constant BILLING_MODE_PER_USE u1)
(define-constant BILLING_MODE_MONTHLY u2)

;; --- State ---
(define-data-var admin principal tx-sender)

(define-map integrations principal {
  owner: principal,
  payer: principal,
  reporter: principal,
  name: (string-ascii 64),
  metadata: (string-ascii 256),
  billing-mode: uint,
  fee-amount: uint,
  active: bool,
  key-hash: (buff 32),
  registered-at: uint,
  updated-at: uint
})

;; Key records are retained after rotation so an old hash can never be reused.
(define-map api-key-records (buff 32) {
  integration: principal,
  active: bool,
  registered-at: uint,
  deactivated-at: uint
})

;; --- Validation and authorization ---
(define-private (is-valid-billing-mode (billing-mode uint))
  (or
    (is-eq billing-mode BILLING_MODE_PER_USE)
    (is-eq billing-mode BILLING_MODE_MONTHLY)
  )
)

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (get-integration-or-error (integration principal))
  (map-get? integrations integration)
)

;; --- Administrative lifecycle ---

;; @desc Register an approved integration with bounded metadata and a key hash.
(define-public (register-integration
    (integration principal)
    (owner principal)
    (payer principal)
    (reporter principal)
    (name (string-ascii 64))
    (metadata (string-ascii 256))
    (billing-mode uint)
    (fee-amount uint)
    (key-hash (buff 32)))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? integrations integration)) ERR_INTEGRATION_EXISTS)
    (asserts! (is-valid-billing-mode billing-mode) ERR_INVALID_BILLING_MODE)
    (asserts! (> fee-amount u0) ERR_INVALID_FEE)
    (asserts! (is-none (map-get? api-key-records key-hash)) ERR_DUPLICATE_KEY_HASH)
    (map-set integrations integration {
      owner: owner,
      payer: payer,
      reporter: reporter,
      name: name,
      metadata: metadata,
      billing-mode: billing-mode,
      fee-amount: fee-amount,
      active: true,
      key-hash: key-hash,
      registered-at: burn-block-height,
      updated-at: burn-block-height
    })
    (map-set api-key-records key-hash {
      integration: integration,
      active: true,
      registered-at: burn-block-height,
      deactivated-at: u0
    })
    (print {
      event: "integration-registered",
      integration: integration,
      owner: owner,
      payer: payer,
      reporter: reporter,
      billing-mode: billing-mode,
      fee-amount: fee-amount
    })
    (ok true)
  )
)

;; @desc Update an integration's bounded metadata and billing configuration.
(define-public (set-integration-config
    (integration principal)
    (name (string-ascii 64))
    (metadata (string-ascii 256))
    (billing-mode uint)
    (fee-amount uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (is-valid-billing-mode billing-mode) ERR_INVALID_BILLING_MODE)
    (asserts! (> fee-amount u0) ERR_INVALID_FEE)
    (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
      (map-set integrations integration (merge current {
        name: name,
        metadata: metadata,
        billing-mode: billing-mode,
        fee-amount: fee-amount,
        updated-at: burn-block-height
      }))
      (print {
        event: "integration-config-updated",
        integration: integration,
        billing-mode: billing-mode,
        fee-amount: fee-amount
      })
      (ok true)
    )
  )
)

;; @desc Update the payer principal used for exact settlement authorization.
(define-public (set-integration-payer (integration principal) (payer principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
      (map-set integrations integration (merge current {
        payer: payer,
        updated-at: burn-block-height
      }))
      (ok true)
    )
  )
)

;; @desc Update the owner principal allowed to rotate the API-key commitment.
(define-public (set-integration-owner (integration principal) (owner principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
      (map-set integrations integration (merge current {
        owner: owner,
        updated-at: burn-block-height
      }))
      (ok true)
    )
  )
)

(define-private (set-active-status (integration principal) (active bool))
  (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
    (map-set integrations integration (merge current {
      active: active,
      updated-at: burn-block-height
    }))
    (print {
      event: "integration-status-updated",
      integration: integration,
      active: active
    })
    (ok active)
  )
)

;; @desc Enable or disable an integration. Disabled integrations cannot record usage.
(define-public (set-integration-status (integration principal) (active bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (set-active-status integration active)
  )
)

;; Alias with an explicit active name for operational callers.
(define-public (set-integration-active (integration principal) (active bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (set-active-status integration active)
  )
)

;; @desc Change the trusted usage reporter for an integration.
(define-public (set-integration-reporter (integration principal) (reporter principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
      (map-set integrations integration (merge current {
        reporter: reporter,
        updated-at: burn-block-height
      }))
      (print {
        event: "integration-reporter-updated",
        integration: integration,
        reporter: reporter
      })
      (ok true)
    )
  )
)

;; @desc Rotate a key commitment. Only the configured owner or payer may do so.
;; The previous key record is retained and marked inactive permanently.
(define-public (rotate-api-key (integration principal) (new-key-hash (buff 32)))
  (let ((current (unwrap! (get-integration-or-error integration) ERR_INTEGRATION_NOT_FOUND)))
    (begin
      (asserts!
        (or
          (is-eq tx-sender (get owner current))
          (is-eq tx-sender (get payer current)))
        ERR_NOT_OWNER_OR_PAYER)
      (asserts! (is-none (map-get? api-key-records new-key-hash)) ERR_DUPLICATE_KEY_HASH)
      (map-set api-key-records (get key-hash current) {
        integration: integration,
        active: false,
        registered-at: (get registered-at (unwrap! (map-get? api-key-records (get key-hash current)) ERR_INTEGRATION_NOT_FOUND)),
        deactivated-at: burn-block-height
      })
      (map-set api-key-records new-key-hash {
        integration: integration,
        active: true,
        registered-at: burn-block-height,
        deactivated-at: u0
      })
      (map-set integrations integration (merge current {
        key-hash: new-key-hash,
        updated-at: burn-block-height
      }))
      (print {
        event: "integration-api-key-rotated",
        integration: integration,
        old-key-hash: (get key-hash current),
        new-key-hash: new-key-hash,
        actor: tx-sender
      })
      (ok true)
    )
  )
)

;; @desc Update the registry administrator.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- Read-only API ---

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-integration (integration principal))
  (ok (map-get? integrations integration))
)

(define-read-only (get-integration-config (integration principal))
  (ok (map-get? integrations integration))
)

(define-read-only (is-integration-active (integration principal))
  (match (map-get? integrations integration)
    current (ok (get active current))
    (ok false))
)

(define-read-only (get-integration-reporter (integration principal))
  (match (map-get? integrations integration)
    current (ok (some (get reporter current)))
    (ok none))
)

(define-read-only (get-integration-payer (integration principal))
  (match (map-get? integrations integration)
    current (ok (some (get payer current)))
    (ok none))
)

(define-read-only (get-integration-key-hash (integration principal))
  (match (map-get? integrations integration)
    current (ok (some (get key-hash current)))
    (ok none))
)

(define-read-only (get-api-key-record (key-hash (buff 32)))
  (ok (map-get? api-key-records key-hash))
)

(define-read-only (is-api-key-active (key-hash (buff 32)))
  (match (map-get? api-key-records key-hash)
    current (ok (get active current))
    (ok false))
)
