;; automation-manager.clar
;; Automation orchestration

(define-data-var automation-active bool true)
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

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
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1001))
    (var-set automation-active active)
    (ok true)
  )
)
