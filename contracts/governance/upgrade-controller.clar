;; upgrade-controller.clar
;; On-chain release authorization registry for protocol upgrades.
;;
;; This contract deliberately does not replace target bytecode. It records
;; which implementation hash governance authorized for a target principal,
;; the staged rollout state, and the emergency rollback authorization. A
;; deployment or target contract must consume this registry separately.

(define-constant BPS u10000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_BLOCK_WINDOW u1000000)

(define-constant STATUS_PENDING u0)
(define-constant STATUS_ACTIVATED u1)
(define-constant STATUS_CANCELLED u2)
(define-constant STATUS_ROLLED_BACK u3)

(define-constant ERR_UNAUTHORIZED u1100)
(define-constant ERR_INVALID_HASH u1101)
(define-constant ERR_INVALID_BPS u1102)
(define-constant ERR_INVALID_ETA u1103)
(define-constant ERR_INVALID_ROLLBACK_WINDOW u1104)
(define-constant ERR_PROPOSAL_NOT_FOUND u1105)
(define-constant ERR_PROPOSAL_NOT_PENDING u1106)
(define-constant ERR_ALREADY_ACTIVATED u1107)
(define-constant ERR_ALREADY_CANCELLED u1108)
(define-constant ERR_ALREADY_ROLLED_BACK u1109)
(define-constant ERR_SIGNER_NOT_ENABLED u1110)
(define-constant ERR_DUPLICATE_APPROVAL u1111)
(define-constant ERR_THRESHOLD_NOT_REACHED u1112)
(define-constant ERR_ETA_NOT_REACHED u1113)
(define-constant ERR_STALE_RELEASE u1114)
(define-constant ERR_NO_ACTIVE_RELEASE u1115)
(define-constant ERR_ROLLBACK_EXPIRED u1116)
(define-constant ERR_LAST_SIGNER u1117)
(define-constant ERR_INVALID_THRESHOLD u1118)
(define-constant ERR_SIGNER_STATE u1119)
(define-constant ERR_ARITHMETIC_OVERFLOW u1120)

(define-data-var admin principal tx-sender)
(define-data-var governance principal tx-sender)
(define-data-var initial-signer principal tx-sender)
(define-data-var enabled-signer-count uint u1)
(define-data-var signer-threshold uint u1)
(define-data-var signer-generation uint u0)
(define-data-var next-proposal-id uint u1)

;; The initial signer is implicitly enabled until explicitly overridden in the
;; map. This seeds the registry without a privileged post-deployment action.
(define-map authorized-signers principal bool)

(define-map proposals uint {
  target: principal,
  previous-hash: (buff 32),
  proposed-hash: (buff 32),
  initial-rollout-bps: uint,
  activation-eta: uint,
  rollback-window: uint,
  rollback-deadline: uint,
  activation-approvals: uint,
  rollback-approvals: uint,
  activation-generation: uint,
  rollback-generation: uint,
  activated: bool,
  cancelled: bool,
  rolled-back: bool,
  active-rollout-bps: uint
})

(define-map activation-approvals { proposal-id: uint, generation: uint, signer: principal } bool)
(define-map rollback-approvals { proposal-id: uint, generation: uint, signer: principal } bool)

(define-map active-releases principal {
  proposal-id: uint,
  implementation-hash: (buff 32),
  previous-hash: (buff 32),
  rollout-bps: uint,
  activated-at: uint,
  rollback-deadline: uint,
  rolled-back: bool
})

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-governance-or-admin)
  (or (is-admin) (is-eq tx-sender (var-get governance)))
)

(define-private (is-enabled-signer (signer principal))
  (match (map-get? authorized-signers signer)
    enabled enabled
    (is-eq signer (var-get initial-signer))
  )
)

(define-private (safe-add-blocks (base uint) (window uint))
  (if (> window (- MAX_UINT base))
    none
    (some (+ base window))
  )
)

(define-private (status-of (proposal {
    target: principal,
    previous-hash: (buff 32),
    proposed-hash: (buff 32),
    initial-rollout-bps: uint,
    activation-eta: uint,
    rollback-window: uint,
    rollback-deadline: uint,
    activation-approvals: uint,
    rollback-approvals: uint,
    activation-generation: uint,
    rollback-generation: uint,
    activated: bool,
    cancelled: bool,
    rolled-back: bool,
    active-rollout-bps: uint
  }))
  (if (get cancelled proposal)
    STATUS_CANCELLED
    (if (get rolled-back proposal)
      STATUS_ROLLED_BACK
      (if (get activated proposal) STATUS_ACTIVATED STATUS_PENDING)
    )
  )
)

;; @desc Update the registry administrator.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Set the governance principal allowed to submit and operate releases.
(define-public (set-governance (new-governance principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set governance new-governance)
    (print { event: "upgrade-governance-configured", governance: new-governance })
    (ok true)
  )
)

;; @desc Add or remove an emergency signer and invalidate prior approvals.
(define-public (set-signer (signer principal) (enabled bool))
  (let ((currently-enabled (is-enabled-signer signer)))
    (begin
      (asserts! (is-governance-or-admin) (err ERR_UNAUTHORIZED))
      (if enabled
        (begin
          (asserts! (not currently-enabled) (err ERR_SIGNER_STATE))
          ;; The enabled signer count must not wrap when a signer is added.
          (asserts! (< (var-get enabled-signer-count) MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
          (asserts! (< (var-get signer-generation) MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
          (map-set authorized-signers signer true)
          (var-set enabled-signer-count (+ (var-get enabled-signer-count) u1))
          (var-set signer-generation (+ (var-get signer-generation) u1))
          (print { event: "upgrade-signer-enabled", signer: signer })
          (ok true)
        )
        (begin
          (asserts! currently-enabled (err ERR_SIGNER_STATE))
          (asserts! (> (var-get enabled-signer-count) u1) (err ERR_LAST_SIGNER))
          (asserts! (>= (- (var-get enabled-signer-count) u1) (var-get signer-threshold)) (err ERR_INVALID_THRESHOLD))
          (asserts! (< (var-get signer-generation) MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
          (map-set authorized-signers signer false)
          (var-set enabled-signer-count (- (var-get enabled-signer-count) u1))
          (var-set signer-generation (+ (var-get signer-generation) u1))
          (print { event: "upgrade-signer-disabled", signer: signer })
          (ok true)
        )
      )
    )
  )
)

;; @desc Set the number of distinct signer approvals required and invalidate
;; prior approvals when the threshold changes.
(define-public (set-signer-threshold (threshold uint))
  (begin
    (asserts! (is-governance-or-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> threshold u0) (err ERR_INVALID_THRESHOLD))
    (asserts! (<= threshold (var-get enabled-signer-count)) (err ERR_INVALID_THRESHOLD))
    (if (is-eq threshold (var-get signer-threshold))
      true
      (begin
        (asserts! (< (var-get signer-generation) MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
        (var-set signer-threshold threshold)
        (var-set signer-generation (+ (var-get signer-generation) u1))
      )
    )
    (print { event: "upgrade-signer-threshold-updated", threshold: threshold })
    (ok true)
  )
)

;; @desc Create a release authorization proposal. Hashes are authorization
;; metadata only; no target bytecode is changed by this registry.
(define-public (create-proposal
    (target principal)
    (previous-hash (buff 32))
    (proposed-hash (buff 32))
    (initial-rollout-bps uint)
    (activation-eta uint)
    (rollback-window uint)
  )
  (begin
    (asserts! (is-governance-or-admin) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-eq previous-hash proposed-hash)) (err ERR_INVALID_HASH))
    (asserts! (<= initial-rollout-bps BPS) (err ERR_INVALID_BPS))
    (asserts! (> activation-eta burn-block-height) (err ERR_INVALID_ETA))
    (asserts! (> rollback-window u0) (err ERR_INVALID_ROLLBACK_WINDOW))
    (asserts! (<= rollback-window MAX_BLOCK_WINDOW) (err ERR_INVALID_ROLLBACK_WINDOW))
    (let ((proposal-id (var-get next-proposal-id)))
      (begin
        ;; Proposal identifiers are monotonic; reject the terminal value before
        ;; advancing it so the next identifier cannot wrap.
        (asserts! (< proposal-id MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
        (map-set proposals proposal-id {
          target: target,
          previous-hash: previous-hash,
          proposed-hash: proposed-hash,
          initial-rollout-bps: initial-rollout-bps,
          activation-eta: activation-eta,
          rollback-window: rollback-window,
          rollback-deadline: u0,
          activation-approvals: u0,
          rollback-approvals: u0,
          activation-generation: (var-get signer-generation),
          rollback-generation: (var-get signer-generation),
          activated: false,
          cancelled: false,
          rolled-back: false,
          active-rollout-bps: initial-rollout-bps
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (print {
          event: "upgrade-proposal-created",
          proposal-id: proposal-id,
          target: target,
          previous-hash: previous-hash,
          proposed-hash: proposed-hash,
          activation-eta: activation-eta,
          rollback-window: rollback-window
        })
        (ok proposal-id)
      )
    )
  )
)

;; @desc Add one distinct signer approval for activation.
(define-public (approve-activation (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND))))
    (begin
      (asserts! (is-enabled-signer tx-sender) (err ERR_SIGNER_NOT_ENABLED))
      (asserts! (not (get activated proposal)) (err ERR_ALREADY_ACTIVATED))
      (asserts! (not (get cancelled proposal)) (err ERR_ALREADY_CANCELLED))
      (asserts!
        (is-none (map-get? activation-approvals {
          proposal-id: proposal-id,
          generation: (var-get signer-generation),
          signer: tx-sender
        }))
        (err ERR_DUPLICATE_APPROVAL)
      )
      (let (
          (generation (var-get signer-generation))
          (prior-approvals
            (if (is-eq (get activation-generation proposal) (var-get signer-generation))
              (get activation-approvals proposal)
              u0
            )
          )
        )
        (begin
          (asserts! (< prior-approvals MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
          (map-set activation-approvals {
            proposal-id: proposal-id,
            generation: generation,
            signer: tx-sender
          } true)
          (map-set proposals proposal-id (merge proposal {
            activation-approvals: (+ prior-approvals u1),
            activation-generation: generation
          }))
          (print { event: "upgrade-activation-approved", proposal-id: proposal-id, signer: tx-sender, generation: generation })
          (ok true)
        )
      )
    )
  )
)

;; @desc Activate a fully approved proposal permissionlessly after its ETA.
(define-public (activate (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND))))
    (begin
      (asserts! (not (get activated proposal)) (err ERR_ALREADY_ACTIVATED))
      (asserts! (not (get cancelled proposal)) (err ERR_ALREADY_CANCELLED))
      (asserts! (>= burn-block-height (get activation-eta proposal)) (err ERR_ETA_NOT_REACHED))
      (asserts! (is-eq (get activation-generation proposal) (var-get signer-generation)) (err ERR_THRESHOLD_NOT_REACHED))
      (asserts! (>= (get activation-approvals proposal) (var-get signer-threshold)) (err ERR_THRESHOLD_NOT_REACHED))
      (asserts!
        (match (map-get? active-releases (get target proposal))
          active (is-eq (get implementation-hash active) (get previous-hash proposal))
          true
        )
        (err ERR_STALE_RELEASE)
      )
      (let ((rollback-deadline
          (unwrap!
            (safe-add-blocks burn-block-height (get rollback-window proposal))
            (err ERR_INVALID_ROLLBACK_WINDOW)
          )
        ))
        (begin
          (map-set active-releases (get target proposal) {
            proposal-id: proposal-id,
            implementation-hash: (get proposed-hash proposal),
            previous-hash: (get previous-hash proposal),
            rollout-bps: (get initial-rollout-bps proposal),
            activated-at: burn-block-height,
            rollback-deadline: rollback-deadline,
            rolled-back: false
          })
          (map-set proposals proposal-id (merge proposal {
            activated: true,
            rollback-deadline: rollback-deadline,
            active-rollout-bps: (get initial-rollout-bps proposal)
          }))
          (print {
            event: "upgrade-authorized",
            proposal-id: proposal-id,
            target: (get target proposal),
            implementation-hash: (get proposed-hash proposal),
            rollout-bps: (get initial-rollout-bps proposal),
            rollback-deadline: rollback-deadline
          })
          (ok true)
        )
      )
    )
  )
)

;; @desc Increase the active rollout percentage without decreasing it.
(define-public (update-rollout (proposal-id uint) (new-rollout-bps uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND))))
    (begin
      (asserts! (is-governance-or-admin) (err ERR_UNAUTHORIZED))
      (asserts! (get activated proposal) (err ERR_PROPOSAL_NOT_PENDING))
      (asserts! (not (get rolled-back proposal)) (err ERR_ALREADY_ROLLED_BACK))
      (asserts! (<= new-rollout-bps BPS) (err ERR_INVALID_BPS))
      (asserts! (>= new-rollout-bps (get active-rollout-bps proposal)) (err ERR_INVALID_BPS))
      (let ((active (unwrap! (map-get? active-releases (get target proposal)) (err ERR_NO_ACTIVE_RELEASE))))
        (begin
          (asserts! (is-eq (get proposal-id active) proposal-id) (err ERR_NO_ACTIVE_RELEASE))
          (asserts! (not (get rolled-back active)) (err ERR_ALREADY_ROLLED_BACK))
          (map-set active-releases (get target proposal) (merge active { rollout-bps: new-rollout-bps }))
          (map-set proposals proposal-id (merge proposal { active-rollout-bps: new-rollout-bps }))
          (print {
            event: "upgrade-rollout-updated",
            proposal-id: proposal-id,
            target: (get target proposal),
            rollout-bps: new-rollout-bps
          })
          (ok new-rollout-bps)
        )
      )
    )
  )
)

;; @desc Cancel a proposal before activation.
(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND))))
    (begin
      (asserts! (is-governance-or-admin) (err ERR_UNAUTHORIZED))
      (asserts! (not (get activated proposal)) (err ERR_ALREADY_ACTIVATED))
      (asserts! (not (get cancelled proposal)) (err ERR_ALREADY_CANCELLED))
      (map-set proposals proposal-id (merge proposal { cancelled: true }))
      (print { event: "upgrade-proposal-cancelled", proposal-id: proposal-id })
      (ok true)
    )
  )
)

;; @desc Add one distinct signer approval for an emergency rollback.
(define-public (approve-rollback (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND))))
    (begin
      (asserts! (is-enabled-signer tx-sender) (err ERR_SIGNER_NOT_ENABLED))
      (asserts! (get activated proposal) (err ERR_PROPOSAL_NOT_PENDING))
      (asserts! (not (get rolled-back proposal)) (err ERR_ALREADY_ROLLED_BACK))
      (asserts!
        (is-none (map-get? rollback-approvals {
          proposal-id: proposal-id,
          generation: (var-get signer-generation),
          signer: tx-sender
        }))
        (err ERR_DUPLICATE_APPROVAL)
      )
      (let (
          (generation (var-get signer-generation))
          (prior-approvals
            (if (is-eq (get rollback-generation proposal) (var-get signer-generation))
              (get rollback-approvals proposal)
              u0
            )
          )
        )
        (begin
          (asserts! (< prior-approvals MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
          (map-set rollback-approvals {
            proposal-id: proposal-id,
            generation: generation,
            signer: tx-sender
          } true)
          (map-set proposals proposal-id (merge proposal {
            rollback-approvals: (+ prior-approvals u1),
            rollback-generation: generation
          }))
          (print { event: "upgrade-rollback-approved", proposal-id: proposal-id, signer: tx-sender, generation: generation })
          (ok true)
        )
      )
    )
  )
)

;; @desc Roll back the exact active proposal once, within its rollback window.
(define-public (rollback (proposal-id uint))
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) (err ERR_PROPOSAL_NOT_FOUND)))
      (active (unwrap! (map-get? active-releases (get target proposal)) (err ERR_NO_ACTIVE_RELEASE)))
    )
    (begin
      (asserts! (get activated proposal) (err ERR_PROPOSAL_NOT_PENDING))
      (asserts! (not (get rolled-back proposal)) (err ERR_ALREADY_ROLLED_BACK))
      (asserts! (is-eq (get proposal-id active) proposal-id) (err ERR_NO_ACTIVE_RELEASE))
      (asserts! (not (get rolled-back active)) (err ERR_ALREADY_ROLLED_BACK))
      (asserts! (<= burn-block-height (get rollback-deadline active)) (err ERR_ROLLBACK_EXPIRED))
      (asserts! (is-eq (get rollback-generation proposal) (var-get signer-generation)) (err ERR_THRESHOLD_NOT_REACHED))
      (asserts! (>= (get rollback-approvals proposal) (var-get signer-threshold)) (err ERR_THRESHOLD_NOT_REACHED))
      (map-set active-releases (get target proposal) (merge active {
        implementation-hash: (get previous-hash proposal),
        rollout-bps: u0,
        rolled-back: true
      }))
      (map-set proposals proposal-id (merge proposal {
        rolled-back: true,
        active-rollout-bps: u0
      }))
      (print {
        event: "upgrade-rolled-back",
        proposal-id: proposal-id,
        target: (get target proposal),
        implementation-hash: (get previous-hash proposal)
      })
      (ok true)
    )
  )
)

(define-read-only (get-config)
  {
    admin: (var-get admin),
    governance: (var-get governance),
    initial-signer: (var-get initial-signer),
    enabled-signer-count: (var-get enabled-signer-count),
    signer-threshold: (var-get signer-threshold),
    signer-generation: (var-get signer-generation),
    next-proposal-id: (var-get next-proposal-id)
  }
)

(define-read-only (is-signer-enabled (signer principal))
  (is-enabled-signer signer)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (some (status-of proposal))
    none
  )
)

(define-read-only (get-active-release (target principal))
  (map-get? active-releases target)
)
