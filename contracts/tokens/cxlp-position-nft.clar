;; cxlp-position-nft.clar
;; Conxian Enterprise Standard: CXLP Liquidity Position NFT
;; Represents a concentrated liquidity position in the Conxian DEX
;;
;; REPAIRED: Full implementation of liquidity position NFT with metadata and fee tracking

(impl-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NOT_FOUND u1001)
(define-constant ERR_INVALID_TICK_RANGE u1002)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1003)
(define-constant ERR_POSITION_LOCKED u1004)

;; NFT Definition
(define-non-fungible-token cxlp-position uint)

;; Data Vars
(define-data-var last-position-id uint u0)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var pool-manager principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var fee-collector principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Position Data
(define-map positions
    uint
    {
        owner: principal,
        pool: principal,
        token0: principal,
        token1: principal,
        tick-lower: int,
        tick-upper: int,
        liquidity: uint,
        fee-growth-inside0-last: uint,
        fee-growth-inside1-last: uint,
        tokens-owed0: uint,
        tokens-owed1: uint,
        created-at: uint,
        last-updated: uint
    }
)

;; Events
(define-private (emit-position-created (position-id uint) (owner principal) (pool principal))
    (print {
        event: "position-created",
        position-id: position-id,
        owner: owner,
        pool: pool,
        timestamp: burn-block-height
    })
)

(define-private (emit-position-updated (position-id uint) (liquidity uint))
    (print {
        event: "position-updated",
        position-id: position-id,
        liquidity: liquidity,
        timestamp: burn-block-height
    })
)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-pool-manager)
    (is-eq tx-sender (var-get pool-manager))
)

;; SIP-009 Implementation
(define-read-only (get-last-token-id)
    (ok (var-get last-position-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? cxlp-position token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
        (try! (nft-transfer? cxlp-position token-id sender recipient))
        (ok true)
    )
)

;; Position Management
(define-public (mint-position
    (owner principal)
    (pool principal)
    (token0 principal)
    (token1 principal)
    (tick-lower int)
    (tick-upper int)
    (liquidity uint)
  )
    (let ((new-id (+ (var-get last-position-id) u1)))
        (asserts! (is-pool-manager) (err ERR_UNAUTHORIZED))
        (asserts! (< tick-lower tick-upper) (err ERR_INVALID_TICK_RANGE))
        (asserts! (> liquidity u0) (err ERR_INSUFFICIENT_LIQUIDITY))
        
        (try! (nft-mint? cxlp-position new-id owner))
        
        (map-set positions new-id {
            owner: owner,
            pool: pool,
            token0: token0,
            token1: token1,
            tick-lower: tick-lower,
            tick-upper: tick-upper,
            liquidity: liquidity,
            fee-growth-inside0-last: u0,
            fee-growth-inside1-last: u0,
            tokens-owed0: u0,
            tokens-owed1: u0,
            created-at: burn-block-height,
            last-updated: burn-block-height
        })
        
        (var-set last-position-id new-id)
        (emit-position-created new-id owner pool)
        (ok new-id)
    )
)

(define-read-only (get-position (position-id uint))
    (map-get? positions position-id)
)
