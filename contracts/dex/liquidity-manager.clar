;; liquidity-manager.clar
;; Conxian Standard: Nakamoto-Aligned Liquidity Management
;; Manages liquidity positions and interacts with pools via Traits

;; Traits
(use-trait vault-trait .vault-trait.vault-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_POOL (err u2001))
(define-constant ERR_SLIPPAGE (err u2002))

;; Data Maps
;; positions: position-id -> { pool: principal, owner: principal, liquidity: uint, tick-lower: int, tick-upper: int }
(define-map positions
    uint
    {
        pool: principal,
        owner: principal,
        liquidity: uint,
        tick-lower: int,
        tick-upper: int,
    }
)

(define-data-var position-nonce uint u0)

;; Core Logic

;; @desc Opens a new liquidity position
;; @param pool principal - The pool contract
;; @param token0 principal - Token 0
;; @param token1 principal - Token 1
;; @param tick-lower int
;; @param tick-upper int
;; @param liquidity uint
;; @returns (response uint uint) - position-id
(define-public (open-position
        (pool principal)
        (token0 <sip-010-trait>)
        (token1 <sip-010-trait>)
        (tick-lower int)
        (tick-upper int)
        (liquidity uint)
    )
    (let (
            (position-id (+ (var-get position-nonce) u1))
            (tenure-id (contract-call? .block-utils get-current-tenure-id))
        )
        ;; 1. Check Global Pause via Facade
        (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))

        ;; 2. Interaction: Call Pool Mint
        ;; Note: The pool contract must implement (mint (uint int int uint) (response bool uint))
        ;; We use a specific ID if known, or pass as principal. 
        ;; For this integration, we call the pool principal directly assuming standard interface.
        (try! (contract-call? .concentrated-liquidity-pool mint u1 tick-lower
            tick-upper liquidity
        ))

        ;; 3. Record position
        (map-set positions position-id {
            pool: pool,
            owner: tx-sender,
            liquidity: liquidity,
            tick-lower: tick-lower,
            tick-upper: tick-upper,
        })

        (var-set position-nonce position-id)

        ;; Event with tenure-id for indexing
        (print {
            event: "open-position",
            position-id: position-id,
            owner: tx-sender,
            pool: pool,
            tenure-id: tenure-id,
        })

        (ok position-id)
    )
)

;; @desc Closes a position
;; @param position-id uint
;; @returns (response bool uint)
(define-public (close-position (position-id uint))
    (let ((position (unwrap! (map-get? positions position-id) (err u404))))
        (asserts! (is-eq (get owner position) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))

        (map-delete positions position-id)

        (print {
            event: "close-position",
            position-id: position-id,
            owner: tx-sender,
            tenure-id: (contract-call? .block-utils get-current-tenure-id),
        })
        (ok true)
    )
)