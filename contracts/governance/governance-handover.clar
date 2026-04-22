;; governance-handover.clar
;; @desc Governance Handover Contract: Manages the transition from SAB control to DAO control.
;; @dev Tracks handoff stages and ensures atomic transitions.
;; @constant TARGET_OWNER The final owner after handoff is complete (DAO-controlled timelock).
;; @constant STAGE_SAB_CUSTODY Stage 2: SAB-controlled custody.
;; @constant STAGE_DAO_POLICY_GATE Stage 4: DAO policy quorum gate.
;; @constant STAGE_COMPLETE Final stage: Full DAO control.

(define-constant TARGET_OWNER .timelock)
(define-constant STAGE_BOOTSTRAP u0)
(define-constant STAGE_SAB_CUSTODY u1)
(define-constant STAGE_SAB_DEPLOYER_MULTISIG u2)
(define-constant STAGE_DAO_POLICY_GATE u3)
(define-constant STAGE_COMPLETE u4)

(define-data-var current-stage uint STAGE_BOOTSTRAP)
(define-data-var sab-deployer-multisig principal tx-sender)
(define-data-var dao-policy-quorum principal tx-sender)
(define-data-var admin principal tx-sender)

(define-data-var dao-timelock-start uint u0)

(define-map handoff-steps
    uint
    { name: (string-ascii 50), completed: bool, timestamp: uint }
)

;; @desc Get the current handoff stage
(define-read-only (get-current-stage)
    (ok (var-get current-stage))
)

;; @desc Get the target owner (final DAO timelock)
(define-read-only (get-target-owner)
    (ok TARGET_OWNER)
)

;; @desc Get handoff step status
(define-read-only (get-step-status (step uint))
    (ok (map-get? handoff-steps step))
)

(define-private (is-sab-member)
    (or
        (is-eq tx-sender (var-get sab-deployer-multisig))
        (is-eq tx-sender (var-get dao-policy-quorum))
        (is-admin)
    )
)

(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

;; @desc Verify that all pre-conditions for full handover are met
(define-public (verify-full-handover)
    (let
        (
            (stage (var-get current-stage))
        )
        (ok (and
            (>= stage STAGE_COMPLETE)
            (is-sab-member)
        ))
    )
)

;; @desc Execute a specific handoff step
;; @param step The step number to execute
(define-public (execute-handover-step (step uint))
    (begin
        (asserts! (is-sab-member) (err u100))
        (map-set handoff-steps step {
            name: (get-step-name step),
            completed: true,
            timestamp: burn-block-height
        })
        (ok true)
    )
)

(define-private (get-step-name (step uint))
    (if (is-eq step STAGE_BOOTSTRAP)
        "Bootstrap"
        (if (is-eq step STAGE_SAB_CUSTODY)
            "SAB Custody"
            (if (is-eq step STAGE_SAB_DEPLOYER_MULTISIG)
                "SAB Deployer Multisig"
                (if (is-eq step STAGE_DAO_POLICY_GATE)
                    "DAO Policy Gate"
                    "Complete"
                )
            )
        )
    )
)

;; @desc Advance to the next stage
(define-public (advance-stage)
    (let (
        (stage (var-get current-stage))
        (next-stage (+ stage u1))
    )
        (begin
            (asserts! (is-sab-member) (err u100))
            
            ;; If moving to DAO Policy Gate, start the 144-block timelock
            (if (is-eq next-stage STAGE_DAO_POLICY_GATE)
                (var-set dao-timelock-start burn-block-height)
                true
            )
            
            ;; If moving to COMPLETE, enforce the 144-block delay
            (if (is-eq next-stage STAGE_COMPLETE)
                (asserts! (>= burn-block-height (+ (var-get dao-timelock-start) u144)) (err u101))
                true
            )
            
            (var-set current-stage next-stage)
            (ok next-stage)
        )
    )
)

;; @desc Set the SAB deployer multisig
(define-public (set-sab-deployer-multisig (new-msig principal))
    (begin
        (asserts! (is-admin) (err u100))
        (var-set sab-deployer-multisig new-msig)
        (ok true)
    )
)

;; @desc Set the DAO policy quorum
(define-public (set-dao-policy-quorum (new-quorum principal))
    (begin
        (asserts! (is-admin) (err u100))
        (var-set dao-policy-quorum new-quorum)
        (ok true)
    )
)

;; @desc Set the admin
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin) (err u100))
        (var-set admin new-admin)
        (ok true)
    )
)

;; @desc Get current config
(define-read-only (get-config)
    (ok {
        sab-deployer-multisig: (var-get sab-deployer-multisig),
        dao-policy-quorum: (var-get dao-policy-quorum),
        admin: (var-get admin)
    })
)
