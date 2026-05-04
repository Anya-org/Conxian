;; automation-manager.clar
;; Automation orchestration
;; Remediated April 2026: Dynamic admin fetching via operational-treasury

(define-data-var automation-active bool true)

;; @desc Triggers an automation job by its ID.
;; @param job-id: The unique identifier of the job to trigger.
(define-public (trigger-automation (job-id uint))
  (begin
    (asserts! (var-get automation-active) (err u1000))
    (print { event: "automation-triggered", job-id: job-id })
    (ok true)
  )
)

;; @desc Sets the global active status of the automation engine. Admin only.
;; @param active: Boolean indicating whether automation should be active.
(define-public (set-automation-active (active bool))
  (let (
    (admin (default-to tx-sender (contract-call? .operational-treasury get-protocol-principal "automation-admin")))
  )
    (begin
      (asserts! (is-eq tx-sender admin) (err u1001))
      (var-set automation-active active)
      (ok true)
    )
  )
)
