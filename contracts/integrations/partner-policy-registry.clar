;; partner-policy-registry.clar
;; Dormant partner/integration policy schema and lifecycle controls.
;;
;; This contract does not record usage, custody assets, or settle partner fees.
;; It stores public-safe policy commitments and versioned role bindings for a
;; future, separately versioned settlement route. Raw KYC, tax, legal,
;; sanctions, jurisdiction, and customer data must remain off-chain.

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_POLICY_ID (err u3001))
(define-constant ERR_INVALID_VERSION (err u3002))
(define-constant ERR_POLICY_EXISTS (err u3003))
(define-constant ERR_POLICY_NOT_FOUND (err u3004))
(define-constant ERR_INVALID_EFFECTIVE_PERIOD (err u3005))
(define-constant ERR_UNSUPPORTED_ASSET (err u3006))
(define-constant ERR_UNSUPPORTED_BILLING_MODE (err u3007))
(define-constant ERR_UNSUPPORTED_POLICY_MODE (err u3008))
(define-constant ERR_POLICY_NOT_ACTIVE (err u3009))
(define-constant ERR_POLICY_NOT_EFFECTIVE (err u3010))
(define-constant ERR_POLICY_REVOKED (err u3011))
(define-constant ERR_PARTNER_EXISTS (err u3012))
(define-constant ERR_PARTNER_NOT_FOUND (err u3013))
(define-constant ERR_INVALID_ROLE_BINDING (err u3014))
(define-constant ERR_INVALID_TRANSITION (err u3015))
(define-constant ERR_POLICY_MISMATCH (err u3016))
(define-constant ERR_PARTNER_INACTIVE (err u3017))
(define-constant ERR_BOOTSTRAP_FINALIZED (err u3018))
(define-constant ERR_AUTHORIZATION_NOT_READY (err u3019))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u3020))

;; --- Approved dormant v1 defaults ---
(define-constant ASSET_NATIVE_STX_MICROSTX u1)
(define-constant BILLING_MODE_PER_USE u1)
(define-constant FEE_BASE_ACCEPTED_SETTLED_MICROSTX u1)
(define-constant CORRECTION_MODE_APPEND_THEN_COMPENSATE u1)
(define-constant LIFECYCLE_MODE_IMMUTABLE_VERSIONED u1)
(define-constant PARTNER_SPLIT_BPS u5000)
(define-constant PROTOCOL_SPLIT_BPS u5000)
(define-constant BPS_DENOMINATOR u10000)
(define-constant PERIOD_LENGTH_BURN_BLOCKS u4320)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-constant POLICY_STATUS_DRAFT u1)
(define-constant POLICY_STATUS_ACTIVE u2)
(define-constant POLICY_STATUS_REVOKED u3)

(define-constant PARTNER_STATUS_REGISTERED u1)
(define-constant PARTNER_STATUS_ACTIVE u2)
(define-constant PARTNER_STATUS_INACTIVE u3)
(define-constant PARTNER_STATUS_REVOKED u4)

(define-constant ADMIN_ROUTE_KEY "partner-policy-admin")
(define-constant REGISTRAR_ROUTE_KEY "partner-policy-registrar")

;; The publish-time principal may bootstrap the two dynamic treasury routes.
;; Once finalized, all authorization fails closed on missing route entries.
(define-data-var bootstrap-admin principal tx-sender)
(define-data-var bootstrap-active bool true)

;; --- Immutable policy content plus lifecycle markers ---
(define-map policy-records { policy-id: uint, version: uint } {
  policy-hash: (buff 32),
  asset: uint,
  billing-mode: uint,
  fee-base: uint,
  correction-mode: uint,
  lifecycle-mode: uint,
  partner-split-bps: uint,
  protocol-split-bps: uint,
  period-length: uint,
  effective-start: uint,
  effective-end: uint,
  status: uint,
  created-at: uint,
  activated-at: uint,
  revoked-at: uint,
  revocation-reason-hash: (optional (buff 32))
})

;; Sequential versions and non-overlapping effective periods are enforced per
;; policy ID. The head never changes historical policy records.
(define-map policy-version-heads uint {
  latest-version: uint,
  last-effective-end: uint
})

;; Partner records are versioned so beneficiary changes never rewrite the
;; historical role/policy binding that was previously active.
(define-map partner-records { integration: principal, version: uint } {
  owner: principal,
  payer: principal,
  beneficiary: principal,
  reporter: principal,
  asset: uint,
  billing-mode: uint,
  policy-id: uint,
  policy-version: uint,
  policy-hash: (buff 32),
  status: uint,
  registered-at: uint,
  activated-at: uint,
  deactivated-at: uint
})

(define-map partner-version-heads principal uint)

;; --- Authorization and validation ---
(define-private (route-principal (key (string-ascii 50)))
  (contract-call? .operational-treasury get-protocol-principal key)
)

(define-private (is-route-authorized (key (string-ascii 50)) (actor principal))
  (match (route-principal key)
    configured (is-eq actor configured)
    false)
)

(define-private (is-admin-principal (actor principal))
  (or
    (is-route-authorized ADMIN_ROUTE_KEY actor)
    (and
      (var-get bootstrap-active)
      (is-eq actor (var-get bootstrap-admin))))
)

(define-private (is-registrar-principal (actor principal))
  (or
    (is-admin-principal actor)
    (is-route-authorized REGISTRAR_ROUTE_KEY actor))
)

(define-private (valid-v1-policy-modes
    (asset uint)
    (billing-mode uint)
    (fee-base uint)
    (correction-mode uint)
    (lifecycle-mode uint))
  (and
    (is-eq asset ASSET_NATIVE_STX_MICROSTX)
    (is-eq billing-mode BILLING_MODE_PER_USE)
    (is-eq fee-base FEE_BASE_ACCEPTED_SETTLED_MICROSTX)
    (is-eq correction-mode CORRECTION_MODE_APPEND_THEN_COMPENSATE)
    (is-eq lifecycle-mode LIFECYCLE_MODE_IMMUTABLE_VERSIONED))
)

(define-private (valid-role-bindings
    (integration principal)
    (owner principal)
    (payer principal)
    (beneficiary principal)
    (reporter principal))
  (and
    (not (is-eq integration owner))
    (not (is-eq integration payer))
    (not (is-eq integration beneficiary))
    (not (is-eq integration reporter))
    (not (is-eq owner payer))
    (not (is-eq owner beneficiary))
    (not (is-eq reporter owner))
    (not (is-eq payer beneficiary))
    (not (is-eq reporter payer))
    (not (is-eq reporter beneficiary)))
)

(define-private (policy-effective-now (policy {
    policy-hash: (buff 32),
    asset: uint,
    billing-mode: uint,
    fee-base: uint,
    correction-mode: uint,
    lifecycle-mode: uint,
    partner-split-bps: uint,
    protocol-split-bps: uint,
    period-length: uint,
    effective-start: uint,
    effective-end: uint,
    status: uint,
    created-at: uint,
    activated-at: uint,
    revoked-at: uint,
    revocation-reason-hash: (optional (buff 32)) }))
  (and
    (is-eq (get status policy) POLICY_STATUS_ACTIVE)
    (<= (get effective-start policy) burn-block-height)
    (< burn-block-height (get effective-end policy)))
)

(define-private (load-current-partner (integration principal))
  (let ((version (unwrap! (map-get? partner-version-heads integration) ERR_PARTNER_NOT_FOUND)))
    (ok {
      version: version,
      record: (unwrap!
        (map-get? partner-records { integration: integration, version: version })
        ERR_PARTNER_NOT_FOUND)
    })
  )
)

;; --- Policy lifecycle ---

;; @desc Publish one immutable v1 policy version. Later versions must be
;; sequential and their effective periods may not overlap or move backward.
(define-public (create-policy
    (policy-id uint)
    (version uint)
    (policy-hash (buff 32))
    (asset uint)
    (billing-mode uint)
    (fee-base uint)
    (correction-mode uint)
    (lifecycle-mode uint)
    (effective-start uint)
    (effective-end uint))
  (begin
    (asserts! (is-admin-principal tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> policy-id u0) ERR_INVALID_POLICY_ID)
    (asserts! (> version u0) ERR_INVALID_VERSION)
    (asserts! (> effective-end effective-start) ERR_INVALID_EFFECTIVE_PERIOD)
    (asserts! (is-eq asset ASSET_NATIVE_STX_MICROSTX) ERR_UNSUPPORTED_ASSET)
    (asserts! (is-eq billing-mode BILLING_MODE_PER_USE) ERR_UNSUPPORTED_BILLING_MODE)
    (asserts!
      (and
        (is-eq fee-base FEE_BASE_ACCEPTED_SETTLED_MICROSTX)
        (is-eq correction-mode CORRECTION_MODE_APPEND_THEN_COMPENSATE)
        (is-eq lifecycle-mode LIFECYCLE_MODE_IMMUTABLE_VERSIONED))
      ERR_UNSUPPORTED_POLICY_MODE)
    (asserts!
      (is-none (map-get? policy-records { policy-id: policy-id, version: version }))
      ERR_POLICY_EXISTS)
    (match (map-get? policy-version-heads policy-id)
      head (begin
        (asserts! (< (get latest-version head) MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
        (asserts! (is-eq version (+ (get latest-version head) u1)) ERR_INVALID_VERSION)
        (asserts! (>= effective-start (get last-effective-end head)) ERR_INVALID_EFFECTIVE_PERIOD))
      (asserts! (is-eq version u1) ERR_INVALID_VERSION))
    (map-set policy-records { policy-id: policy-id, version: version } {
      policy-hash: policy-hash,
      asset: asset,
      billing-mode: billing-mode,
      fee-base: fee-base,
      correction-mode: correction-mode,
      lifecycle-mode: lifecycle-mode,
      partner-split-bps: PARTNER_SPLIT_BPS,
      protocol-split-bps: PROTOCOL_SPLIT_BPS,
      period-length: PERIOD_LENGTH_BURN_BLOCKS,
      effective-start: effective-start,
      effective-end: effective-end,
      status: POLICY_STATUS_DRAFT,
      created-at: burn-block-height,
      activated-at: u0,
      revoked-at: u0,
      revocation-reason-hash: none
    })
    (map-set policy-version-heads policy-id {
      latest-version: version,
      last-effective-end: effective-end
    })
    (print {
      event: "partner-policy-created",
      policy-id: policy-id,
      version: version,
      policy-hash: policy-hash,
      effective-start: effective-start,
      effective-end: effective-end
    })
    (ok true)
  )
)

(define-public (activate-policy (policy-id uint) (version uint))
  (begin
    (asserts! (is-admin-principal tx-sender) ERR_UNAUTHORIZED)
    (let ((policy (unwrap!
      (map-get? policy-records { policy-id: policy-id, version: version })
      ERR_POLICY_NOT_FOUND)))
      (asserts! (is-eq (get status policy) POLICY_STATUS_DRAFT) ERR_INVALID_TRANSITION)
      (asserts! (> (get effective-end policy) burn-block-height) ERR_POLICY_NOT_EFFECTIVE)
      (map-set policy-records { policy-id: policy-id, version: version } (merge policy {
        status: POLICY_STATUS_ACTIVE,
        activated-at: burn-block-height
      }))
      (print {
        event: "partner-policy-activated",
        policy-id: policy-id,
        version: version,
        policy-hash: (get policy-hash policy),
        effective-start: (get effective-start policy),
        effective-end: (get effective-end policy)
      })
      (ok true)
    )
  )
)

(define-public (revoke-policy
    (policy-id uint)
    (version uint)
    (reason-hash (buff 32)))
  (begin
    (asserts! (is-admin-principal tx-sender) ERR_UNAUTHORIZED)
    (let ((policy (unwrap!
      (map-get? policy-records { policy-id: policy-id, version: version })
      ERR_POLICY_NOT_FOUND)))
      (asserts! (is-eq (get status policy) POLICY_STATUS_ACTIVE) ERR_INVALID_TRANSITION)
      (map-set policy-records { policy-id: policy-id, version: version } (merge policy {
        status: POLICY_STATUS_REVOKED,
        revoked-at: burn-block-height,
        revocation-reason-hash: (some reason-hash)
      }))
      (print {
        event: "partner-policy-revoked",
        policy-id: policy-id,
        version: version,
        policy-hash: (get policy-hash policy),
        reason-hash: reason-hash
      })
      (ok true)
    )
  )
)

;; --- Partner lifecycle ---

(define-public (register-partner
    (integration principal)
    (owner principal)
    (payer principal)
    (beneficiary principal)
    (reporter principal)
    (policy-id uint)
    (policy-version uint))
  (begin
    (asserts! (is-registrar-principal tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? partner-version-heads integration)) ERR_PARTNER_EXISTS)
    (asserts!
      (valid-role-bindings integration owner payer beneficiary reporter)
      ERR_INVALID_ROLE_BINDING)
    (let ((policy (unwrap!
      (map-get? policy-records { policy-id: policy-id, version: policy-version })
      ERR_POLICY_NOT_FOUND)))
      (asserts! (is-eq (get status policy) POLICY_STATUS_ACTIVE) ERR_POLICY_NOT_ACTIVE)
      (asserts! (policy-effective-now policy) ERR_POLICY_NOT_EFFECTIVE)
      (asserts!
        (valid-v1-policy-modes
          (get asset policy)
          (get billing-mode policy)
          (get fee-base policy)
          (get correction-mode policy)
          (get lifecycle-mode policy))
        ERR_UNSUPPORTED_POLICY_MODE)
      (map-set partner-records { integration: integration, version: u1 } {
        owner: owner,
        payer: payer,
        beneficiary: beneficiary,
        reporter: reporter,
        asset: (get asset policy),
        billing-mode: (get billing-mode policy),
        policy-id: policy-id,
        policy-version: policy-version,
        policy-hash: (get policy-hash policy),
        status: PARTNER_STATUS_REGISTERED,
        registered-at: burn-block-height,
        activated-at: u0,
        deactivated-at: u0
      })
      (map-set partner-version-heads integration u1)
      (print {
        event: "partner-integration-registered",
        integration: integration,
        registration-version: u1,
        owner: owner,
        payer: payer,
        beneficiary: beneficiary,
        reporter: reporter,
        policy-id: policy-id,
        policy-version: policy-version,
        policy-hash: (get policy-hash policy)
      })
      (ok u1)
    )
  )
)

(define-public (activate-partner (integration principal))
  (begin
    (asserts! (is-registrar-principal tx-sender) ERR_UNAUTHORIZED)
    (let (
      (current (try! (load-current-partner integration)))
      (version (get version current))
      (record (get record current))
      (policy (unwrap!
        (map-get? policy-records {
          policy-id: (get policy-id record),
          version: (get policy-version record) })
        ERR_POLICY_NOT_FOUND))
    )
      (asserts! (is-eq (get status record) PARTNER_STATUS_REGISTERED) ERR_INVALID_TRANSITION)
      (asserts! (policy-effective-now policy) ERR_POLICY_NOT_EFFECTIVE)
      (asserts! (is-eq (get policy-hash record) (get policy-hash policy)) ERR_POLICY_MISMATCH)
      (map-set partner-records { integration: integration, version: version } (merge record {
        status: PARTNER_STATUS_ACTIVE,
        activated-at: burn-block-height
      }))
      (print {
        event: "partner-integration-activated",
        integration: integration,
        registration-version: version,
        policy-id: (get policy-id record),
        policy-version: (get policy-version record)
      })
      (ok true)
    )
  )
)

;; @desc Beneficiary changes create a new active registration version. The
;; preceding record is retained and marked inactive for historical audit.
(define-public (change-beneficiary (integration principal) (new-beneficiary principal))
  (begin
    (asserts! (is-registrar-principal tx-sender) ERR_UNAUTHORIZED)
    (let (
      (current (try! (load-current-partner integration)))
      (old-version (get version current))
      (old-record (get record current))
      (policy (unwrap!
        (map-get? policy-records {
          policy-id: (get policy-id old-record),
          version: (get policy-version old-record) })
        ERR_POLICY_NOT_FOUND))
    )
      (asserts! (is-eq (get status old-record) PARTNER_STATUS_ACTIVE) ERR_PARTNER_INACTIVE)
      (asserts! (< old-version MAX_UINT) ERR_ARITHMETIC_OVERFLOW)
      (asserts!
        (valid-role-bindings
          integration
          (get owner old-record)
          (get payer old-record)
          new-beneficiary
          (get reporter old-record))
        ERR_INVALID_ROLE_BINDING)
      (asserts! (policy-effective-now policy) ERR_POLICY_NOT_EFFECTIVE)
      (let ((new-version (+ old-version u1)))
        (map-set partner-records { integration: integration, version: old-version } (merge old-record {
          status: PARTNER_STATUS_INACTIVE,
          deactivated-at: burn-block-height
        }))
        (map-set partner-records { integration: integration, version: new-version } (merge old-record {
          beneficiary: new-beneficiary,
          status: PARTNER_STATUS_ACTIVE,
          registered-at: burn-block-height,
          activated-at: burn-block-height,
          deactivated-at: u0
        }))
        (map-set partner-version-heads integration new-version)
        (print {
          event: "partner-beneficiary-changed",
          integration: integration,
          previous-registration-version: old-version,
          registration-version: new-version,
          previous-beneficiary: (get beneficiary old-record),
          beneficiary: new-beneficiary,
          policy-id: (get policy-id old-record),
          policy-version: (get policy-version old-record)
        })
        (ok new-version)
      )
    )
  )
)

(define-private (close-partner
    (integration principal)
    (next-status uint)
    (event-name (string-ascii 40)))
  (let (
    (current (try! (load-current-partner integration)))
    (version (get version current))
    (record (get record current))
  )
    (begin
      (asserts!
        (or
          (is-eq (get status record) PARTNER_STATUS_REGISTERED)
          (is-eq (get status record) PARTNER_STATUS_ACTIVE))
        ERR_INVALID_TRANSITION)
      (map-set partner-records { integration: integration, version: version } (merge record {
        status: next-status,
        deactivated-at: burn-block-height
      }))
      (print {
        event: event-name,
        integration: integration,
        registration-version: version,
        policy-id: (get policy-id record),
        policy-version: (get policy-version record)
      })
      (ok true)
    )
  )
)

(define-public (deactivate-partner (integration principal))
  (begin
    (asserts! (is-registrar-principal tx-sender) ERR_UNAUTHORIZED)
    (close-partner integration PARTNER_STATUS_INACTIVE "partner-integration-deactivated")
  )
)

(define-public (revoke-partner (integration principal))
  (begin
    (asserts! (is-admin-principal tx-sender) ERR_UNAUTHORIZED)
    (close-partner integration PARTNER_STATUS_REVOKED "partner-integration-revoked")
  )
)

;; @desc Permanently remove the publish-time bootstrap fallback after both
;; dynamic authorization routes have been configured in operational-treasury.
(define-public (finalize-bootstrap-authorization)
  (begin
    (asserts! (var-get bootstrap-active) ERR_BOOTSTRAP_FINALIZED)
    (asserts! (is-eq tx-sender (var-get bootstrap-admin)) ERR_UNAUTHORIZED)
    (asserts!
      (and
        (is-some (route-principal ADMIN_ROUTE_KEY))
        (is-some (route-principal REGISTRAR_ROUTE_KEY)))
      ERR_AUTHORIZATION_NOT_READY)
    (var-set bootstrap-active false)
    (print { event: "partner-policy-bootstrap-finalized" })
    (ok true)
  )
)

;; --- Read-only audit API ---

(define-read-only (get-policy (policy-id uint) (version uint))
  (ok (map-get? policy-records { policy-id: policy-id, version: version }))
)

(define-read-only (get-policy-head (policy-id uint))
  (ok (map-get? policy-version-heads policy-id))
)

(define-read-only (get-effective-period (policy-id uint) (version uint))
  (match (map-get? policy-records { policy-id: policy-id, version: version })
    policy (ok (some {
      effective-start: (get effective-start policy),
      effective-end: (get effective-end policy),
      period-length: (get period-length policy),
      status: (get status policy)
    }))
    (ok none))
)

(define-read-only (get-policy-asset (policy-id uint) (version uint))
  (match (map-get? policy-records { policy-id: policy-id, version: version })
    policy (ok (some (get asset policy)))
    (ok none))
)

(define-read-only (get-policy-billing-mode (policy-id uint) (version uint))
  (match (map-get? policy-records { policy-id: policy-id, version: version })
    policy (ok (some (get billing-mode policy)))
    (ok none))
)

(define-read-only (get-partner (integration principal))
  (match (map-get? partner-version-heads integration)
    version (ok (map-get? partner-records { integration: integration, version: version }))
    (ok none))
)

(define-read-only (get-partner-version (integration principal) (version uint))
  (ok (map-get? partner-records { integration: integration, version: version }))
)

;; Future usage/settlement consumers must call this with the registration's
;; immutable policy reference. Missing, stale, revoked, inactive, mismatched,
;; or unsupported combinations return an error rather than a permissive bool.
(define-read-only (validate-partner-policy
    (integration principal)
    (policy-id uint)
    (policy-version uint)
    (policy-hash (buff 32)))
  (let (
    (current (try! (load-current-partner integration)))
    (record (get record current))
  )
    (begin
      (asserts! (is-eq (get status record) PARTNER_STATUS_ACTIVE) ERR_PARTNER_INACTIVE)
      (asserts!
        (and
          (is-eq (get policy-id record) policy-id)
          (is-eq (get policy-version record) policy-version)
          (is-eq (get policy-hash record) policy-hash))
        ERR_POLICY_MISMATCH)
      (let ((policy (unwrap!
        (map-get? policy-records { policy-id: policy-id, version: policy-version })
        ERR_POLICY_NOT_FOUND)))
        (asserts! (not (is-eq (get status policy) POLICY_STATUS_REVOKED)) ERR_POLICY_REVOKED)
        (asserts! (is-eq (get status policy) POLICY_STATUS_ACTIVE) ERR_POLICY_NOT_ACTIVE)
        (asserts! (policy-effective-now policy) ERR_POLICY_NOT_EFFECTIVE)
        (asserts! (is-eq (get policy-hash policy) policy-hash) ERR_POLICY_MISMATCH)
        (asserts!
          (valid-v1-policy-modes
            (get asset policy)
            (get billing-mode policy)
            (get fee-base policy)
            (get correction-mode policy)
            (get lifecycle-mode policy))
          ERR_UNSUPPORTED_POLICY_MODE)
        (ok {
          registration-version: (get version current),
          owner: (get owner record),
          payer: (get payer record),
          beneficiary: (get beneficiary record),
          reporter: (get reporter record),
          asset: (get asset policy),
          billing-mode: (get billing-mode policy),
          fee-base: (get fee-base policy),
          partner-split-bps: (get partner-split-bps policy),
          protocol-split-bps: (get protocol-split-bps policy),
          period-length: (get period-length policy),
          correction-mode: (get correction-mode policy),
          lifecycle-mode: (get lifecycle-mode policy),
          effective-start: (get effective-start policy),
          effective-end: (get effective-end policy),
          policy-id: policy-id,
          policy-version: policy-version,
          policy-hash: policy-hash
        })
      )
    )
  )
)

(define-read-only (get-v1-defaults)
  (ok {
    asset: ASSET_NATIVE_STX_MICROSTX,
    billing-mode: BILLING_MODE_PER_USE,
    fee-base: FEE_BASE_ACCEPTED_SETTLED_MICROSTX,
    correction-mode: CORRECTION_MODE_APPEND_THEN_COMPENSATE,
    lifecycle-mode: LIFECYCLE_MODE_IMMUTABLE_VERSIONED,
    partner-split-bps: PARTNER_SPLIT_BPS,
    protocol-split-bps: PROTOCOL_SPLIT_BPS,
    bps-denominator: BPS_DENOMINATOR,
    period-length: PERIOD_LENGTH_BURN_BLOCKS
  })
)

;; Exact v1 floor/remainder semantics. This is read-only policy math, not a
;; transfer, payout, settlement, or authorization to activate partner routing.
(define-read-only (preview-v1-split (accepted-fee-microstx uint))
  (let ((partner-amount (/ accepted-fee-microstx u2)))
    (ok {
      partner-amount: partner-amount,
      protocol-amount: (- accepted-fee-microstx partner-amount)
    })
  )
)

(define-read-only (get-authorization-state (actor principal))
  (ok {
    bootstrap-admin: (var-get bootstrap-admin),
    bootstrap-active: (var-get bootstrap-active),
    admin-route: (route-principal ADMIN_ROUTE_KEY),
    registrar-route: (route-principal REGISTRAR_ROUTE_KEY),
    actor-is-admin: (is-admin-principal actor),
    actor-is-registrar: (is-registrar-principal actor)
  })
)
