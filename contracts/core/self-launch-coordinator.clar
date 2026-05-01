;; self-launch-coordinator.clar
;; Governs the progressive deployment funding curve for Conxian-Labs

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PHASE_COMPLETE (err u1001))
(define-constant ERR_ZERO_FUNDING (err u1002))

(define-data-var admin principal tx-sender)

;; 1. Bootstrap 2. Core 3. Liquidity 4. Governance 5. Autonomous
(define-data-var current-phase uint u1)
(define-data-var current-funding-stx uint u0)

;; Phase Targets (in STX micro-units: 1 STX = 1000000)
(define-constant PHASE_1_TARGET u10000000000)  ;; 10k STX
(define-constant PHASE_2_TARGET u100000000000) ;; 100k STX
(define-constant PHASE_3_TARGET u250000000000) ;; 250k STX
(define-constant PHASE_4_TARGET u400000000000) ;; 400k STX
(define-constant PHASE_5_TARGET u600000000000) ;; 600k STX

(define-map contributors principal uint)
(define-data-var total-contributors uint u0)

(define-read-only (get-current-phase)
  (ok (var-get current-phase))
)

(define-read-only (get-funding-progress)
  (ok (var-get current-funding-stx))
)

(define-public (contribute-to-launch (amount uint))
  (let ((caller tx-sender))
    (asserts! (> amount u0) ERR_ZERO_FUNDING)
    (asserts! (< (var-get current-phase) u6) ERR_PHASE_COMPLETE)

    ;; Transfer STX to protocol treasury (admin for now)
    (try! (stx-transfer? amount caller (var-get admin)))

    (let ((existing (default-to u0 (map-get? contributors caller))))
      (if (is-eq existing u0)
        (var-set total-contributors (+ (var-get total-contributors) u1))
        true
      )
      (map-set contributors caller (+ existing amount))
    )

    (var-set current-funding-stx (+ (var-get current-funding-stx) amount))
    (check-and-advance-phase)

    (print { event: "launch-contribution", contributor: caller, amount: amount, phase: (var-get current-phase) })
    (ok true)
  )
)

(define-private (check-and-advance-phase)
  (let ((current (var-get current-funding-stx)))
    (if (>= current PHASE_5_TARGET)
      (var-set current-phase u6) ;; Launch sequence fully funded
      (if (>= current PHASE_4_TARGET)
        (var-set current-phase u5)
        (if (>= current PHASE_3_TARGET)
          (var-set current-phase u4)
          (if (>= current PHASE_2_TARGET)
            (var-set current-phase u3)
            (if (>= current PHASE_1_TARGET)
              (var-set current-phase u2)
              true
            )
          )
        )
      )
    )
  )
)
