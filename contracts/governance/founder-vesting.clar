;; Tier 0 Stub
(define-constant ERR_NOT_IMPLEMENTED (err u9999))
(define-read-only (stub-func)
  (ok true)
)
    )
)

;; Beneficiary Functions
(define-public (claim-vested-tokens (token <sip-010-trait>))
    (let (
        (schedule (unwrap! (map-get? vesting-schedules tx-sender) ERR_NO_VESTING_SCHEDULE))
        (current-block block-height)
        (vested (calculate-vested-amount schedule current-block))
        (claimable (- vested (get claimed-amount schedule)))
    )
        (asserts! (> claimable u0) ERR_NOTHING_TO_CLAIM)
        
        ;; Payout
        (as-contract (contract-call? token transfer claimable tx-sender (get-owner schedule) none))
        
        ;; Update Schedule
        (map-set vesting-schedules tx-sender
            (merge schedule { claimed-amount: vested })
        )
        (ok claimable)
    )
)

;; Helper
(define-private (calculate-vested-amount (schedule {total-amount: uint, start-block: uint, end-block: uint, claimed-amount: uint}) (current-block uint))
    (if (< current-block (get start-block schedule))
        u0
        (if (>= current-block (get end-block schedule))
            (get total-amount schedule)
            (/ (* (get total-amount schedule) (- current-block (get start-block schedule))) 
               (- (get end-block schedule) (get start-block schedule)))
        )
    )
)

(define-private (get-owner (schedule {total-amount: uint, start-block: uint, end-block: uint, claimed-amount: uint}))
    tx-sender ;; Simulating return of beneficiary from map key context if needed, but clarity map-get doesn't give key inside value.
    ;; Actually, beneficiary calls claim, so tx-sender IS beneficiary. recipient is tx-sender.
)
