;; CXLP Token - Conxian Liquidity Provider Token
;; SIP-010 Fungible Token representing liquidity provider shares

;; Import SIP-010 trait
(impl-trait .sip-standards.sip-010-ft-trait)

;; Token metadata
(define-constant TOKEN_NAME "Conxian Liquidity Provider Token")
(define-constant TOKEN_SYMBOL "CXLP")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI "https://conxian.io/metadata/cxlp.json")

;; Token state
(define-data-var total-supply uint u0)
(define-map balances { account: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })
(define-map pool-shares { pool: principal, account: principal } { shares: uint })

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)

;; Events
(define-event (transfer-mint (sender principal) (recipient principal) (amount uint)))
(define-event (transfer-burn (sender principal) (amount uint)))
(define-event (transfer (sender principal) (recipient principal) (amount uint)))
(define-event (approve (owner principal) (spender principal) (amount uint)))
(define-event (liquidity-added (pool principal) (provider principal) (amount uint)))
(define-event (liquidity-removed (pool principal) (provider principal) (amount uint)))

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

;; Pool-specific read-only functions

(define-read-only (get-pool-shares (pool principal) (account principal))
  (default-to u0 (map-get? pool-shares { pool: pool, account: account })))

(define-read-only (get-total-pool-shares (pool principal))
  (fold (map-keys balances) u0 
    (lambda ((total uint) (account principal))
      (+ total (get-pool-shares pool account)))
  )
)

(define-read-only (get-pool-share-percentage (pool principal) (account principal))
  (let ((user-shares (get-pool-shares pool account))
        (total-shares (get-total-pool-shares pool)))
    (if (> total-shares u0)
        (/ (* user-shares u10000) total-shares)
        u0)
  )
)

;; Public functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 3001))
    (asserts! (>= (get-balance from) amount) (err 3002))
    
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
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 3003))
    (asserts! (> amount u0) (err 3004))
    
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
    (asserts! (> amount u0) (err 3005))
    (asserts! (>= (get-balance tx-sender) amount) (err 3006))
    
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
    (asserts! (> amount u0) (err 3007))
    
    ;; Set allowance
    (map-set allowances { owner: tx-sender, spender: spender } { amount: amount })
    
    ;; Emit event
    (emit-event (approve tx-sender spender amount))
    
    (ok true)
  )
)

(define-public (transfer-from (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 3008))
    (asserts! (>= (get-balance from) amount) (err 3009))
    (asserts! (>= (get-allowance from tx-sender) amount) (err 3010))
    
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

;; Liquidity functions

(define-public (mint-for-liquidity (pool principal) (provider principal) (amount uint))
  (begin
    ;; Only authorized contracts can mint for liquidity
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-eq tx-sender (var-get admin))
      (contract-call? .dex-facade is-authorized-pool pool)
    ) (err 3011))
    
    (asserts! (> amount u0) (err 3012))
    
    ;; Update total supply and provider balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances { account: provider } { amount: (+ (get-balance provider) amount) })
    
    ;; Update pool shares
    (map-set pool-shares { pool: pool, account: provider } { 
      shares: (+ (get-pool-shares pool provider) amount) 
    })
    
    ;; Emit events
    (emit-event (transfer-mint tx-sender provider amount))
    (emit-event (liquidity-added pool provider amount))
    
    (ok true)
  )
)

(define-public (burn-for-liquidity (pool principal) (provider principal) (amount uint))
  (begin
    ;; Only authorized contracts can burn for liquidity
    (asserts! (or 
      (is-eq tx-sender CONTRACT_OWNER)
      (is-eq tx-sender (var-get admin))
      (contract-call? .dex-facade is-authorized-pool pool)
    ) (err 3013))
    
    (asserts! (> amount u0) (err 3014))
    (asserts! (>= (get-balance provider) amount) (err 3015))
    
    ;; Update total supply and provider balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: provider } { amount: (- (get-balance provider) amount) })
    
    ;; Update pool shares
    (let ((current-shares (get-pool-shares pool provider)))
      (if (>= current-shares amount)
          (map-set pool-shares { pool: pool, account: provider } { 
            shares: (- current-shares amount) 
          })
          (map-delete pool-shares { pool: pool, account: provider })
      )
    )
    
    ;; Emit events
    (emit-event (transfer-burn provider amount))
    (emit-event (liquidity-removed pool provider amount))
    
    (ok true)
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 3016))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (emergency-burn (amount uint) (from principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 3017))
    (asserts! (> amount u0) (err 3018))
    (asserts! (>= (get-balance from) amount) (err 3019))
    
    ;; Update total supply and balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn from amount))
    
    (ok true)
  )
)

;; Utility functions

(define-read-only (is-liquidity-token)
  true)

(define-read-only (get-liquidity-provider-count (pool principal))
  (fold (map-keys balances) u0 
    (lambda ((count uint) (account principal))
      (if (> (get-pool-shares pool account) u0)
          (+ count u1)
          count)
    )
  )
)

(define-read-only (get-top-liquidity-providers (pool principal) (limit uint))
  (begin
    (asserts! (> limit u0) (err 3020))
    (asserts! (<= limit u100) (err 3021))
    
    ;; Get all providers with shares and sort by amount
    (let ((providers (fold (map-keys balances) (list 0 principal)
      (lambda ((list (list 10 principal)) (account principal))
        (if (> (get-pool-shares pool account) u0)
            (append list account)
            list)
      ))))
      
    ;; Return top providers (simplified - would need proper sorting in production)
    (if (> (len providers) limit)
        (slice providers u0 limit)
        providers)
  )
)
