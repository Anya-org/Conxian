;; dex-backend.clar
;; Conxian Enterprise Standard: DEX Backend
;; Contains all business logic for decentralized exchange operations

;; Trait imports
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait oracle-trait .oracle.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u9300))
(define-constant ERR_INVALID_TOKEN (err u9301))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u9302))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u9303))
(define-constant ERR_POOL_NOT_FOUND (err u9304))

;; Pool storage
(define-map pools 
  { token-a: principal, token-b: principal }
  { 
    reserve-a: uint, 
    reserve-b: uint, 
    total-liquidity: uint, 
    fee-basis-points: uint,
    last-update: uint 
  }
)

;; Liquidity positions
(define-map liquidity-positions
  { owner: principal, token-a: principal, token-b: principal }
  { liquidity-amount: uint, last-deposit: uint }
)

;; Data Vars
(define-data-var dex-owner principal tx-sender)
(define-data-var total-pools uint u0)
(define-data-var total-volume-24h uint u0)

;; Public functions
(define-public (swap-tokens 
  (token-a principal) 
  (token-b principal) 
  (amount-in uint) 
  (min-amount-out uint)
)
  (begin
    (asserts! (> amount-in u0) ERR_INVALID_TOKEN)
    
    ;; Get pool
    (match (map-get? pools { token-a: token-a, token-b: token-b })
      pool 
      (begin
        ;; Calculate output amount (simplified AMM formula)
        (let 
          ((reserve-a (get reserve-a pool))
           (reserve-b (get reserve-b pool))
           (amount-in-with-fee (- amount-in (/ (* amount-in u30) u10000))) ;; 0.3% fee
           (amount-out (/ (* amount-in-with-fee reserve-b) (+ reserve-a amount-in-with-fee))))
          
          (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
          (asserts! (> amount-out u0) ERR_INSUFFICIENT_LIQUIDITY)
          
          ;; Update reserves
          (map-set pools 
            { token-a: token-a, token-b: token-b }
            { 
              reserve-a: (+ reserve-a amount-in),
              reserve-b: (- reserve-b amount-out),
              total-liquidity: (get total-liquidity pool),
              fee-basis-points: (get fee-basis-points pool),
              last-update: block-height
            }
          )
          
          (ok amount-out)
        )
      )
      (err ERR_POOL_NOT_FOUND)
    )
  )
)

(define-public (add-liquidity 
  (token-a principal) 
  (token-b principal) 
  (amount-a uint) 
  (amount-b uint) 
  (min-liquidity uint)
)
  (begin
    (asserts! (and (> amount-a u0) (> amount-b u0)) ERR_INVALID_TOKEN)
    
    ;; Get or create pool
    (let 
      ((pool-key { token-a: token-a, token-b: token-b })
       (existing-pool (map-get? pools pool-key)))
      
      (match existing-pool
        pool
        (begin
          ;; Add to existing pool
          (let 
            ((liquidity-amount (min (* amount-a u1000) (* amount-b u1000)))) ;; Simplified LP calculation
            
            (asserts! (>= liquidity-amount min-liquidity) ERR_SLIPPAGE_TOO_HIGH)
            
            ;; Update pool
            (map-set pools pool-key
              { 
                reserve-a: (+ (get reserve-a pool) amount-a),
                reserve-b: (+ (get reserve-b pool) amount-b),
                total-liquidity: (+ (get total-liquidity pool) liquidity-amount),
                fee-basis-points: (get fee-basis-points pool),
                last-update: block-height
              }
            )
            
            ;; Update user position
            (map-set liquidity-positions
              { owner: tx-sender, token-a: token-a, token-b: token-b }
              { 
                liquidity-amount: (+ (default-to u0 (get liquidity-amount (map-get? liquidity-positions { owner: tx-sender, token-a: token-a, token-b: token-b }))) liquidity-amount),
                last-deposit: block-height
              }
            )
            
            (ok liquidity-amount)
          )
        )
        (begin
          ;; Create new pool
          (let ((liquidity-amount (min (* amount-a u1000) (* amount-b u1000))))
            
            (asserts! (>= liquidity-amount min-liquidity) ERR_SLIPPAGE_TOO_HIGH)
            
            (map-set pools pool-key
              { 
                reserve-a: amount-a,
                reserve-b: amount-b,
                total-liquidity: liquidity-amount,
                fee-basis-points: u30, ;; 0.3%
                last-update: block-height
              }
            )
            
            (map-set liquidity-positions
              { owner: tx-sender, token-a: token-a, token-b: token-b }
              { liquidity-amount: liquidity-amount, last-deposit: block-height }
            )
            
            (var-set total-pools (+ (var-get total-pools) u1))
            
            (ok liquidity-amount)
          )
        )
      )
    )
  )
)

(define-public (remove-liquidity 
  (token-a principal) 
  (token-b principal) 
  (liquidity-amount uint) 
  (min-amount-a uint) 
  (min-amount-b uint)
)
  (begin
    (asserts! (> liquidity-amount u0) ERR_INVALID_TOKEN)
    
    ;; Get pool and user position
    (match (map-get? pools { token-a: token-a, token-b: token-b })
      pool 
      (begin
        (match (map-get? liquidity-positions { owner: tx-sender, token-a: token-a, token-b: token-b })
          position
          (begin
            (let 
              ((user-liquidity (get liquidity-amount position))
               (total-liquidity (get total-liquidity pool))
               (reserve-a (get reserve-a pool))
               (reserve-b (get reserve-b pool))
               (amount-a (/ (* liquidity-amount reserve-a) total-liquidity))
               (amount-b (/ (* liquidity-amount reserve-b) total-liquidity)))
              
              (asserts! (<= liquidity-amount user-liquidity) ERR_INVALID_TOKEN)
              (asserts! (and (>= amount-a min-amount-a) (>= amount-b min-amount-b)) ERR_SLIPPAGE_TOO_HIGH)
              
              ;; Update pool
              (map-set pools { token-a: token-a, token-b: token-b }
                { 
                  reserve-a: (- reserve-a amount-a),
                  reserve-b: (- reserve-b amount-b),
                  total-liquidity: (- total-liquidity liquidity-amount),
                  fee-basis-points: (get fee-basis-points pool),
                  last-update: block-height
                }
              )
              
              ;; Update user position
              (map-set liquidity-positions
                { owner: tx-sender, token-a: token-a, token-b: token-b }
                { 
                  liquidity-amount: (- user-liquidity liquidity-amount),
                  last-deposit: (get last-deposit position)
                }
              )
              
              (ok { amount-a: amount-a, amount-b: amount-b })
            )
          )
          (err ERR_POOL_NOT_FOUND)
        )
      )
      (err ERR_POOL_NOT_FOUND)
    )
  )
)

(define-read-only (get-pool-info (token-a principal) (token-b principal))
  (match (map-get? pools { token-a: token-a, token-b: token-b })
    pool 
    (ok pool)
    (err ERR_POOL_NOT_FOUND)
  )
)

(define-read-only (get-swap-quote 
  (token-a principal) 
  (token-b principal) 
  (amount-in uint)
)
  (match (map-get? pools { token-a: token-a, token-b: token-b })
    pool 
    (let 
      ((reserve-a (get reserve-a pool))
       (reserve-b (get reserve-b pool))
       (amount-in-with-fee (- amount-in (/ (* amount-in u30) u10000)))
       (amount-out (/ (* amount-in-with-fee reserve-b) (+ reserve-a amount-in-with-fee))))
      
      (ok { amount-out: amount-out, fee: (- amount-in amount-in-with-fee) })
    )
    (err ERR_POOL_NOT_FOUND)
  )
)

(define-read-only (get-user-position 
  (owner principal) 
  (token-a principal) 
  (token-b principal)
)
  (match (map-get? liquidity-positions { owner: owner, token-a: token-a, token-b: token-b })
    position (ok position)
    (err ERR_POOL_NOT_FOUND)
  )
)
