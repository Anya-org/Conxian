;; proof-of-reserves.clar
;; Conxian Security: quorum attestations over live-reconciled reserve snapshots.
;;
;; Canonical schema v1 hashing:
;; - uint leaf = the Clarity-native sha256(uint) encoding
;; - domain/network leaves use fixed ASCII byte tags after exact-value checks
;; - fixed 32-byte identities/digests are included directly
;; - ordered fixed-width leaves are grouped and hashed; group hashes are hashed
;;   once more to produce the final 32-byte digest
;; Snapshot leaves: domain, schema-version, chain-id, network, registry-epoch,
;; governance-registered asset identity, observed on-chain balance, total supply,
;; off-chain backing, burn height, and expiry.
;; Envelope leaves: attestation domain, schema-version, snapshot digest,
;; sha256(registered attestor public key), and per-attestor nonce.
;; Each signer signs an envelope, while quorum is counted on the shared snapshot
;; digest so distinct signers do not create unrelated quorum buckets.
;;
;; off-chain-backing excludes the observed balance held by this contract. The
;; invariant on-chain-balance + off-chain-backing >= total-supply is evaluated
;; without addition as backing >= supply - balance when balance is below supply.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_INVALID_SIGNATURE u8001)
(define-constant ERR_STALE_SNAPSHOT u8002)
(define-constant ERR_DUPLICATE_ATTESTATION u8003)
(define-constant ERR_INVALID_SCHEMA u8004)
(define-constant ERR_INVALID_DOMAIN u8005)
(define-constant ERR_INVALID_NETWORK u8006)
(define-constant ERR_INVALID_CHAIN u8007)
(define-constant ERR_FUTURE_SNAPSHOT u8008)
(define-constant ERR_EXPIRED_SNAPSHOT u8009)
(define-constant ERR_REPLAYED_NONCE u8010)
(define-constant ERR_TOKEN_READ_FAILED u8011)
(define-constant ERR_LIVE_STATE_MISMATCH u8012)
(define-constant ERR_UNBACKED_SNAPSHOT u8013)
(define-constant ERR_INVALID_ATTESTOR u8014)
(define-constant ERR_INVALID_NETWORK_CONFIG u8015)
(define-constant ERR_INVALID_ASSET u8016)

(define-constant SNAPSHOT_SCHEMA_VERSION u1)
(define-constant SNAPSHOT_DOMAIN "CONXIAN-POR-SNAPSHOT")
(define-constant ATTESTATION_DOMAIN "CONXIAN-POR-ATTESTATION")
(define-constant SNAPSHOT_DOMAIN_TAG 0x434f4e5849414e2d504f522d534e415053484f54)
(define-constant ATTESTATION_DOMAIN_TAG 0x434f4e5849414e2d504f522d4154544553544154494f4e)
(define-constant MAINNET_TAG 0x6d61696e6e6574)
(define-constant TESTNET_TAG 0x746573746e6574)
(define-constant SIMNET_TAG 0x73696d6e6574)
(define-constant UNCONFIGURED_NETWORK "unset")
(define-constant MAX_SNAPSHOT_AGE u1008)
(define-constant MAX_SNAPSHOT_LIFETIME u1008)
(define-constant MIN_ATTESTATIONS u3)
(define-constant ZERO_PUBKEY 0x000000000000000000000000000000000000000000000000000000000000000000)
(define-constant ZERO_DIGEST 0x0000000000000000000000000000000000000000000000000000000000000000)

;; Registry or network changes advance the epoch and fail closed for every
;; previously promoted snapshot until a new quorum attests under that epoch.
(define-data-var contract-owner principal tx-sender)
(define-data-var governance principal tx-sender)
(define-data-var network-id (string-ascii 8) UNCONFIGURED_NETWORK)
(define-data-var configured-chain-id uint u0)
(define-data-var registry-epoch uint u0)

(define-map attestor-registry principal { active: bool, public-key: (buff 33) })
(define-map registered-attestor-keys (buff 33) principal)

;; The pinned Clarity toolchain cannot serialize principals on chain. This
;; registry binds a token principal to one unique canonical 32-byte identity.
(define-map asset-registry principal { active: bool, identity: (buff 32) })
(define-map registered-asset-identities (buff 32) principal)

(define-map snapshot-candidates
  { asset: principal, snapshot-digest: (buff 32) }
  {
    on-chain-balance: uint,
    total-supply: uint,
    off-chain-backing: uint,
    snapshot-height: uint,
    expires-at: uint,
    registry-epoch: uint,
    attestation-count: uint
  }
)

(define-map snapshot-approvals
  { asset: principal, snapshot-digest: (buff 32), attestor: principal }
  { nonce: uint, envelope-digest: (buff 32) }
)

(define-map used-nonces { attestor: principal, nonce: uint } bool)

;; Only this map is authoritative. Candidate and approval maps are diagnostic.
(define-map accepted-reserves
  principal
  {
    snapshot-digest: (buff 32),
    on-chain-balance: uint,
    total-supply: uint,
    off-chain-backing: uint,
    snapshot-height: uint,
    expires-at: uint,
    registry-epoch: uint,
    attestation-count: uint,
    accepted-at: uint
  }
)

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-governance)
  (or (is-owner) (is-eq tx-sender (var-get governance)))
)

(define-private (advance-registry-epoch)
  (var-set registry-epoch (+ (var-get registry-epoch) u1))
)

(define-private (valid-runtime-network (network (string-ascii 8)))
  (or (is-eq network "mainnet") (is-eq network "testnet") (is-eq network "simnet"))
)

(define-private (reserve-invariant-holds
    (on-chain-balance uint)
    (off-chain-backing uint)
    (total-supply uint)
  )
  (or
    (>= on-chain-balance total-supply)
    (>= off-chain-backing (- total-supply on-chain-balance))
  )
)

(define-private (snapshot-is-current
    (snapshot-height uint)
    (expires-at uint)
    (snapshot-registry-epoch uint)
  )
  (and
    (is-eq snapshot-registry-epoch (var-get registry-epoch))
    (<= snapshot-height burn-block-height)
    (<= (- burn-block-height snapshot-height) MAX_SNAPSHOT_AGE)
    (< burn-block-height expires-at)
  )
)

(define-private (hash-uint (value uint))
  (sha256 value)
)

(define-private (network-hash (network (string-ascii 8)))
  (if (is-eq network "mainnet") (sha256 MAINNET_TAG)
    (if (is-eq network "testnet") (sha256 TESTNET_TAG) (sha256 SIMNET_TAG)))
)

(define-private (compute-snapshot-digest
    (schema-version uint)
    (domain (string-ascii 24))
    (network (string-ascii 8))
    (expected-chain-id uint)
    (snapshot-registry-epoch uint)
    (asset-identity (buff 32))
    (on-chain-balance uint)
    (total-supply uint)
    (off-chain-backing uint)
    (snapshot-height uint)
    (expires-at uint)
  )
  (let (
      (identity-group (sha256 (concat
        (sha256 SNAPSHOT_DOMAIN_TAG)
        (concat (hash-uint schema-version)
          (concat (hash-uint expected-chain-id)
            (concat (network-hash network)
              (concat (hash-uint snapshot-registry-epoch) asset-identity)))))))
      (reserve-group (sha256 (concat
        (hash-uint on-chain-balance)
        (concat (hash-uint total-supply)
          (concat (hash-uint off-chain-backing)
            (concat (hash-uint snapshot-height) (hash-uint expires-at)))))))
    )
    (sha256 (concat identity-group reserve-group))
  )
)

(define-private (compute-envelope-digest
    (schema-version uint)
    (snapshot-digest (buff 32))
    (attestor-identity (buff 32))
    (nonce uint)
  )
  (sha256 (concat
    (sha256 ATTESTATION_DOMAIN_TAG)
    (concat (hash-uint schema-version)
      (concat snapshot-digest
        (concat attestor-identity (hash-uint nonce))))))
)

(define-private (promote-if-newer
    (asset principal)
    (snapshot-digest (buff 32))
    (candidate {
      on-chain-balance: uint,
      total-supply: uint,
      off-chain-backing: uint,
      snapshot-height: uint,
      expires-at: uint,
      registry-epoch: uint,
      attestation-count: uint
    })
  )
  (if (>= (get attestation-count candidate) MIN_ATTESTATIONS)
    (match (map-get? accepted-reserves asset)
      current
        (if (> (get snapshot-height candidate) (get snapshot-height current))
          (begin
            (map-set accepted-reserves asset (merge candidate {
              snapshot-digest: snapshot-digest,
              accepted-at: burn-block-height
            }))
            true
          )
          false
        )
      (begin
        (map-set accepted-reserves asset (merge candidate {
          snapshot-digest: snapshot-digest,
          accepted-at: burn-block-height
        }))
        true
      )
    )
    false
  )
)

(define-public (set-attestor (attestor principal) (public-key (buff 33)))
  (let ((existing-key-owner (map-get? registered-attestor-keys public-key)))
    (begin
      (asserts! (is-governance) (err ERR_UNAUTHORIZED))
      (asserts! (not (is-eq public-key ZERO_PUBKEY)) (err ERR_INVALID_ATTESTOR))
      (asserts! (match existing-key-owner owner (is-eq owner attestor) true) (err ERR_INVALID_ATTESTOR))
      (map-set attestor-registry attestor { active: true, public-key: public-key })
      (map-set registered-attestor-keys public-key attestor)
      (advance-registry-epoch)
      (print { event: "por-attestor-set", attestor: attestor, registry-epoch: (var-get registry-epoch) })
      (ok true)
    )
  )
)

(define-public (remove-attestor (attestor principal))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    (match (map-get? attestor-registry attestor)
      registered (map-set attestor-registry attestor (merge registered { active: false }))
      false
    )
    (advance-registry-epoch)
    (print { event: "por-attestor-removed", attestor: attestor, registry-epoch: (var-get registry-epoch) })
    (ok true)
  )
)

(define-public (set-asset (asset principal) (identity (buff 32)))
  (let ((existing-identity-owner (map-get? registered-asset-identities identity)))
    (begin
      (asserts! (is-governance) (err ERR_UNAUTHORIZED))
      (asserts! (not (is-eq identity ZERO_DIGEST)) (err ERR_INVALID_ASSET))
      (asserts! (match existing-identity-owner owner (is-eq owner asset) true) (err ERR_INVALID_ASSET))
      (map-set asset-registry asset { active: true, identity: identity })
      (map-set registered-asset-identities identity asset)
      (advance-registry-epoch)
      (ok true)
    )
  )
)

(define-public (remove-asset (asset principal))
  (begin
    (asserts! (is-governance) (err ERR_UNAUTHORIZED))
    (match (map-get? asset-registry asset)
      registered (map-set asset-registry asset (merge registered { active: false }))
      false
    )
    (advance-registry-epoch)
    (ok true)
  )
)

(define-public (set-network-id (network (string-ascii 8)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (valid-runtime-network network) (err ERR_INVALID_NETWORK_CONFIG))
    (var-set network-id network)
    (advance-registry-epoch)
    (ok true)
  )
)

(define-public (set-chain-id (new-chain-id uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (> new-chain-id u0) (err ERR_INVALID_CHAIN))
    (var-set configured-chain-id new-chain-id)
    (advance-registry-epoch)
    (ok true)
  )
)

(define-public (set-governance (new-governance principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set governance new-governance)
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; All validation and live SIP-010 reconciliation happens before proof writes.
(define-public (submit-attestation
    (asset <sip-010-trait>)
    (schema-version uint)
    (domain (string-ascii 24))
    (network (string-ascii 8))
    (expected-chain-id uint)
    (snapshot-registry-epoch uint)
    (observed-on-chain-balance uint)
    (observed-total-supply uint)
    (off-chain-backing uint)
    (snapshot-height uint)
    (expires-at uint)
    (nonce uint)
    (signature (buff 65))
  )
  (let (
      (asset-principal (contract-of asset))
      (attestor tx-sender)
      (configured-network (var-get network-id))
      (live-balance (unwrap! (contract-call? asset get-balance (as-contract tx-sender)) (err ERR_TOKEN_READ_FAILED)))
      (live-supply (unwrap! (contract-call? asset get-total-supply) (err ERR_TOKEN_READ_FAILED)))
      (registered (unwrap! (map-get? attestor-registry attestor) (err ERR_UNAUTHORIZED)))
      (registered-asset (unwrap! (map-get? asset-registry asset-principal) (err ERR_INVALID_ASSET)))
    )
    (begin
      (asserts! (get active registered) (err ERR_UNAUTHORIZED))
      (asserts! (get active registered-asset) (err ERR_INVALID_ASSET))
      (asserts! (is-eq schema-version SNAPSHOT_SCHEMA_VERSION) (err ERR_INVALID_SCHEMA))
      (asserts! (is-eq domain SNAPSHOT_DOMAIN) (err ERR_INVALID_DOMAIN))
      (asserts! (not (is-eq configured-network UNCONFIGURED_NETWORK)) (err ERR_INVALID_NETWORK))
      (asserts! (is-eq network configured-network) (err ERR_INVALID_NETWORK))
      (asserts! (valid-runtime-network network) (err ERR_INVALID_NETWORK))
      (asserts! (> (var-get configured-chain-id) u0) (err ERR_INVALID_CHAIN))
      (asserts! (is-eq expected-chain-id (var-get configured-chain-id)) (err ERR_INVALID_CHAIN))
      (asserts! (is-eq snapshot-registry-epoch (var-get registry-epoch)) (err ERR_INVALID_ATTESTOR))
      (asserts! (<= snapshot-height burn-block-height) (err ERR_FUTURE_SNAPSHOT))
      (asserts! (<= (- burn-block-height snapshot-height) MAX_SNAPSHOT_AGE) (err ERR_STALE_SNAPSHOT))
      (asserts! (> expires-at burn-block-height) (err ERR_EXPIRED_SNAPSHOT))
      (asserts! (>= expires-at snapshot-height) (err ERR_EXPIRED_SNAPSHOT))
      (asserts! (<= (- expires-at snapshot-height) MAX_SNAPSHOT_LIFETIME) (err ERR_EXPIRED_SNAPSHOT))
      (asserts! (is-eq observed-on-chain-balance live-balance) (err ERR_LIVE_STATE_MISMATCH))
      (asserts! (is-eq observed-total-supply live-supply) (err ERR_LIVE_STATE_MISMATCH))
      (asserts! (reserve-invariant-holds live-balance off-chain-backing live-supply) (err ERR_UNBACKED_SNAPSHOT))
      (asserts! (is-none (map-get? used-nonces { attestor: attestor, nonce: nonce })) (err ERR_REPLAYED_NONCE))
      (let (
          (snapshot-digest (compute-snapshot-digest
            schema-version domain network expected-chain-id snapshot-registry-epoch
            (get identity registered-asset) live-balance live-supply off-chain-backing snapshot-height expires-at))
          (envelope-digest (compute-envelope-digest
            schema-version snapshot-digest (sha256 (get public-key registered)) nonce))
          (approval-key { asset: asset-principal, snapshot-digest: snapshot-digest, attestor: attestor })
        )
        (begin
          (asserts! (is-none (map-get? snapshot-approvals approval-key)) (err ERR_DUPLICATE_ATTESTATION))
          (asserts! (secp256k1-verify envelope-digest signature (get public-key registered)) (err ERR_INVALID_SIGNATURE))
          (let (
              (candidate (default-to {
                  on-chain-balance: live-balance,
                  total-supply: live-supply,
                  off-chain-backing: off-chain-backing,
                  snapshot-height: snapshot-height,
                  expires-at: expires-at,
                  registry-epoch: snapshot-registry-epoch,
                  attestation-count: u0
                } (map-get? snapshot-candidates { asset: asset-principal, snapshot-digest: snapshot-digest })))
              (updated-candidate (merge candidate { attestation-count: (+ (get attestation-count candidate) u1) }))
            )
            (map-set used-nonces { attestor: attestor, nonce: nonce } true)
            (map-set snapshot-approvals approval-key { nonce: nonce, envelope-digest: envelope-digest })
            (map-set snapshot-candidates { asset: asset-principal, snapshot-digest: snapshot-digest } updated-candidate)
            (let ((promoted (promote-if-newer asset-principal snapshot-digest updated-candidate)))
              (print {
                event: "por-attestation-accepted",
                asset: asset-principal,
                snapshot-digest: snapshot-digest,
                attestor: attestor,
                attestation-count: (get attestation-count updated-candidate),
                promoted: promoted
              })
              (ok promoted)
            )
          )
        )
      )
    )
  )
)

;; Canonical external signing helpers.
(define-read-only (get-snapshot-digest
    (schema-version uint)
    (domain (string-ascii 24))
    (network (string-ascii 8))
    (expected-chain-id uint)
    (snapshot-registry-epoch uint)
    (asset-identity (buff 32))
    (on-chain-balance uint)
    (total-supply uint)
    (off-chain-backing uint)
    (snapshot-height uint)
    (expires-at uint)
  )
  (compute-snapshot-digest schema-version domain network expected-chain-id snapshot-registry-epoch
    asset-identity on-chain-balance total-supply off-chain-backing snapshot-height expires-at)
)

(define-read-only (get-attestation-digest
    (schema-version uint)
    (snapshot-digest (buff 32))
    (attestor-identity (buff 32))
    (nonce uint)
  )
  (compute-envelope-digest schema-version snapshot-digest attestor-identity nonce)
)

;; Dynamic trait calls are conservatively classified as potentially writing by
;; the pinned Clarity analyzer, even when invoking SIP-010 read-only methods.
;; Therefore live reconciliation is exposed as a public, non-mutating check
;; that can be transaction-simulated. It fails closed on every error/drift.
(define-private (check-live-proof (asset <sip-010-trait>))
  (let ((asset-principal (contract-of asset)))
    (match (map-get? accepted-reserves asset-principal)
      proof
        (and
          (>= (get attestation-count proof) MIN_ATTESTATIONS)
          (snapshot-is-current (get snapshot-height proof) (get expires-at proof) (get registry-epoch proof))
          (reserve-invariant-holds (get on-chain-balance proof) (get off-chain-backing proof) (get total-supply proof))
          (match (contract-call? asset get-balance (as-contract tx-sender))
            live-balance
              (and
                (is-eq live-balance (get on-chain-balance proof))
                (match (contract-call? asset get-total-supply)
                  live-supply (is-eq live-supply (get total-supply proof))
                  read-error false
                )
              )
            read-error false
          )
        )
      false
    )
  )
)

(define-public (is-fully-backed (asset <sip-010-trait>))
  (ok (check-live-proof asset))
)

(define-public (get-reserve-ratio (asset <sip-010-trait>))
  (ok (if (check-live-proof asset) u10000 u0))
)

(define-public (get-proof-status (asset <sip-010-trait>))
  (let ((asset-principal (contract-of asset)))
    (match (map-get? accepted-reserves asset-principal)
      proof (ok {
        fully-backed: (check-live-proof asset),
        reserve-ratio: (if (check-live-proof asset) u10000 u0),
        snapshot-digest: (get snapshot-digest proof),
        attestation-count: (get attestation-count proof),
        snapshot-height: (get snapshot-height proof),
        expires-at: (get expires-at proof),
        registry-epoch: (get registry-epoch proof),
        is-stale: (not (snapshot-is-current (get snapshot-height proof) (get expires-at proof) (get registry-epoch proof)))
      })
      (ok {
        fully-backed: false,
        reserve-ratio: u0,
        snapshot-digest: ZERO_DIGEST,
        attestation-count: u0,
        snapshot-height: u0,
        expires-at: u0,
        registry-epoch: u0,
        is-stale: true
      })
    )
  )
)

(define-read-only (get-accepted-reserve (asset principal))
  (map-get? accepted-reserves asset)
)

(define-read-only (get-snapshot-candidate (asset principal) (snapshot-digest (buff 32)))
  (map-get? snapshot-candidates { asset: asset, snapshot-digest: snapshot-digest })
)

(define-read-only (get-attestation (asset principal) (snapshot-digest (buff 32)) (attestor principal))
  (map-get? snapshot-approvals { asset: asset, snapshot-digest: snapshot-digest, attestor: attestor })
)

(define-read-only (get-attestor (attestor principal))
  (map-get? attestor-registry attestor)
)

(define-read-only (get-asset (asset principal))
  (map-get? asset-registry asset)
)

(define-read-only (get-domain-config)
  {
    schema-version: SNAPSHOT_SCHEMA_VERSION,
    snapshot-domain: SNAPSHOT_DOMAIN,
    attestation-domain: ATTESTATION_DOMAIN,
    network: (var-get network-id),
    chain-id: (var-get configured-chain-id),
    registry-epoch: (var-get registry-epoch),
    minimum-attestations: MIN_ATTESTATIONS,
    maximum-age: MAX_SNAPSHOT_AGE,
    maximum-lifetime: MAX_SNAPSHOT_LIFETIME
  }
)
