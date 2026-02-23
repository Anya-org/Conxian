;; liquidity-manager.clar
;; Conxian Standard: Nakamoto-Aligned Liquidity Management
;; Manages liquidity positions and interacts with pools via Traits

;; Traits
(use-trait vault-trait .vault-traits.vault-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_POOL u2001)
(define-constant ERR_SLIPPAGE u2002)
(define-constant ERR_NON_COMPLIANT u2003)

;; Data Maps
;; positions: position-id -> { pool-id: uint, owner: principal, liquidity: uint, tick-lower: int, tick-upper: int }
(define-map positions
  uint
  {
    pool-id: uint,
    owner: principal,
    liquidity: uint,
    tick-lower: int,
    tick-upper: int,
  }
)

(define-data-var position-nonce uint u0)

;; Compliance Helper
(define-private (check-compliance (user principal))
  (contract-call? .regulatory-adapter check-clean-hands-compliance user)
)

;; Core Logic

;; @desc Opens a new liquidity position
;; @param pool-id uint - The pool ID
;; @param tick-lower int
;; @param tick-upper int
;; @param liquidity uint
;; @returns (response uint uint) - position-id
(define-public (open-position
    (pool-id uint)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
  )
  (let (
      (position-id (+ (var-get position-nonce) u1))
      (tenure-id (/ block-height u10))
    )
    ;; 1. Check Global Pause via Facade
    (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))

    ;; 2. Compliance Check
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))

    ;; 3. Interaction: Call Pool Mint
    (try! (contract-call? .concentrated-liquidity-pool mint pool-id tick-lower
      tick-upper liquidity
    ))

    ;; 4. Record position
    (map-set positions position-id {
      pool-id: pool-id,
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
      pool-id: pool-id,
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
    (asserts! (is-eq (get owner position) tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))

    ;; Compliance Check
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))

    ;; Call burn in pool
    (try! (contract-call? .concentrated-liquidity-pool burn (get pool-id position) (get tick-lower position) (get tick-upper position) (get liquidity position)))

    (map-delete positions position-id)

    (print {
      event: "close-position",
      position-id: position-id,
      owner: tx-sender,
      tenure-id: (/ block-height u10),
    })
    (ok true)
  )
)
