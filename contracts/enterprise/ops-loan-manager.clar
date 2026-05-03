;; ops-loan-manager.clar
;; Structured Finance for Business Operations (BOS)
;; Implements Junior/Senior Tranches and 5-class Wallet Model

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_LOAN (err u1001))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1002))
(define-constant ERR_INTENT_NOT_VERIFIED (err u1003))

;; Wallet Classes
(define-constant CLASS_OWNER u1)
(define-constant CLASS_GUARDIAN u2)
(define-constant CLASS_WORKER u3)
(define-constant CLASS_SENIOR u4)
(define-constant CLASS_JUNIOR u5)

;; --- State ---
(define-map loans
  uint
  {
    invoice-id: (string-ascii 64),
    total-amount: uint,
    senior-funded: uint,
    junior-funded: uint,
    senior-target: uint,
    junior-target: uint,
    status: (string-ascii 20),
    guardian: principal,
    intent-verified: bool
  }
)

(define-data-var loan-nonce uint u0)

;; --- Public Functions ---

;; @desc Create a new structured Ops Loan
(define-public (create-ops-loan (invoice-id (string-ascii 64)) (amount uint) (senior-ratio uint) (guardian principal))
  (let (
    (loan-id (+ (var-get loan-nonce) u1))
    (senior-target (/ (* amount senior-ratio) u100))
    (junior-target (- amount senior-target))
  )
    (begin
      (map-set loans loan-id {
        invoice-id: invoice-id,
        total-amount: amount,
        senior-funded: u0,
        junior-funded: u0,
        senior-target: senior-target,
        junior-target: junior-target,
        status: "funding",
        guardian: guardian,
        intent-verified: false
      })
      (var-set loan-nonce loan-id)
      (ok loan-id)
    )
  )
)

;; @desc Fund a loan tranche (Senior or Junior)
;; @desc Fund a specific loan tranche (Senior/Junior)
(define-public (fund-tranche (loan-id uint) (amount uint) (tranche-class uint) (token <sip-010-ft-trait>))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_INVALID_LOAN))
  )
    (begin
      (asserts! (is-eq (get status loan) "funding") ERR_INVALID_LOAN)
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))

      (if (is-eq tranche-class CLASS_SENIOR)
        (map-set loans loan-id (merge loan { senior-funded: (+ (get senior-funded loan) amount) }))
        (map-set loans loan-id (merge loan { junior-funded: (+ (get junior-funded loan) amount) }))
      )

      (ok true)
    )
  )
)

;; @desc Verify ERP Intent (Guardian Only)
;; @desc Verify ERP intent (Guardian only)
(define-public (verify-intent (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_INVALID_LOAN))
  )
    (begin
      (asserts! (is-eq tx-sender (get guardian loan)) ERR_UNAUTHORIZED)
      (map-set loans loan-id (merge loan { intent-verified: true }))
      (ok true)
    )
  )
)

;; @desc Settle Loan (Triggers payment to ERP endpoint)
;; @desc Settle an Ops Loan and transfer funds to recipient
(define-public (settle-loan (loan-id uint) (token <sip-010-ft-trait>) (recipient principal))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_INVALID_LOAN))
  )
    (begin
      (asserts! (get intent-verified loan) ERR_INTENT_NOT_VERIFIED)
      (asserts! (>= (+ (get senior-funded loan) (get junior-funded loan)) (get total-amount loan)) ERR_INSUFFICIENT_FUNDS)

      (try! (as-contract (contract-call? token transfer (get total-amount loan) (as-contract tx-sender) recipient none)))

      (map-set loans loan-id (merge loan { status: "settled" }))
      (ok true)
    )
  )
)

;; @desc Get loan details
(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)
