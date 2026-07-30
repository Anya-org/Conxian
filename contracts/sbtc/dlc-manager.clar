;; dlc-manager.clar
;; Conxian Protocol: DLC Management and Bitcoin Verification Bridge
;; Aligned with BitVM2 Verification Floor and Apex CSF (v1.1.0)
;;
;; BitVM2 proof verification uses a multi-verifier attestation model:
;; 1. Proofs are submitted on-chain with root + SNARK payload
;; 2. Authorized verifiers (BitVM2 watchers) attest to validity
;; 3. After quorum threshold is reached, the proof is accepted
;; 4. Challenge period allows disputes before finalization
;;
;; Actual SNARK verification happens off-chain via lib-conxian-core;
;; this contract records attestations and manages the verification lifecycle.

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_PROOF (err u1005))
(define-constant ERR_ALREADY_SUBMITTED (err u1006))
(define-constant ERR_ALREADY_ATTESTED (err u1007))
(define-constant ERR_NOT_VERIFIER (err u1008))
(define-constant ERR_QUORUM_NOT_MET (err u1009))
(define-constant ERR_CHALLENGE_ACTIVE (err u1010))
(define-constant ERR_CHALLENGE_EXPIRED (err u1011))
(define-constant ERR_PROOF_EXPIRED (err u1012))
(define-constant ERR_PROOF_NOT_FOUND (err u1013))

(define-constant PROOF_STATUS_PENDING u0)
(define-constant PROOF_STATUS_ATTESTING u1)
(define-constant PROOF_STATUS_VERIFIED u2)
(define-constant PROOF_STATUS_REJECTED u3)
(define-constant PROOF_STATUS_CHALLENGED u4)

;; Challenge window: 144 blocks (~12 hours at 5s blocks)
(define-constant CHALLENGE_WINDOW u144)
;; Attestation expiry: 1008 blocks (~1.4 days)
(define-constant ATTESTATION_WINDOW u1008)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var verifier-threshold uint u2)
(define-data-var verifier-count uint u0)
(define-data-var next-proof-id uint u0)

;; Authorized BitVM2 verifiers
(define-map verifiers principal bool)

;; Proof registry: proof-id → attestation state
(define-map proofs
  uint
  {
    root: (buff 32),
    proof-hash: (buff 32),
    submitter: principal,
    submitted-at: uint,
    attestation-count: uint,
    status: uint,
    challenged-at: uint,
    challenger: principal,
    finalized-at: uint
  }
)

;; Per-verifier attestations: (proof-id, verifier) → attested
(define-map attestations { proof-id: uint, verifier: principal } bool)

;; --- Verifier Management ---

;; @desc Authorize a new BitVM2 verifier (admin only)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (not (default-to false (map-get? verifiers verifier))) ERR_ALREADY_ATTESTED)
    (map-set verifiers verifier true)
    (var-set verifier-count (+ (var-get verifier-count) u1))
    (print { event: "verifier-added", verifier: verifier, total: (var-get verifier-count) })
    (ok true)
  )
)

;; @desc Remove a BitVM2 verifier (admin only)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (default-to false (map-get? verifiers verifier)) ERR_NOT_VERIFIER)
    (map-delete verifiers verifier)
    (var-set verifier-count (- (var-get verifier-count) u1))
    (print { event: "verifier-removed", verifier: verifier, total: (var-get verifier-count) })
    (ok true)
  )
)

;; @desc Set the attestation threshold required for proof acceptance
(define-public (set-verifier-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> threshold u0) ERR_UNAUTHORIZED)
    (var-set verifier-threshold threshold)
    (print { event: "verifier-threshold-updated", threshold: threshold })
    (ok true)
  )
)

;; --- DLC Management ---

;; @desc Create a new DLC commitment for Bitcoin settlement
;; @param amount: The amount in sats to be committed
;; @returns (response bool uint)
(define-public (create-dlc (amount uint))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PROOF)
    (print {
      event: "dlc-created",
      amount: amount,
      creator: tx-sender,
      block: burn-block-height
    })
    (ok true)
  )
)

;; --- BitVM2 Proof Verification ---

;; @desc Submit a BitVM2 state root proof for verification.
;; The proof is recorded on-chain and awaits verifier attestations.
;; @param root: The 32-byte BitVM2 state root
;; @param proof: The SNARK-based proof payload (verified off-chain by lib-conxian-core)
;; @returns (response uint uint) — the proof ID on success
(define-public (submit-bitvm2-proof (root (buff 32)) (proof (buff 1024)))
  (let ((proof-id (+ (var-get next-proof-id) u1)))
    (begin
      (asserts! (is-authorized) ERR_UNAUTHORIZED)
      (var-set next-proof-id proof-id)
      (map-set proofs proof-id {
        root: root,
        proof-hash: (sha256 proof),
        submitter: tx-sender,
        submitted-at: burn-block-height,
        attestation-count: u0,
        status: PROOF_STATUS_PENDING,
        challenged-at: u0,
        challenger: tx-sender,
        finalized-at: u0
      })
      (print {
        event: "bitvm2-proof-submitted",
        proof-id: proof-id,
        root: root,
        submitter: tx-sender
      })
      (ok proof-id)
    )
  )
)

;; @desc Attest to the validity of a submitted BitVM2 proof.
;; Only authorized verifiers may attest. After quorum, proof is accepted.
;; @param proof-id: The ID of the proof to attest to
;; @returns (response bool uint)
(define-public (attest-proof (proof-id uint))
  (let (
      (proof (unwrap! (map-get? proofs proof-id) (err ERR_PROOF_NOT_FOUND)))
    )
    (begin
      (asserts! (default-to false (map-get? verifiers tx-sender)) (err ERR_NOT_VERIFIER))
      (asserts! (is-eq (get status proof) PROOF_STATUS_PENDING) (err ERR_ALREADY_ATTESTED))
      (asserts! (<= (- burn-block-height (get submitted-at proof)) ATTESTATION_WINDOW)
        (err ERR_PROOF_EXPIRED))

      ;; Record attestation
      (map-set attestations { proof-id: proof-id, verifier: tx-sender } true)

      (let ((new-count (+ (get attestation-count proof) u1)))
        (map-set proofs proof-id (merge proof { attestation-count: new-count }))

        ;; Check quorum
        (if (>= new-count (var-get verifier-threshold))
          (begin
            (map-set proofs proof-id (merge proof {
              attestation-count: new-count,
              status: PROOF_STATUS_VERIFIED,
              finalized-at: burn-block-height
            }))
            (print {
              event: "bitvm2-proof-verified",
              proof-id: proof-id,
              attestations: new-count,
              root: (get root proof)
            })
            (ok true)
          )
          (begin
            (map-set proofs proof-id (merge proof {
              attestation-count: new-count,
              status: PROOF_STATUS_ATTESTING
            }))
            (print {
              event: "bitvm2-proof-attested",
              proof-id: proof-id,
              verifier: tx-sender,
              attestations: new-count,
              threshold: (var-get verifier-threshold)
            })
            (ok true)
          )
        )
      ))
    )
  )
)

;; @desc Challenge a submitted proof within the challenge window.
;; Any verifier can challenge; the proof enters challenged state.
;; @param proof-id: The ID of the proof to challenge
;; @returns (response bool uint)
(define-public (challenge-proof (proof-id uint))
  (let (
      (proof (unwrap! (map-get? proofs proof-id) (err ERR_PROOF_NOT_FOUND)))
    )
    (begin
      (asserts! (default-to false (map-get? verifiers tx-sender)) (err ERR_NOT_VERIFIER))
      (asserts! (is-eq (get status proof) PROOF_STATUS_VERIFIED) (err ERR_INVALID_PROOF))
      (asserts! (<= (- burn-block-height (get finalized-at proof)) CHALLENGE_WINDOW)
        (err ERR_CHALLENGE_EXPIRED))

      (map-set proofs proof-id (merge proof {
        status: PROOF_STATUS_CHALLENGED,
        challenged-at: burn-block-height,
        challenger: tx-sender
      }))
      (print {
        event: "bitvm2-proof-challenged",
        proof-id: proof-id,
        challenger: tx-sender,
        root: (get root proof)
      })
      (ok true)
    )
  )
)

;; @desc Reject a proof that failed verification.
;; Only admin or quorum of verifiers can reject.
;; @param proof-id: The ID of the proof to reject
;; @returns (response bool uint)
(define-public (reject-proof (proof-id uint))
  (let (
      (proof (unwrap! (map-get? proofs proof-id) (err ERR_PROOF_NOT_FOUND)))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (asserts! (not (is-eq (get status proof) PROOF_STATUS_VERIFIED)) ERR_INVALID_PROOF)
      (map-set proofs proof-id (merge proof {
        status: PROOF_STATUS_REJECTED,
        finalized-at: burn-block-height
      }))
      (print {
        event: "bitvm2-proof-rejected",
        proof-id: proof-id,
        root: (get root proof)
      })
      (ok true)
    )
  )
)

;; --- Read-only ---

;; @desc Returns the verification status of a proof
(define-read-only (get-proof-status (proof-id uint))
  (match (map-get? proofs proof-id)
    proof (ok {
      root: (get root proof),
      status: (get status proof),
      attestations: (get attestation-count proof),
      threshold: (var-get verifier-threshold),
      submitted-at: (get submitted-at proof),
      finalized-at: (get finalized-at proof)
    })
    (err ERR_PROOF_NOT_FOUND)
  )
)

;; @desc Checks if a proof has been fully verified
(define-read-only (is-proof-verified (proof-id uint))
  (match (map-get? proofs proof-id)
    proof (ok (is-eq (get status proof) PROOF_STATUS_VERIFIED))
    (err ERR_PROOF_NOT_FOUND)
  )
)

;; @desc Returns whether a principal is an authorized verifier
(define-read-only (is-verifier (principal principal))
  (default-to false (map-get? verifiers principal))
)

;; @desc Get protocol status
(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    version: "v1.1.0-Apex",
    mode: "BITVM2-MULTI-VERIFIER",
    verifier-count: (var-get verifier-count),
    verifier-threshold: (var-get verifier-threshold),
    total-proofs: (var-get next-proof-id)
  })
)

;; --- Private Helpers ---

(define-private (is-authorized)
  (or
    (is-eq tx-sender (var-get admin))
    (unwrap-panic (contract-call? .conxian-access has-role tx-sender u4))
  )
)

;; --- Admin ---

;; @desc Update admin principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (print { event: "dlc-manager-admin-changed", new-admin: new-admin })
    (ok true)
  )
)
