;; mock-fee-source.clar
;;
;; Simnet-only source-custody implementation for protocol-fee collector tests.
;; Each payer must first create a transaction-local pending expectation. The
;; callback validates the collector caller, fixed recipient, exact debit, and
;; same-block pending record before spending this contract's custody.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-fee-source-trait .protocol-fee-source-trait.protocol-fee-source-trait)
(impl-trait .protocol-fee-source-trait.protocol-fee-source-trait)

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_CALLBACK_CALLER (err u6001))
(define-constant ERR_CALLBACK_RECIPIENT (err u6002))
(define-constant ERR_CALLBACK_AMOUNT (err u6003))
(define-constant ERR_CALLBACK_ASSET (err u6004))
(define-constant ERR_CALLBACK_BLOCK (err u6005))
(define-constant ERR_PENDING (err u6006))
(define-constant ERR_INVALID_MODE (err u6007))

(define-constant MODE_EXACT u0)
(define-constant MODE_UNDERPAY u1)
(define-constant MODE_OVERPAY u2)
(define-constant MODE_NO_TRANSFER u3)
(define-constant MODE_WRONG_DESTINATION u4)

(define-data-var admin principal tx-sender)

(define-map pending-stx principal {
  expected-amount: uint,
  mode: uint,
  created-at: uint
})

(define-map pending-ft principal {
  expected-amount: uint,
  asset: principal,
  mode: uint,
  created-at: uint
})

(define-public (prepare-stx
    (payer principal)
    (expected-amount uint)
    (mode uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= mode MODE_WRONG_DESTINATION) ERR_INVALID_MODE)
    (map-set pending-stx payer {
      expected-amount: expected-amount,
      mode: mode,
      created-at: block-height
    })
    (ok true)
  )
)

(define-public (prepare-ft
    (payer principal)
    (asset principal)
    (expected-amount uint)
    (mode uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= mode MODE_WRONG_DESTINATION) ERR_INVALID_MODE)
    (map-set pending-ft payer {
      expected-amount: expected-amount,
      asset: asset,
      mode: mode,
      created-at: block-height
    })
    (ok true)
  )
)

(define-public (fund-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (prepay-stx-fee (amount uint) (recipient principal))
  (let ((pending (unwrap! (map-get? pending-stx tx-sender) ERR_PENDING)))
    (begin
      (asserts! (is-eq contract-caller .protocol-fee-collector) ERR_CALLBACK_CALLER)
      (asserts! (is-eq recipient .protocol-fee-collector) ERR_CALLBACK_RECIPIENT)
      (asserts! (is-eq amount (get expected-amount pending)) ERR_CALLBACK_AMOUNT)
      (asserts! (is-eq block-height (get created-at pending)) ERR_CALLBACK_BLOCK)
      (let (
        (mode (get mode pending))
        (debit (if (is-eq mode MODE_UNDERPAY)
          (if (> amount u0) (- amount u1) u0)
          (if (is-eq mode MODE_OVERPAY) (+ amount u1) amount)))
        (destination (if (is-eq mode MODE_WRONG_DESTINATION) tx-sender recipient))
      )
        (begin
          (if (is-eq mode MODE_NO_TRANSFER)
            true
            (if (> debit u0)
              (try! (as-contract (stx-transfer? debit tx-sender destination)))
              true))
          (map-delete pending-stx tx-sender)
          (ok true)
        )
      )
    )
  )
)

(define-public (prepay-ft-fee
    (token <sip-010-ft-trait>)
    (amount uint)
    (recipient principal))
  (let ((asset (contract-of token)))
    (begin
      (asserts! (is-eq contract-caller .protocol-fee-collector) ERR_CALLBACK_CALLER)
      (asserts! (is-eq recipient .protocol-fee-collector) ERR_CALLBACK_RECIPIENT)
      (let ((pending (unwrap! (map-get? pending-ft tx-sender) ERR_PENDING)))
        (begin
          (asserts! (is-eq asset (get asset pending)) ERR_CALLBACK_ASSET)
          (asserts! (is-eq amount (get expected-amount pending)) ERR_CALLBACK_AMOUNT)
          (asserts! (is-eq block-height (get created-at pending)) ERR_CALLBACK_BLOCK)
          (let (
            (mode (get mode pending))
            (debit (if (is-eq mode MODE_UNDERPAY)
              (if (> amount u0) (- amount u1) u0)
              (if (is-eq mode MODE_OVERPAY) (+ amount u1) amount)))
            (destination (if (is-eq mode MODE_WRONG_DESTINATION) tx-sender recipient))
          )
            (begin
              (if (is-eq mode MODE_NO_TRANSFER)
                true
                (if (> debit u0)
                  (try! (as-contract (contract-call? token transfer debit tx-sender destination none)))
                  true))
              (map-delete pending-ft tx-sender)
              (ok true)
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-pending-stx (payer principal))
  (ok (map-get? pending-stx payer))
)

(define-read-only (get-pending-ft (payer principal))
  (ok (map-get? pending-ft payer))
)

;; Test-only entrypoints make the source the immediate caller of the collector
;; settlement API while keeping the source principal explicit and checked.
(define-public (settle-ft
    (source <protocol-fee-source-trait>)
    (token <sip-010-ft-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (begin
    (asserts! (is-eq (contract-of source) (as-contract tx-sender)) ERR_CALLBACK_CALLER)
    (contract-call? .protocol-fee-collector settle-source-ft source token stream-id eligible-fee-base settlement-id)
  )
)

(define-public (settle-stx
    (source <protocol-fee-source-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32)))
  (begin
    (asserts! (is-eq (contract-of source) (as-contract tx-sender)) ERR_CALLBACK_CALLER)
    (contract-call? .protocol-fee-collector settle-source-stx source stream-id eligible-fee-base settlement-id)
  )
)
