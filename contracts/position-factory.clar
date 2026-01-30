;; position-factory.clar
;; Factory for creating and managing user positions (e.g., Liquidity, Lending)
;; Tier 0 Architecture

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_PARAMS u1001)

(define-map positions
  uint
  {
    owner: principal,
    pool: principal,
    amount: uint,
    created: uint,
  }
)

(define-data-var position-nonce uint u0)

(define-public (create-position
    (pool principal)
    (amount uint)
  )
  (let (
      (id (+ (var-get position-nonce) u1))
      (sender tx-sender)
    )
    (map-set positions id {
      owner: sender,
      pool: pool,
      amount: amount,
      created: block-height,
    })
    (var-set position-nonce id)
    (ok id)
  )
)

(define-read-only (get-position (id uint))
  (map-get? positions id)
)
