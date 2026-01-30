;; wormhole-outbox.clar
;; Sends cross-chain messages via Wormhole
;; Nakamoto-aligned with block-height

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u7200)
(define-constant BRIDGE_FEE u1000000) ;; 1 STX

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var sequence uint u0)

;; Storage
(define-map outgoing-messages
    uint
    {
        target-chain: uint,
        recipient: (buff 32),
        payload: (buff 1024),
        sender: principal,
        sent-at: uint,
    }
)

;; Public Functions

(define-public (send-message (target-chain uint) (recipient (buff 32)) (payload (buff 1024)))
  (let ((seq (+ (var-get sequence) u1)))
    (begin
      (try! (stx-transfer? BRIDGE_FEE tx-sender (contract-call? .revenue-distributor get-operational-treasury)))
      (map-set outgoing-messages seq {
          target-chain: target-chain,
          recipient: recipient,
          payload: payload,
          sender: tx-sender,
          sent-at: block-height,
      })
      (var-set sequence seq)
      (ok seq)
    )
  )
)

(define-read-only (get-message (seq uint))
    (map-get? outgoing-messages seq)
)
