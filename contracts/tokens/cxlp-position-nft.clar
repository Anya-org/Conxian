;; CXLP Position NFT - Concentrated Liquidity Position NFT
;; SIP-009 NFT implementation for liquidity positions

;; Import SIP-009 trait
(impl-trait .sip-standards.sip-009-nft-trait)

;; NFT metadata
(define-constant NFT_NAME "Conxian Liquidity Position")
(define-constant NFT_SYMBOL "CXLP")
(define-constant NFT_URI "https://conxian.io/metadata/cxlp.json")

;; NFT state
(define-map tokens { token-id: uint } { owner: principal })
(define-map token-metadata { token-id: uint } { 
  token-uri: (optional (string-ascii 256))
  metadata: (optional (string-ascii 256))
})
(define-map position-data { token-id: uint } {
  pool: principal
  owner: principal
  tick-lower: int
  tick-upper: int
  liquidity: uint
  fee-growth-inside-0-x128: uint
  fee-growth-inside-1-x128: uint
  tokens-owed-0: uint
  tokens-owed-1: uint
})

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var next-token-id uint u1)

;; Events
(define-event (transfer-mint (recipient principal) (token-id uint)))
(define-event (transfer-burn (sender principal) (token-id uint)))
(define-event (transfer (sender principal) (recipient principal) (token-id uint)))
(define-event (position-updated (token-id uint) (liquidity uint)))
(define-event (fees-collected (token-id uint) (amount0 uint) (amount1 uint)))

;; Read-only functions

(define-read-only (get-name)
  NFT_NAME)

(define-read-only (get-symbol)
  NFT_SYMBOL)

(define-read-only (get-token-uri)
  NFT_URI)

(define-read-only (get-last-token-id)
  (- (var-get next-token-id) u1))

(define-read-only (get-owner (token-id uint))
  (match (map-get? tokens { token-id: token-id })
    token (get token owner)
    none (err 2001)
  )
)

(define-read-only (get-token-uri-optional (token-id uint))
  (match (map-get? token-metadata { token-id: token-id })
    metadata (get metadata token-uri)
    none none
  )
)

(define-read-only (get-metadata-optional (token-id uint))
  (match (map-get? token-metadata { token-id: token-id })
    metadata (get metadata metadata)
    none none
  )
)

;; Position-specific read-only functions

(define-read-only (get-position (token-id uint))
  (map-get? position-data { token-id: token-id }))

(define-read-only (get-position-liquidity (token-id uint))
  (match (get-position token-id)
    position (ok (get position liquidity))
    none (err 2002)
  )
)

(define-read-only (get-position-owner (token-id uint))
  (match (get-position token-id)
    position (ok (get position owner))
    none (err 2003)
  )
)

(define-read-only (get-position-pool (token-id uint))
  (match (get-position token-id)
    position (ok (get position pool))
    none (err 2004)
  )
)

(define-read-only (get-position-ticks (token-id uint))
  (match (get-position token-id)
    position (ok { tick-lower: (get position tick-lower), tick-upper: (get position tick-upper) })
    none (err 2005)
  )
)

;; Public functions

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; Verify sender owns the token
    (asserts! (is-eq (get-owner token-id) sender) (err 2006))
    
    ;; Transfer ownership
    (map-set tokens { token-id: token-id } { owner: recipient })
    
    ;; Update position owner
    (map-set position-data { token-id: token-id } {
      pool: (unwrap-panic (get-position-pool token-id)),
      owner: recipient,
      tick-lower: (unwrap-panic (get-position-ticks token-id)).tick-lower,
      tick-upper: (unwrap-panic (get-position-ticks token-id)).tick-upper,
      liquidity: (unwrap-panic (get-position-liquidity token-id)),
      fee-growth-inside-0-x128: u0,
      fee-growth-inside-1-x128: u0,
      tokens-owed-0: u0,
      tokens-owed-1: u0
    })
    
    ;; Emit event
    (emit-event (transfer sender recipient token-id))
    
    (ok true)
  )
)

(define-public (mint-position 
  (pool principal) 
  (owner principal) 
  (tick-lower int) 
  (tick-upper int) 
  (liquidity uint)
)
  (begin
    ;; Only authorized contracts can mint positions
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-eq tx-sender (var-get admin))
      (contract-call? .dex-facade is-authorized-pool pool)
    ) (err 2007))
    
    ;; Validate parameters
    (asserts! (> liquidity u0) (err 2008))
    (asserts! (< tick-lower tick-upper) (err 2009))
    
    ;; Get next token ID
    (let ((token-id (var-get next-token-id)))
      ;; Update next token ID
      (var-set next-token-id (+ token-id u1))
      
      ;; Mint NFT
      (map-set tokens { token-id: token-id } { owner: owner })
      (map-set token-metadata { token-id: token-id } {
        token-uri: (some NFT_URI),
        metadata: (some (concat "Position in pool " (contract-call? .pool-factory get-pool-name pool)))
      })
      
      ;; Create position data
      (map-set position-data { token-id: token-id } {
        pool: pool,
        owner: owner,
        tick-lower: tick-lower,
        tick-upper: tick-upper,
        liquidity: liquidity,
        fee-growth-inside-0-x128: u0,
        fee-growth-inside-1-x128: u0,
        tokens-owed-0: u0,
        tokens-owed-1: u0
      })
      
      ;; Emit event
      (emit-event (transfer-mint owner token-id))
      (emit-event (position-updated token-id liquidity))
      
      (ok token-id)
    )
  )
)

(define-public (burn-position (token-id uint))
  (begin
    ;; Verify caller owns the token
    (asserts! (is-eq (get-owner token-id) tx-sender) (err 2010))
    
    ;; Get position data
    (match (get-position token-id)
      position
        (begin
          ;; Remove NFT
          (map-delete tokens { token-id: token-id })
          (map-delete token-metadata { token-id: token-id })
          (map-delete position-data { token-id: token-id })
          
          ;; Emit event
          (emit-event (transfer-burn tx-sender token-id))
          
          (ok {
            pool: (get position pool),
            liquidity: (get position liquidity),
            tokens-owed-0: (get position tokens-owed-0),
            tokens-owed-1: (get position tokens-owed-1)
          })
        )
      none (err 2011)
    )
  )
)

(define-public (update-position (token-id uint) (new-liquidity uint))
  (begin
    ;; Only authorized contracts can update positions
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-eq tx-sender (var-get admin))
      (contract-call? .dex-facade is-authorized-pool (unwrap-panic (get-position-pool token-id)))
    ) (err 2012))
    
    ;; Update liquidity
    (match (get-position token-id)
      position
        (begin
          (map-set position-data { token-id: token-id } {
            pool: (get position pool),
            owner: (get position owner),
            tick-lower: (get position tick-lower),
            tick-upper: (get position tick-upper),
            liquidity: new-liquidity,
            fee-growth-inside-0-x128: (get position fee-growth-inside-0-x128),
            fee-growth-inside-1-x128: (get position fee-growth-inside-1-x128),
            tokens-owed-0: (get position tokens-owed-0),
            tokens-owed-1: (get position tokens-owed-1)
          })
          
          ;; Emit event
          (emit-event (position-updated token-id new-liquidity))
          
          (ok true)
        )
      none (err 2013)
    )
  )
)

(define-public (collect-fees (token-id uint))
  (begin
    ;; Verify caller owns the token
    (asserts! (is-eq (get-owner token-id) tx-sender) (err 2014))
    
    ;; Get position data
    (match (get-position token-id)
      position
        (begin
          (let ((amount0 (get position tokens-owed-0))
                (amount1 (get position tokens-owed-1)))
            
            ;; Reset tokens owed
            (map-set position-data { token-id: token-id } {
              pool: (get position pool),
              owner: (get position owner),
              tick-lower: (get position tick-lower),
              tick-upper: (get position tick-upper),
              liquidity: (get position liquidity),
              fee-growth-inside-0-x128: (get position fee-growth-inside-0-x128),
              fee-growth-inside-1-x128: (get position fee-growth-inside-1-x128),
              tokens-owed-0: u0,
              tokens-owed-1: u0
            })
            
            ;; Emit event
            (emit-event (fees-collected token-id amount0 amount1))
            
            (ok { amount0: amount0, amount1: amount1 })
          )
        )
      none (err 2015)
    )
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 2016))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (emergency-burn (token-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 2017))
    
    ;; Remove NFT without checks
    (map-delete tokens { token-id: token-id })
    (map-delete token-metadata { token-id: token-id })
    (map-delete position-data { token-id: token-id })
    
    ;; Emit event
    (emit-event (transfer-burn tx-sender token-id))
    
    (ok true)
  )
)
