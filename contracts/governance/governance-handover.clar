;; governance-handover.clar
;; Sovereign handover verification and execution controller.
;;
;; This contract records and verifies the transfer of bootstrap authority to
;; the timelock. It does NOT execute the transfers itself — each target
;; contract must be called by its current owner. This contract witnesses the
;; resulting state and advances an internal handover counter.
;;
;; Handover sequence:
;;   Step 1 — conxian-access contract-owner transferred to .timelock
;;   Step 2 — admin-facade global-admin transferred to .timelock
;;   Step 3 — Verify, seal, and record completion

;; --- Constants ---

(define-constant TARGET_OWNER .timelock)

(define-constant STEP_NONE         u0)
(define-constant STEP_ACCESS       u1)
(define-constant STEP_ADMIN        u2)
(define-constant STEP_SEAL         u3)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED            (err u100))
(define-constant ERR_ALREADY_COMPLETE          (err u101))
(define-constant ERR_WRONG_STEP                (err u102))
(define-constant ERR_ACCESS_NOT_TRANSFERRED    (err u103))
(define-constant ERR_ACCESS_OWNER_READ_FAILED  (err u104))
(define-constant ERR_ADMIN_NOT_TRANSFERRED     (err u105))
(define-constant ERR_STEP_ALREADY_EXECUTED     (err u106))
(define-constant ERR_NOT_INITIALIZED           (err u107))

;; --- State ---

(define-data-var handover-step   uint   STEP_NONE)
(define-data-var handover-sealed bool   false)

;; --- Authorization ---

(define-private (is-authorized)
  (or
    ;; The current conxian-access owner (bootstrap authority)
    (is-eq tx-sender
      (unwrap! (contract-call? .conxian-access get-contract-owner)
        false))
    ;; The timelock (target authority)
    (is-eq tx-sender TARGET_OWNER)
  )
)

(define-private (assert-authorized)
  (asserts! (is-authorized) ERR_NOT_AUTHORIZED)
)

;; --- Read-only verification ---

;; Returns the full handover state for post-state readback.
(define-read-only (get-handover-state)
  (ok {
    step:   (var-get handover-step),
    sealed: (var-get handover-sealed),
    target: TARGET_OWNER
  })
)

;; Verifies the complete handover is finished.
;; Returns (ok true) only when all steps are executed and sealed.
(define-public (verify-full-handover)
  (let
    (
      (step   (var-get handover-step))
      (sealed (var-get handover-sealed))
    )
    (ok (and (is-eq step STEP_SEAL) sealed))
  )
)

;; --- Step execution ---

;; Execute a single handover step. Each step verifies the expected on-chain
;; state before advancing. Only the current authority holder may advance.
(define-public (execute-handover-step (step uint))
  (begin
    ;; Fail closed: handover already sealed
    (asserts! (not (var-get handover-sealed)) ERR_ALREADY_COMPLETE)

    ;; Fail closed: steps must be executed sequentially
    (asserts! (is-eq step (+ (var-get handover-step) u1)) ERR_WRONG_STEP)

    (assert-authorized)

    (if (is-eq step STEP_ACCESS)
      (begin
        ;; Verify conxian-access owner is now the timelock
        (asserts!
          (is-eq (unwrap! (contract-call? .conxian-access get-contract-owner)
                   ERR_ACCESS_OWNER_READ_FAILED)
                 TARGET_OWNER)
          ERR_ACCESS_NOT_TRANSFERRED
        )
        (var-set handover-step STEP_ACCESS)
        (ok true)
      )
      (if (is-eq step STEP_ADMIN)
        (begin
          ;; Verify admin-facade.global-admin has been transferred to timelock.
          ;; We verify this by having the timelock call admin-facade.is-authorized
          ;; with the admin role — if the transfer succeeded, the timelock IS the
          ;; global admin and authorization will succeed.
          (asserts!
            (unwrap! (contract-call? .admin-facade is-authorized u1)
              ERR_ADMIN_NOT_TRANSFERRED)
            ERR_ADMIN_NOT_TRANSFERRED
          )
          (var-set handover-step STEP_ADMIN)
          (ok true)
        )
        ;; STEP_SEAL — final verification and seal
        (begin
          ;; Re-verify both conditions before sealing
          (asserts!
            (is-eq (unwrap! (contract-call? .conxian-access get-contract-owner)
                     ERR_ACCESS_OWNER_READ_FAILED)
                   TARGET_OWNER)
            ERR_ACCESS_NOT_TRANSFERRED
          )
          (asserts!
            (unwrap! (contract-call? .admin-facade is-authorized u1)
              ERR_ADMIN_NOT_TRANSFERRED)
            ERR_ADMIN_NOT_TRANSFERRED
          )
          (var-set handover-step STEP_SEAL)
          (var-set handover-sealed true)
          (ok true)
        )
      )
    )
  )
)

;; --- Revocation (fail-closed) ---

;; Revoke a completed-but-unsealed handover step. Only callable before sealing.
;; Returns the handover to the previous step.
(define-public (revoke-handover-step (step uint))
  (begin
    (asserts! (not (var-get handover-sealed)) ERR_ALREADY_COMPLETE)
    (asserts! (is-eq step (var-get handover-step)) ERR_WRONG_STEP)
    (assert-authorized)
    (var-set handover-step (- step u1))
    (ok true)
  )
)
