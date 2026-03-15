;; founder-vesting.clar
;; Conxian Protocol Standard Contract

;; contracts/core/founder-vesting.clar
;; BOLT: Refactored for Clarity 4, Nakamoto compatibility, and secure state management.
;; Migrated to burn-block-height for second-precision vesting.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants and Errors ---
(define-constant CONTRACT_OWNER 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_NO_VESTING_SCHEDULE u404)
(define-constant ERR_NOTHING_TO_CLAIM u405)
(define-constant ERR_SCHEDULE_EXISTS u409)

;; --- Data Storage ---
(define-data-var contract-owner principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var vesting-start uint u0)

(define-map vesting-schedules principal {
  total-amount: uint,
  start-time: uint,
  end-time: uint,
  claimed-amount: uint
})

;; --- Contract Initialization ---

;; @desc Initialize
;; @returns (response bool uint)
(define-public (initialize (owner principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (var-set contract-owner owner)
    (var-set vesting-start burn-block-height)
    (ok true)
  )
)

;; --- Administrative Functions ---

;; @desc Add vesting schedule
;; @returns (response bool uint)
(define-public (add-vesting-schedule (beneficiary principal) (total-amount uint) (start-time uint) (end-time uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? vesting-schedules beneficiary)) (err ERR_SCHEDULE_EXISTS))
    (map-set vesting-schedules beneficiary {
      total-amount: total-amount,
      start-time: start-time,
      end-time: end-time,
      claimed-amount: u0
    })
    (ok true)
  )
)

;; --- Public Functions ---

;; @desc Claim vested tokens
;; @returns (response bool uint)
(define-public (claim-vested-tokens)
  (let ((schedule (map-get? vesting-schedules tx-sender)))
    (asserts! (is-some schedule) (err ERR_NO_VESTING_SCHEDULE))
    (let ((vested-amount (calculate-vested-amount (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE)))))
      (asserts! (> vested-amount (get claimed-amount (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE)))) (err ERR_NOTHING_TO_CLAIM))
      (let ((claim-amount (- vested-amount (get claimed-amount (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE))))))
        (map-set vesting-schedules tx-sender {
          total-amount: (get total-amount (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE))),
          start-time: (get start-time (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE))),
          end-time: (get end-time (unwrap! schedule (err ERR_NO_VESTING_SCHEDULE))),
          claimed-amount: vested-amount
        })
        (print { event: "vesting-claimed", beneficiary: tx-sender, amount: claim-amount, timestamp: burn-block-height })
        (ok claim-amount)
      )
    )
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-vesting-info (beneficiary principal))
  (map-get? vesting-schedules beneficiary)
)

;; --- Private Helper Functions ---
(define-private (calculate-vested-amount (schedule {total-amount: uint, start-time: uint, end-time: uint, claimed-amount: uint}))
  (if (< burn-block-height (var-get vesting-start))
    u0
    (if (>= burn-block-height (+ (var-get vesting-start) (- (get end-time schedule) (get start-time schedule))))
      (get total-amount schedule)
      (/ (* (get total-amount schedule) (- burn-block-height (var-get vesting-start))) (- (get end-time schedule) (get start-time schedule)))
    )
  )
)
