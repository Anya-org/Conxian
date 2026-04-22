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
(define-data-var sab-deployer-multisig principal 'ST1NXQXZ2NK3E3FK1F9YMRK1GE3Z6GZ1RK9Z8X7J5)
(define-data-var dao-policy-quorum principal 'ST2REHNS5HFJ3SQ1SJGAZ3M03TZ3X2S4K3S3Z2ZK1)

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
    )
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
    (begin
        (asserts! (is-sab-member) (err u100))
        (var-set current-stage (+ (var-get current-stage) u1))
        (ok (var-get current-stage))
    )
)

;; @desc Set the SAB deployer multisig
(define-public (set-sab-deployer-multisig (new-msig principal))
    (begin
        (asserts! (is-sab-member) (err u100))
        (var-set sab-deployer-multisig new-msig)
        (ok true)
    )
)

;; @desc Set the DAO policy quorum
(define-public (set-dao-policy-quorum (new-quorum principal))
    (begin
        (asserts! (is-sab-member) (err u100))
        (var-set dao-policy-quorum new-quorum)
        (ok true)
    )
)
