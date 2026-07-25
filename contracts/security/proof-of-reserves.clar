;; @contract proof-of-reserves
;; @desc Fail-closed, quorum-backed reserve snapshot verification.
;; @version 2.0.0
;;
;; This verifies registered secp256k1 attestors over a canonical, chain-bound
;; snapshot. It does not qualify attestors, perform audits, or prove deployment.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_SIGNATURE (err u8001))
(define-constant ERR_STALE_OBSERVATION (err u8002))
(define-constant ERR_DUPLICATE_ATTESTATION (err u8003))
(define-constant ERR_INVALID_ATTESTOR (err u8004))
(define-constant ERR_REGISTRY_FULL (err u8005))
(define-constant ERR_INVALID_QUORUM (err u8006))
(define-constant ERR_TOKEN_CALL_FAILED (err u8007))
(define-constant ERR_NONCE_REPLAY (err u8009))
(define-constant ERR_SNAPSHOT_MISMATCH (err u8010))
(define-constant ERR_SERIALIZATION_FAILED (err u8011))
(define-constant ERR_ATTESTOR_EXISTS (err u8012))
(define-constant ERR_ATTESTOR_NOT_FOUND (err u8013))
(define-constant ERR_UNSUPPORTED_SIGNATURE (err u8014))
(define-constant ERR_UNSUPPORTED_PUBLIC_KEY (err u8015))

;; All validity values are burn-block heights. Observations are accepted at
;; age <= 1008. Expiry is exclusive: valid only while height < expiry.
(define-constant SNAPSHOT_DOMAIN "CONXIAN_POR_SNAPSHOT_V1")
(define-constant ATTESTOR_DOMAIN "CONXIAN_POR_ATTESTOR_V1")
(define-constant SCHEMA_VERSION u1)
(define-constant MAX_ATTESTORS u10)
(define-constant DEFAULT_QUORUM u3)
(define-constant MAX_OBSERVATION_AGE_BLOCKS u1008)
(define-constant MAX_EXPIRY_WINDOW_BLOCKS u1008)
(define-constant VERIFYING_CONTRACT .proof-of-reserves)

(define-data-var contract-owner principal tx-sender)
(define-data-var quorum uint DEFAULT_QUORUM)
(define-data-var attestor-list (list 10 principal) (list))

(define-map attestor-registry
  principal
  { active: bool, public-key: (buff 33), key-version: uint })

(define-map reserve-snapshots
  (buff 32)
  {
    domain: (string-ascii 24), schema-version: uint, network: uint,
    verifying-contract: principal, asset: principal,
    on-chain-balance: uint, total-supply: uint, off-chain-backing: uint,
    as-of-height: uint, expiry-height: uint, nonce: uint,
    first-submitted-at: uint })

(define-map validated-attestations
  { snapshot-digest: (buff 32), attestor: principal }
  {
    envelope-digest: (buff 32), signature: (buff 65),
    public-key: (buff 33), key-version: uint, submitted-at: uint })

(define-map used-nonces
  { asset: principal, attestor: principal, nonce: uint }
  bool)

(define-map active-snapshots principal (buff 32))

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (contract-principal)
  VERIFYING_CONTRACT)

(define-private (observation-window-valid
    (as-of-height uint) (expiry-height uint) (current-height uint))
  (and
    (<= as-of-height current-height)
    (<= (- current-height as-of-height) MAX_OBSERVATION_AGE_BLOCKS)
    (> expiry-height current-height)
    (> expiry-height as-of-height)
    (<= (- expiry-height as-of-height) MAX_EXPIRY_WINDOW_BLOCKS)))

;; Overflow-safe equivalent of on-chain-balance + off-chain-backing >= supply.
(define-private (covers-supply
    (on-chain-balance uint) (off-chain-backing uint) (total-supply uint))
  (or
    (>= on-chain-balance total-supply)
    (>= off-chain-backing (- total-supply on-chain-balance))))

(define-private (count-valid-attestor
    (attestor principal)
    (state { snapshot-digest: (buff 32), count: uint }))
  (match (map-get? attestor-registry attestor)
    registry
      (match (map-get? validated-attestations {
          snapshot-digest: (get snapshot-digest state), attestor: attestor })
        record
          (if (and
              (get active registry)
              (is-eq (get key-version registry) (get key-version record))
              (is-eq (get public-key registry) (get public-key record)))
            (merge state { count: (+ (get count state) u1) })
            state)
        state)
    state))

(define-private (valid-attestation-count (snapshot-digest (buff 32)))
  (get count (fold count-valid-attestor (var-get attestor-list) {
    snapshot-digest: snapshot-digest, count: u0 })))

;; Canonical shared digest. Tuple field names and types are the signed schema.
(define-read-only (get-shared-snapshot-digest
    (asset principal)
    (on-chain-balance uint)
    (total-supply uint)
    (off-chain-backing uint)
    (as-of-height uint)
    (expiry-height uint)
    (nonce uint))
  (match (to-consensus-buff? {
      domain: SNAPSHOT_DOMAIN,
      schema-version: SCHEMA_VERSION,
      network: chain-id,
      verifying-contract: (contract-principal),
      asset: asset,
      on-chain-balance: on-chain-balance,
      total-supply: total-supply,
      off-chain-backing: off-chain-backing,
      as-of-height: as-of-height,
      expiry-height: expiry-height,
      nonce: nonce })
    serialized (ok (sha256 serialized))
    ERR_SERIALIZATION_FAILED))

;; The envelope binds the shared digest to one registered identity.
(define-read-only (get-attestor-envelope-digest
    (snapshot-digest (buff 32)) (attestor principal))
  (let ((verifying-contract (contract-principal)))
  (match (to-consensus-buff? {
      domain: ATTESTOR_DOMAIN,
      schema-version: SCHEMA_VERSION,
      network: chain-id,
      verifying-contract: verifying-contract,
      snapshot-digest: snapshot-digest,
      attestor: attestor })
    serialized (ok (sha256 serialized))
    ERR_SERIALIZATION_FAILED)))

(define-public (add-attestor (attestor principal) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len public-key) u33) ERR_UNSUPPORTED_PUBLIC_KEY)
    (asserts! (is-none (map-get? attestor-registry attestor)) ERR_ATTESTOR_EXISTS)
    (match (as-max-len? (append (var-get attestor-list) attestor) u10)
      updated-list
        (begin
          (var-set attestor-list updated-list)
          (map-set attestor-registry attestor {
            active: true, public-key: public-key, key-version: u1 })
          (print { event: "por-attestor-added", attestor: attestor, key-version: u1 })
          (ok true))
      ERR_REGISTRY_FULL)))

(define-public (rotate-attestor-key (attestor principal) (public-key (buff 33)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len public-key) u33) ERR_UNSUPPORTED_PUBLIC_KEY)
    (match (map-get? attestor-registry attestor)
      registry
        (let ((next-version (+ (get key-version registry) u1)))
          (map-set attestor-registry attestor {
            active: (get active registry), public-key: public-key, key-version: next-version })
          (print { event: "por-attestor-key-rotated", attestor: attestor,
            key-version: next-version })
          (ok true))
      ERR_ATTESTOR_NOT_FOUND)))

(define-public (deactivate-attestor (attestor principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (match (map-get? attestor-registry attestor)
      registry
        (begin
          (map-set attestor-registry attestor (merge registry { active: false }))
          (print { event: "por-attestor-deactivated", attestor: attestor })
          (ok true))
      ERR_ATTESTOR_NOT_FOUND)))

(define-public (set-quorum (new-quorum uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (and (> new-quorum u0) (<= new-quorum MAX_ATTESTORS)) ERR_INVALID_QUORUM)
    (var-set quorum new-quorum)
    (print { event: "por-quorum-updated", quorum: new-quorum })
    (ok true)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

;; Balance and supply are sampled here. Callers cannot supply either value.
(define-public (submit-attestation
    (asset-trait <sip-010-trait>)
    (off-chain-backing uint)
    (as-of-height uint)
    (expiry-height uint)
    (nonce uint)
    (signature (buff 65)))
  (let (
      (asset (contract-of asset-trait))
      (attestor tx-sender)
      (current-height burn-block-height)
      (verifying-contract (contract-principal))
      (registry (unwrap! (map-get? attestor-registry attestor) ERR_INVALID_ATTESTOR))
      (on-chain-balance (unwrap! (contract-call? asset-trait get-balance verifying-contract) ERR_TOKEN_CALL_FAILED))
      (total-supply (unwrap! (contract-call? asset-trait get-total-supply) ERR_TOKEN_CALL_FAILED))
      (snapshot-digest (try! (get-shared-snapshot-digest asset on-chain-balance total-supply
        off-chain-backing as-of-height expiry-height nonce)))
      (envelope-digest (try! (get-attestor-envelope-digest snapshot-digest attestor)))
    )
    (asserts! (get active registry) ERR_INVALID_ATTESTOR)
    (asserts! (observation-window-valid as-of-height expiry-height current-height) ERR_STALE_OBSERVATION)
    (asserts! (is-eq (len signature) u65) ERR_UNSUPPORTED_SIGNATURE)
    (asserts! (is-none (map-get? validated-attestations {
      snapshot-digest: snapshot-digest, attestor: attestor })) ERR_DUPLICATE_ATTESTATION)
    (asserts! (is-none (map-get? used-nonces {
      asset: asset, attestor: attestor, nonce: nonce })) ERR_NONCE_REPLAY)
    (asserts! (secp256k1-verify envelope-digest signature (get public-key registry)) ERR_INVALID_SIGNATURE)

    (match (map-get? reserve-snapshots snapshot-digest)
      stored
        (asserts! (and
          (is-eq (get domain stored) SNAPSHOT_DOMAIN)
          (is-eq (get schema-version stored) SCHEMA_VERSION)
          (is-eq (get network stored) chain-id)
          (is-eq (get verifying-contract stored) verifying-contract)
          (is-eq (get asset stored) asset)
          (is-eq (get on-chain-balance stored) on-chain-balance)
          (is-eq (get total-supply stored) total-supply)
          (is-eq (get off-chain-backing stored) off-chain-backing)
          (is-eq (get as-of-height stored) as-of-height)
          (is-eq (get expiry-height stored) expiry-height)
          (is-eq (get nonce stored) nonce)) ERR_SNAPSHOT_MISMATCH)
      (map-set reserve-snapshots snapshot-digest {
        domain: SNAPSHOT_DOMAIN, schema-version: SCHEMA_VERSION,
        network: chain-id, verifying-contract: verifying-contract, asset: asset,
        on-chain-balance: on-chain-balance, total-supply: total-supply,
        off-chain-backing: off-chain-backing, as-of-height: as-of-height,
        expiry-height: expiry-height, nonce: nonce,
        first-submitted-at: current-height }))

    (map-set used-nonces { asset: asset, attestor: attestor, nonce: nonce } true)
    (map-set validated-attestations {
        snapshot-digest: snapshot-digest, attestor: attestor } {
      envelope-digest: envelope-digest, signature: signature,
      public-key: (get public-key registry),
      key-version: (get key-version registry), submitted-at: current-height })

    (let ((attestation-count (valid-attestation-count snapshot-digest)))
      (if (>= attestation-count (var-get quorum))
        (map-set active-snapshots asset snapshot-digest)
        false)
      (print {
        event: "por-attestation-validated", asset: asset, attestor: attestor,
        snapshot-digest: snapshot-digest, attestation-count: attestation-count,
        activated: (>= attestation-count (var-get quorum)) })
      (ok { snapshot-digest: snapshot-digest,
        attestation-count: attestation-count,
        activated: (>= attestation-count (var-get quorum)) }))))

(define-private (snapshot-metadata-valid
    (snapshot {
      domain: (string-ascii 24), schema-version: uint, network: uint,
      verifying-contract: principal, asset: principal,
      on-chain-balance: uint, total-supply: uint, off-chain-backing: uint,
      as-of-height: uint, expiry-height: uint, nonce: uint,
      first-submitted-at: uint })
    (asset principal))
  (and
    (is-eq (get domain snapshot) SNAPSHOT_DOMAIN)
    (is-eq (get schema-version snapshot) SCHEMA_VERSION)
    (is-eq (get network snapshot) chain-id)
    (is-eq (get verifying-contract snapshot) (contract-principal))
    (is-eq (get asset snapshot) asset)
    (observation-window-valid (get as-of-height snapshot)
      (get expiry-height snapshot) burn-block-height)))

(define-private (snapshot-live-valid
    (snapshot-digest (buff 32))
    (snapshot {
      domain: (string-ascii 24), schema-version: uint, network: uint,
      verifying-contract: principal, asset: principal,
      on-chain-balance: uint, total-supply: uint, off-chain-backing: uint,
      as-of-height: uint, expiry-height: uint, nonce: uint,
      first-submitted-at: uint })
    (asset principal) (live-balance uint) (live-supply uint))
  (and
    (snapshot-metadata-valid snapshot asset)
    (is-eq live-balance (get on-chain-balance snapshot))
    (is-eq live-supply (get total-supply snapshot))
    (covers-supply live-balance (get off-chain-backing snapshot) live-supply)
    (>= (valid-attestation-count snapshot-digest) (var-get quorum))))

(define-public (is-fully-backed (asset-trait <sip-010-trait>))
  (ok (let ((asset (contract-of asset-trait)))
    (match (map-get? active-snapshots asset)
      snapshot-digest
        (match (map-get? reserve-snapshots snapshot-digest)
          snapshot
            (match (contract-call? asset-trait get-balance (contract-principal))
              live-balance
                (match (contract-call? asset-trait get-total-supply)
                  live-supply (snapshot-live-valid snapshot-digest snapshot asset live-balance live-supply)
                  supply-error false)
              balance-error false)
          false)
      false))))

(define-public (get-proof-status (asset-trait <sip-010-trait>))
  (ok (let ((asset (contract-of asset-trait)))
    (match (map-get? active-snapshots asset)
      snapshot-digest
        (match (map-get? reserve-snapshots snapshot-digest)
          snapshot
            (match (contract-call? asset-trait get-balance (contract-principal))
              live-balance
                (match (contract-call? asset-trait get-total-supply)
                  live-supply {
                    fully-backed: (snapshot-live-valid snapshot-digest snapshot asset live-balance live-supply),
                    token-calls-ok: true, snapshot-digest: (some snapshot-digest),
                    attestation-count: (valid-attestation-count snapshot-digest),
                    quorum: (var-get quorum), as-of-height: (get as-of-height snapshot),
                    expiry-height: (get expiry-height snapshot),
                    live-balance-matches: (is-eq live-balance (get on-chain-balance snapshot)),
                    live-supply-matches: (is-eq live-supply (get total-supply snapshot)) }
                  supply-error {
                    fully-backed: false, token-calls-ok: false,
                    snapshot-digest: (some snapshot-digest),
                    attestation-count: (valid-attestation-count snapshot-digest),
                    quorum: (var-get quorum), as-of-height: (get as-of-height snapshot),
                    expiry-height: (get expiry-height snapshot),
                    live-balance-matches: false, live-supply-matches: false })
              balance-error {
                fully-backed: false, token-calls-ok: false,
                snapshot-digest: (some snapshot-digest),
                attestation-count: (valid-attestation-count snapshot-digest),
                quorum: (var-get quorum), as-of-height: (get as-of-height snapshot),
                expiry-height: (get expiry-height snapshot),
                live-balance-matches: false, live-supply-matches: false })
          {
            fully-backed: false, token-calls-ok: false,
            snapshot-digest: (some snapshot-digest), attestation-count: u0,
            quorum: (var-get quorum), as-of-height: u0, expiry-height: u0,
            live-balance-matches: false, live-supply-matches: false })
      {
        fully-backed: false, token-calls-ok: false,
        snapshot-digest: none, attestation-count: u0,
        quorum: (var-get quorum), as-of-height: u0, expiry-height: u0,
        live-balance-matches: false, live-supply-matches: false }))))

;; Diagnostic raw getters are non-authoritative; only the trait-based status
;; functions above can produce a positive reserve decision.
(define-read-only (get-active-snapshot-digest (asset principal))
  (map-get? active-snapshots asset))
(define-read-only (get-snapshot (snapshot-digest (buff 32)))
  (map-get? reserve-snapshots snapshot-digest))
(define-read-only (get-validated-attestation
    (snapshot-digest (buff 32)) (attestor principal))
  (map-get? validated-attestations {
    snapshot-digest: snapshot-digest, attestor: attestor }))
(define-read-only (get-attestor (attestor principal))
  (map-get? attestor-registry attestor))
(define-read-only (get-attestors) (var-get attestor-list))
(define-read-only (get-quorum) (var-get quorum))
(define-read-only (get-protocol-constants)
  { schema-version: SCHEMA_VERSION, max-attestors: MAX_ATTESTORS,
    max-observation-age-blocks: MAX_OBSERVATION_AGE_BLOCKS,
    max-expiry-window-blocks: MAX_EXPIRY_WINDOW_BLOCKS })
