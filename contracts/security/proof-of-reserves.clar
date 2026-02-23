;; proof-of-reserves.clar
;; Conxian Security: Proof of Reserves for asset backing verification
;; Provides transparency and auditability for treasury holdings
;;
;; REPAIRED: Full implementation of proof of reserves with oracle attestation

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_INVALID_PROOF u8001)
(define-constant ERR_STALE_PROOF u8002)
(define-constant ERR_PROOF_EXISTS u8003)

;; Validity period for proofs (7 days in seconds)
(define-constant PROOF_VALIDITY_PERIOD u604800)

;; Minimum required attestations
(define-constant MIN_ATTESTATIONS u3)

;; Data Vars
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var oracle-aggregator principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Authorized attestors (oracles/auditors)
(define-map authorized-attestors principal bool)

;; Asset tracking: asset-principal -> {total-supply, last-proof}
(define-map asset-reserves
    principal
    {
        total-supply: uint,
        on-chain-balance: uint,
        off-chain-backing: uint,
        last-update: uint,
        attestation-count: uint
    }
)

;; Individual attestations: asset -> attestor -> {amount, timestamp}
(define-map attestations
    { asset: principal, attestor: principal }
    {
        amount: uint,
        timestamp: uint,
        signature: (buff 64)
    }
)

;; Events
(define-private (emit-reserves-updated (asset principal) (amount uint))
    (print {
        event: "reserves-updated",
        asset: asset,
        amount: amount,
        timestamp: burn-block-height
    })
)

(define-private (emit-attestation-received (asset principal) (attestor principal) (amount uint))
    (print {
        event: "attestation-received",
        asset: asset,
        attestor: attestor,
        amount: amount,
        timestamp: burn-block-height
    })
)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-attestor)
    (default-to false (map-get? authorized-attestors tx-sender))
)

;; @desc Add an authorized attestor
(define-public (add-attestor (attestor principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (map-set authorized-attestors attestor true)
        (print {
            event: "attestor-added",
            attestor: attestor,
            timestamp: burn-block-height
        })
        (ok true)
    )
)

;; @desc Remove an authorized attestor
(define-public (remove-attestor (attestor principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (map-delete authorized-attestors attestor)
        (print {
            event: "attestor-removed",
            attestor: attestor,
            timestamp: burn-block-height
        })
        (ok true)
    )
)

;; @desc Submit an attestation for asset reserves
(define-public (submit-attestation
    (asset principal)
    (off-chain-amount uint)
    (signature (buff 64))
  )
    (let (
        (current-time burn-block-height)
        (attestor tx-sender)
      )
        ;; Verify attestor is authorized
        (asserts! (is-authorized-attestor) (err ERR_UNAUTHORIZED))
        
        ;; Store attestation
        (map-set attestations { asset: asset, attestor: attestor } {
            amount: off-chain-amount,
            timestamp: current-time,
            signature: signature
        })
        
        (emit-attestation-received asset attestor off-chain-amount)
        
        ;; Update reserve data
        (match (map-get? asset-reserves asset)
            existing-data
            (map-set asset-reserves asset (merge existing-data {
                off-chain-backing: off-chain-amount,
                last-update: current-time,
                attestation-count: (+ (get attestation-count existing-data) u1)
            }))
            ;; First attestation for this asset
            (map-set asset-reserves asset {
                total-supply: u0, ;; Will be updated by sync
                on-chain-balance: u0,
                off-chain-backing: off-chain-amount,
                last-update: current-time,
                attestation-count: u1
            })
        )
        
        (ok true)
    )
)

;; @desc Sync on-chain balance for an asset
(define-public (sync-on-chain-balance (asset <sip-010-trait>))
    (let (
        (asset-principal (contract-of asset))
        (balance (unwrap-panic (contract-call? asset get-balance (as-contract tx-sender))))
        (total-supply (unwrap-panic (contract-call? asset get-total-supply)))
      )
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        
        (match (map-get? asset-reserves asset-principal)
            existing-data
            (map-set asset-reserves asset-principal (merge existing-data {
                on-chain-balance: balance,
                total-supply: total-supply,
                last-update: burn-block-height
            }))
            ;; First sync for this asset
            (map-set asset-reserves asset-principal {
                total-supply: total-supply,
                on-chain-balance: balance,
                off-chain-backing: u0,
                last-update: burn-block-height,
                attestation-count: u0
            })
        )
        
        (emit-reserves-updated asset-principal balance)
        (ok true)
    )
)

;; @desc Verify if reserves are fully backed
(define-read-only (is-fully-backed (asset principal))
    (match (map-get? asset-reserves asset)
        data
        (and
            (>= (get off-chain-backing data) (get total-supply data))
            (>= (get attestation-count data) MIN_ATTESTATIONS)
            (< (- burn-block-height (get last-update data)) PROOF_VALIDITY_PERIOD)
        )
        false
    )
)

;; @desc Get reserve ratio (basis points, 10000 = 100%)
(define-read-only (get-reserve-ratio (asset principal))
    (match (map-get? asset-reserves asset)
        data
        (let ((supply (get total-supply data)))
            (if (> supply u0)
                (/ (* (get off-chain-backing data) u10000) supply)
                u0
            )
        )
        u0
    )
)

;; Admin Functions
(define-public (set-oracle-aggregator (new-aggregator principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set oracle-aggregator new-aggregator)
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

;; Read-only Functions
(define-read-only (get-reserve-data (asset principal))
    (map-get? asset-reserves asset)
)

(define-read-only (get-attestation (asset principal) (attestor principal))
    (map-get? attestations { asset: asset, attestor: attestor })
)

(define-read-only (is-attestor (principal principal))
    (default-to false (map-get? authorized-attestors principal))
)

(define-read-only (get-proof-status (asset principal))
    (match (map-get? asset-reserves asset)
        data
        {
            fully-backed: (is-fully-backed asset),
            reserve-ratio: (get-reserve-ratio asset),
            attestation-count: (get attestation-count data),
            last-update: (get last-update data),
            is-stale: (> (- burn-block-height (get last-update data)) PROOF_VALIDITY_PERIOD)
        }
        {
            fully-backed: false,
            reserve-ratio: u0,
            attestation-count: u0,
            last-update: u0,
            is-stale: true
        }
    )
)
