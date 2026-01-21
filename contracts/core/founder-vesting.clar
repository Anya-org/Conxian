;; contracts/core/founder-vesting.clar
;; BOLT: Refactored for Clarity 4, Nakamoto compatibility, and secure state management.

(define-contract founder-vesting

    (use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

    ;; --- Constants and Errors ---
    (define-constant CONTRACT_OWNER deployer)
    (define-constant ERR_UNAUTHORIZED (err u401))
    (define-constant ERR_NO_VESTING_SCHEDULE (err u404))
    (define-constant ERR_NOTHING_TO_CLAIM (err u405))
    (define-constant ERR_SCHEDULE_EXISTS (err u409))

    ;; --- Data Storage ---
    (define-data-var contract-owner principal deployer)

    (define-map vesting-schedules principal {
      total-amount: uint,
      start-block: uint,
      end-block: uint,
      claimed-amount: uint
    })

    ;; --- Contract Initialization ---
    (define-public (initialize (owner principal))
      (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-owner owner)
        (ok true)
      )
    )

    ;; --- Administrative Functions ---
    (define-public (add-vesting-schedule (beneficiary principal) (total-amount uint) (start-block uint) (end-block uint))
      (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? vesting-schedules beneficiary)) ERR_SCHEDULE_EXISTS)
        (map-set vesting-schedules beneficiary {
          total-amount: total-amount,
          start-block: start-block,
          end-block: end-block,
          claimed-amount: u0
        })
        (ok true)
      )
    )

    ;; --- Beneficiary Functions ---
    (define-public (claim-vested-tokens (token <sip-010-ft-trait>))
      (let (
        (beneficiary tx-sender)
        (schedule (unwrap! (map-get? vesting-schedules beneficiary) ERR_NO_VESTING_SCHEDULE))
        (vested-amount (calculate-vested-amount schedule))
        (claimable-amount (- vested-amount (get claimed-amount schedule)))
      )
        (asserts! (> claimable-amount u0) ERR_NOTHING_TO_CLAIM)

        (try! (as-contract (contract-call? token transfer claimable-amount tx-sender beneficiary none)))

        (map-set vesting-schedules beneficiary
          (merge schedule { claimed-amount: (+ (get claimed-amount schedule) claimable-amount) })
        )
        (ok claimable-amount)
      )
    )

    ;; --- Read-Only Functions ---
    (define-read-only (get-vesting-schedule (beneficiary principal))
      (map-get? vesting-schedules beneficiary)
    )

    (define-read-only (get-claimable-amount (beneficiary principal))
      (match (map-get? vesting-schedules beneficiary)
        schedule
          (let ((vested (calculate-vested-amount schedule)))
            (ok (- vested (get claimed-amount schedule)))
          )
        (ok u0)
      )
    )

    ;; --- Private Helper Functions ---
    (define-private (calculate-vested-amount (schedule {total-amount: uint, start-block: uint, end-block: uint, claimed-amount: uint}))
      (if (< burn-block-height (get start-block schedule))
        u0
        (if (>= burn-block-height (get end-block schedule))
          (get total-amount schedule)
          (/ (* (get total-amount schedule) (- burn-block-height (get start-block schedule))) (- (get end-block schedule) (get start-block schedule)))
        )
      )
    )

)
