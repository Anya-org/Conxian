;; wormhole-outbox.clar
;; Sends cross-chain messages via Wormhole
;; Collects bridge fees for outgoing operations

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7200))
(define-constant ERR_INSUFFICIENT_FEE (err u7201))
(define-constant BRIDGE_FEE u1000000) ;; 1 STX

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var revenue-contract principal .revenue-distributor)

;; Outgoing Message Storage
(define-map outgoing-messages
    uint ;; sequence
    {
        target-chain: uint,
        recipient: (buff 32),
        payload: (buff 1024),
        sender: principal,
        sent-at: uint,
    }
)

(define-data-var sequence uint u0)

;; Send Message
(define-public (send-message
        (target-chain uint)
        (recipient (buff 32))
        (payload (buff 1024))
    )
    (let (
            (seq (+ (var-get sequence) u1))
            (fee-recipient (var-get revenue-contract))
        )
        ;; Collect bridge fee and send to revenue distributor
        (try! (stx-transfer? BRIDGE_FEE tx-sender fee-recipient))

        ;; Store outgoing message
        (map-set outgoing-messages seq {
            target-chain: target-chain,
            recipient: recipient,
            payload: payload,
            sender: tx-sender,
            sent-at: block-height,
        })

        (var-set sequence seq)

        (print {
            event: "message-sent",
            sequence: seq,
            target-chain: target-chain,
            sender: tx-sender,
            fee: BRIDGE_FEE,
        })

        (ok seq)
    )
)

;; Send Token (Cross-Chain Transfer)
(define-public (send-token
        (token .sip-standards.sip-010-ft-trait)
        (amount uint)
        (target-chain uint)
        (recipient (buff 32))
    )
    (let (
            (seq (+ (var-get sequence) u1))
            (fee-recipient (var-get revenue-contract))
        )
        ;; Collect bridge fee
        (try! (stx-transfer? BRIDGE_FEE tx-sender fee-recipient))

        ;; Lock tokens in this contract (would be burned/locked in production)
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)
            none
        ))

        ;; Store message
        (map-set outgoing-messages seq {
            target-chain: target-chain,
            recipient: recipient,
            payload: 0x00, ;; Token transfer payload
            sender: tx-sender,
            sent-at: block-height,
        })

        (var-set sequence seq)

        (print {
            event: "token-sent",
            sequence: seq,
            amount: amount,
            target-chain: target-chain,
            fee: BRIDGE_FEE,
        })

        (ok seq)
    )
)

;; Admin
(define-public (set-revenue-contract (new-contract principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set revenue-contract new-contract)
        (ok true)
    )
)

;; Read-Only
(define-read-only (get-message (seq uint))
    (ok (map-get? outgoing-messages seq))
)

(define-read-only (get-sequence)
    (ok (var-get sequence))
)

(define-read-only (get-bridge-fee)
    (ok BRIDGE_FEE)
)
