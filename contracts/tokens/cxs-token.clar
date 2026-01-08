;; CXS Token - Conxian Staking Token
;; SIP-010 Fungible Token for staking rewards

;; Import SIP-010 trait
(impl-trait .sip-standards.sip-010-ft-trait)

;; Token metadata
(define-constant TOKEN_NAME "Conxian Staking Token")
(define-constant TOKEN_SYMBOL "CXS")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI "https://conxian.io/metadata/cxs.json")

;; Token state
(define-data-var total-supply uint u0)
(define-map balances { account: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })
(define-map staking-positions { account: principal } { 
  amount: uint,
  start-block: uint,
  rewards-claimed: uint,
  lock-period: uint
})

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)

;; Staking parameters
(define-constant MIN_STAKE_AMOUNT u1000000) ;; 1 STX equivalent
(define-constant MAX_STAKE_AMOUNT u1000000000000) ;; 1M STX equivalent
(define-constant MIN_LOCK_PERIOD u10080) ;; 1 day in blocks (3s per block)
(define-constant MAX_LOCK_PERIOD u31536000) ;; 1 year in blocks
(define-constant REWARD_RATE u100) ;; 1% annual rate in basis points

;; Events
(define-event (transfer-mint (sender principal) (recipient principal) (amount uint)))
(define-event (transfer-burn (sender principal) (amount uint)))
(define-event (transfer (sender principal) (recipient principal) (amount uint)))
(define-event (approve (owner principal) (spender principal) (amount uint)))
(define-event (stake-started (account principal) (amount uint) (lock-period uint)))
(define-event (stake-extended (account principal) (new-lock-period uint)))
(define-event (stake-ended (account principal) (amount uint) (rewards uint)))
(define-event (rewards-claimed (account principal) (rewards uint)))

;; Read-only functions

(define-read-only (get-name)
  TOKEN_NAME)

(define-read-only (get-symbol)
  TOKEN_SYMBOL)

(define-read-only (get-decimals)
  TOKEN_DECIMALS)

(define-read-only (get-token-uri)
  TOKEN_URI)

(define-read-only (get-total-supply)
  (var-get total-supply))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances { account: account })))

(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances { owner: owner, spender: spender })))

(define-read-only (get-token-id)
  (as-contract tx-sender))

;; Staking-specific read-only functions

(define-read-only (get-staking-position (account principal))
  (map-get? staking-positions { account: account }))

(define-read-only (get-staked-amount (account principal))
  (match (get-staking-position account)
    position (ok (get position amount))
    none (ok u0)
  )
)

(define-read-only (get-stake-lock-period (account principal))
  (match (get-staking-position account)
    position (ok (get position lock-period))
    none (ok u0)
  )
)

(define-read-only (get-stake-start-block (account principal))
  (match (get-staking-position account)
    position (ok (get position start-block))
    none (ok u0)
  )
)

(define-read-only (get-stake-end-block (account principal))
  (match (get-staking-position account)
    position (ok (+ (get position start-block) (get position lock-period)))
    none (ok u0)
  )
)

(define-read-only (is-stake-locked (account principal))
  (match (get-staking-position account)
    position (ok (< block-height (+ (get position start-block) (get position lock-period))))
    none (ok false)
  )
)

(define-read-only (calculate-rewards (account principal))
  (match (get-staking-position account)
    position
      (let ((staked-amount (get position amount))
            (start-block (get position start-block))
            (rewards-claimed (get position rewards-claimed))
            (current-block block-height))
        
        (if (>= current-block (+ start-block (get position lock-period)))
            ;; Stake period ended
            (let ((elapsed-blocks (- (+ start-block (get position lock-period)) start-block)))
              (ok (/ (* staked-amount elapsed-blocks REWARD_RATE) u3650000))) ;; Convert to per-block rate
            ;; Stake still active
            (let ((elapsed-blocks (- current-block start-block)))
              (ok (/ (* staked-amount elapsed-blocks REWARD_RATE) u3650000)))
        )
      )
    none (ok u0)
  )
)

(define-read-only (get-claimable-rewards (account principal))
  (match (get-staking-position account)
    position
      (let ((total-rewards (unwrap-panic (calculate-rewards account)))
            (rewards-claimed (get position rewards-claimed)))
        (ok (- total-rewards rewards-claimed))
      )
    none (ok u0)
  )
)

;; Public functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 4001))
    (asserts! (>= (get-balance from) amount) (err 4002))
    
    ;; Update balances
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    (map-set balances { account: to } { amount: (+ (get-balance to) amount) })
    
    ;; Emit event
    (emit-event (transfer from to amount))
    
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Only contract owner can mint
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 4003))
    (asserts! (> amount u0) (err 4004))
    
    ;; Update total supply and recipient balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances { account: recipient } { amount: (+ (get-balance recipient) amount) })
    
    ;; Emit event
    (emit-event (transfer-mint tx-sender recipient amount))
    
    (ok true)
  )
)

(define-public (burn (amount uint) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 4005))
    (asserts! (>= (get-balance tx-sender) amount) (err 4006))
    
    ;; Update total supply and sender balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: tx-sender } { amount: (- (get-balance tx-sender) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn tx-sender amount))
    
    (ok true)
  )
)

(define-public (approve (amount uint) (spender principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 4007))
    
    ;; Set allowance
    (map-set allowances { owner: tx-sender, spender: spender } { amount: amount })
    
    ;; Emit event
    (emit-event (approve tx-sender spender amount))
    
    (ok true)
  )
)

(define-public (transfer-from (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 4008))
    (asserts! (>= (get-balance from) amount) (err 4009))
    (asserts! (>= (get-allowance from tx-sender) amount) (err 4010))
    
    ;; Update allowance
    (map-set allowances { owner: from, spender: tx-sender } { 
      amount: (- (get-allowance from tx-sender) amount) 
    })
    
    ;; Update balances
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    (map-set balances { account: to } { amount: (+ (get-balance to) amount) })
    
    ;; Emit event
    (emit-event (transfer from to amount))
    
    (ok true)
  )
)

;; Staking functions

(define-public (start-stake (amount uint) (lock-period uint))
  (begin
    (asserts! (> amount u0) (err 4011))
    (asserts! (>= (get-balance tx-sender) amount) (err 4012))
    (asserts! (>= amount MIN_STAKE_AMOUNT) (err 4013))
    (asserts! (<= amount MAX_STAKE_AMOUNT) (err 4014))
    (asserts! (>= lock-period MIN_LOCK_PERIOD) (err 4015))
    (asserts! (<= lock-period MAX_LOCK_PERIOD) (err 4016))
    
    ;; Check if user already has a stake
    (match (get-staking-position tx-sender)
      position (err 4017) ;; Already has a stake
      none
        (begin
          ;; Create staking position
          (map-set staking-positions { account: tx-sender } {
            amount: amount,
            start-block: block-height,
            rewards-claimed: u0,
            lock-period: lock-period
          })
          
          ;; Transfer tokens to contract (burn and mint as staked)
          (map-set balances { account: tx-sender } { amount: (- (get-balance tx-sender) amount) })
          
          ;; Emit event
          (emit-event (stake-started tx-sender amount lock-period))
          
          (ok true)
        )
    )
  )
)

(define-public (extend-stake (new-lock-period uint))
  (begin
    (asserts! (>= new-lock-period MIN_LOCK_PERIOD) (err 4018))
    (asserts! (<= new-lock-period MAX_LOCK_PERIOD) (err 4019))
    
    ;; Get existing position
    (match (get-staking-position tx-sender)
      position
        (begin
          (asserts! (>= new-lock-period (get position lock-period)) (err 4020)) ;; Can only extend
          
          ;; Update lock period
          (map-set staking-positions { account: tx-sender } {
            amount: (get position amount),
            start-block: (get position start-block),
            rewards-claimed: (get position rewards-claimed),
            lock-period: new-lock-period
          })
          
          ;; Emit event
          (emit-event (stake-extended tx-sender new-lock-period))
          
          (ok true)
        )
      none (err 4021) ;; No existing stake
    )
  )
)

(define-public (end-stake)
  (begin
    ;; Get existing position
    (match (get-staking-position tx-sender)
      position
        (begin
          (asserts! (>= block-height (+ (get position start-block) (get position lock-period))) (err 4022)) ;; Lock period ended
          
          (let ((staked-amount (get position amount))
                (rewards (unwrap-panic (calculate-rewards tx-sender))))
            
            ;; Return staked tokens
            (map-set balances { account: tx-sender } { amount: (+ (get-balance tx-sender) staked-amount) })
            
            ;; Mint rewards
            (if (> rewards u0)
                (begin
                  (var-set total-supply (+ (var-get total-supply) rewards))
                  (map-set balances { account: tx-sender } { amount: (+ (get-balance tx-sender) rewards) })
                )
                true
            )
            
            ;; Remove staking position
            (map-delete staking-positions { account: tx-sender })
            
            ;; Emit events
            (emit-event (stake-ended tx-sender staked-amount rewards))
            
            (ok { staked-amount: staked-amount, rewards: rewards })
          )
        )
      none (err 4023) ;; No existing stake
    )
  )
)

(define-public (claim-rewards)
  (begin
    ;; Get existing position
    (match (get-staking-position tx-sender)
      position
        (begin
          (let ((claimable (unwrap-panic (get-claimable-rewards tx-sender))))
            (asserts! (> claimable u0) (err 4024)) ;; No rewards to claim
            
            ;; Mint rewards
            (var-set total-supply (+ (var-get total-supply) claimable))
            (map-set balances { account: tx-sender } { amount: (+ (get-balance tx-sender) claimable) })
            
            ;; Update rewards claimed
            (map-set staking-positions { account: tx-sender } {
              amount: (get position amount),
              start-block: (get position start-block),
              rewards-claimed: (+ (get position rewards-claimed) claimable),
              lock-period: (get position lock-period)
            })
            
            ;; Emit event
            (emit-event (rewards-claimed tx-sender claimable))
            
            (ok claimable)
          )
        )
      none (err 4025) ;; No existing stake
    )
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 4026))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (emergency-burn (amount uint) (from principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 4027))
    (asserts! (> amount u0) (err 4028))
    (asserts! (>= (get-balance from) amount) (err 4029))
    
    ;; Update total supply and balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn from amount))
    
    (ok true)
  )
)

(define-public (update-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 4030))
    (asserts! (<= new-rate u10000) (err 4031)) ;; Max 100% annual rate
    
    ;; This would update the REWARD_RATE constant (requires different implementation)
    (print {event: "reward-rate-updated", new-rate: new-rate})
    
    (ok true)
  )
)
