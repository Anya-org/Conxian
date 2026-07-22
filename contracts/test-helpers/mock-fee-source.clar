;; mock-fee-source.clar
;;
;; Simnet-only source-custody implementation for protocol-fee collector tests.
;; The public settlement wrappers create pending state and immediately call the
;; collector in one call stack. There is deliberately no externally callable
;; prepare-then-consume flow: a production source must keep its pending debit
;; private and atomic in the same way.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-fee-source-trait .protocol-fee-source-trait.protocol-fee-source-trait)
(impl-trait .protocol-fee-source-trait.protocol-fee-source-trait)

(define-constant ERR_CALLBACK_CALLER (err u6001))
(define-constant ERR_CALLBACK_RECIPIENT (err u6002))
(define-constant ERR_CALLBACK_AMOUNT (err u6003))
(define-constant ERR_CALLBACK_ASSET (err u6004))
(define-constant ERR_PENDING (err u6006))
(define-constant ERR_INVALID_MODE (err u6007))
(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-constant MODE_EXACT u0)
(define-constant MODE_UNDERPAY u1)
(define-constant MODE_OVERPAY u2)
(define-constant MODE_NO_TRANSFER u3)
(define-constant MODE_WRONG_DESTINATION u4)
(define-constant MODE_WRONG_ASSET u5)

(define-data-var ft-callback-invocations uint u0)
(define-data-var stx-callback-invocations uint u0)
(define-data-var stx-transfer-failure bool false)

(define-map pending-stx principal {
  expected-amount: uint,
  mode: uint,
  stream-id: uint,
  eligible-fee-base: uint,
  settlement-id: (buff 32)
})

(define-map pending-ft principal {
  expected-amount: uint,
  asset: principal,
  mode: uint,
  stream-id: uint,
  eligible-fee-base: uint,
  settlement-id: (buff 32)
})

(define-public (fund-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (set-stx-transfer-failure (should-fail bool))
  (begin
    (var-set stx-transfer-failure should-fail)
    (ok should-fail)
  )
)

(define-public (prepay-stx-fee (amount uint) (recipient principal))
  (let ((pending (unwrap! (map-get? pending-stx tx-sender) ERR_PENDING)))
    (begin
      (var-set stx-callback-invocations (+ (var-get stx-callback-invocations) u1))
      (asserts! (is-eq contract-caller .protocol-fee-collector) ERR_CALLBACK_CALLER)
      (asserts! (is-eq recipient .protocol-fee-collector) ERR_CALLBACK_RECIPIENT)
      (asserts! (is-eq amount (get expected-amount pending)) ERR_CALLBACK_AMOUNT)
      (let (
        (mode (get mode pending))
        (debit (if (is-eq mode MODE_UNDERPAY)
          (if (> amount u0) (- amount u1) u0)
          (if (is-eq mode MODE_OVERPAY) (+ amount u1) amount)))
        (destination (if (is-eq mode MODE_WRONG_DESTINATION) tx-sender recipient))
      )
        (begin
          (if (var-get stx-transfer-failure)
            (try! (as-contract (stx-transfer? MAX_UINT tx-sender destination)))
            (if (is-eq mode MODE_NO_TRANSFER)
              true
              (if (> debit u0)
                (try! (as-contract (stx-transfer? debit tx-sender destination)))
                true)))
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
      (var-set ft-callback-invocations (+ (var-get ft-callback-invocations) u1))
      (asserts! (is-eq contract-caller .protocol-fee-collector) ERR_CALLBACK_CALLER)
      (asserts! (is-eq recipient .protocol-fee-collector) ERR_CALLBACK_RECIPIENT)
      (let ((pending (unwrap! (map-get? pending-ft tx-sender) ERR_PENDING)))
        (begin
          (asserts! (is-eq asset (get asset pending)) ERR_CALLBACK_ASSET)
          (asserts! (is-eq amount (get expected-amount pending)) ERR_CALLBACK_AMOUNT)
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

(define-read-only (get-stx-callback-invocations)
  (ok (var-get stx-callback-invocations))
)

(define-read-only (get-ft-callback-invocations)
  (ok (var-get ft-callback-invocations))
)

;; Test-only entrypoints make the source the immediate caller of the collector
;; settlement API while keeping the source principal explicit and checked.
(define-public (settle-ft
    (source <protocol-fee-source-trait>)
    (token <sip-010-ft-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32))
    (mode uint))
  (begin
    (asserts! (is-eq (contract-of source) (as-contract tx-sender)) ERR_CALLBACK_CALLER)
    (asserts! (<= mode MODE_WRONG_ASSET) ERR_INVALID_MODE)
    (let ((preview (try! (contract-call? .protocol-fee-collector
        preview-source-ft
        (contract-of source)
        stream-id
        (contract-of token)
        eligible-fee-base))))
      (map-set pending-ft tx-sender {
        expected-amount: (get assessed-amount preview),
        asset: (if (is-eq mode MODE_WRONG_ASSET) tx-sender (contract-of token)),
        mode: mode,
        stream-id: stream-id,
        eligible-fee-base: eligible-fee-base,
        settlement-id: settlement-id
      })
      (contract-call? .protocol-fee-collector settle-source-ft source token stream-id eligible-fee-base settlement-id)
    )
  )
)

(define-public (settle-stx
    (source <protocol-fee-source-trait>)
    (stream-id uint)
    (eligible-fee-base uint)
    (settlement-id (buff 32))
    (mode uint))
  (begin
    (asserts! (is-eq (contract-of source) (as-contract tx-sender)) ERR_CALLBACK_CALLER)
    (asserts! (<= mode MODE_WRONG_ASSET) ERR_INVALID_MODE)
    (let ((preview (try! (contract-call? .protocol-fee-collector
        preview-source-stx
        (contract-of source)
        stream-id
        eligible-fee-base))))
      (map-set pending-stx tx-sender {
        expected-amount: (get assessed-amount preview),
        mode: mode,
        stream-id: stream-id,
        eligible-fee-base: eligible-fee-base,
        settlement-id: settlement-id
      })
      (contract-call? .protocol-fee-collector settle-source-stx source stream-id eligible-fee-base settlement-id)
    )
  )
)
