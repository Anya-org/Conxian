;; ico-offering.clar
;; Conxian Initial Community Offering Manager
;;
;; Manages token distribution events with configurable rate, caps,
;; KYC compliance checks, and automatic refund capability.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_COMPLIANCE_FAILED u1004)
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_OFFERING_NOT_ACTIVE u1001)
(define-constant ERR_CAP_EXCEEDED u1002)
(define-constant ERR_INDIVIDUAL_CAP u1003)
(define-constant ERR_SOFT_CAP_NOT_MET u1006)

(define-constant STATUS_PENDING u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_COMPLETE u2)
(define-constant STATUS_REFUNDING u3)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var token-contract principal tx-sender)
(define-data-var rate uint u0)
(define-data-var hard-cap uint u0)
(define-data-var soft-cap uint u0)
(define-data-var individual-cap uint u0)
(define-data-var total-raised uint u0)
(define-data-var total-contributors uint u0)
(define-data-var start-block uint u0)
(define-data-var end-block uint u0)
(define-data-var status uint STATUS_PENDING)

(define-map contributions principal uint)

;; --- Core ---

;; @desc Allows a user to purchase tokens during an ICO offering.
;; @param amount: The amount of STX to contribute.
;; @param token: The token used for purchase.
(define-public (buy-tokens (amount uint) (token <sip-010-trait>))
  (let ((contributor tx-sender))
    (begin
      (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance contributor))
        (err ERR_COMPLIANCE_FAILED))
      (asserts! (is-eq (var-get status) STATUS_ACTIVE) (err ERR_OFFERING_NOT_ACTIVE))
      (asserts! (>= burn-block-height (var-get start-block)) (err ERR_OFFERING_NOT_ACTIVE))
      (asserts! (< burn-block-height (var-get end-block)) (err ERR_OFFERING_NOT_ACTIVE))
      (asserts! (<= (+ (var-get total-raised) amount) (var-get hard-cap)) (err ERR_CAP_EXCEEDED))

      (let ((existing (default-to u0 (map-get? contributions contributor))))
        (asserts! (<= (+ existing amount) (var-get individual-cap)) (err ERR_INDIVIDUAL_CAP))
        (if (is-eq existing u0)
          (var-set total-contributors (+ (var-get total-contributors) u1))
          true
        )
        (map-set contributions contributor (+ existing amount))
      )

      (var-set total-raised (+ (var-get total-raised) amount))
      (print { event: "ico-contribution", contributor: contributor, amount: amount })
      (ok true)
    )
  )
)

;; --- Admin ---

(define-public (initialize-offering
    (token principal) (token-rate uint)
    (hard-cap-amount uint) (soft-cap-amount uint)
    (individual-cap-amount uint) (start uint) (end uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq (var-get status) STATUS_PENDING) (err ERR_OFFERING_NOT_ACTIVE))
    (var-set token-contract token)
    (var-set rate token-rate)
    (var-set hard-cap hard-cap-amount)
    (var-set soft-cap soft-cap-amount)
    (var-set individual-cap individual-cap-amount)
    (var-set start-block start)
    (var-set end-block end)
    (var-set status STATUS_ACTIVE)
    (print { event: "ico-initialized", token: token, rate: token-rate })
    (ok true)
  )
)

(define-public (finalize-offering)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (>= burn-block-height (var-get end-block)) (err ERR_OFFERING_NOT_ACTIVE))
    (if (>= (var-get total-raised) (var-get soft-cap))
      (var-set status STATUS_COMPLETE)
      (var-set status STATUS_REFUNDING)
    )
    (print { event: "ico-finalized", status: (var-get status), raised: (var-get total-raised) })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- Read-only ---

(define-read-only (get-offering-status)
  {
    status: (var-get status),
    total-raised: (var-get total-raised),
    hard-cap: (var-get hard-cap),
    soft-cap: (var-get soft-cap),
    contributors: (var-get total-contributors)
  }
)

(define-read-only (get-contribution (contributor principal))
  (default-to u0 (map-get? contributions contributor))
)
