;; AutoVault Multi-Token Strategy Extension
;; Enables acceptance of competitor DeFi tokens for maximum yield optimization
;; Integrates with existing vault.clar for enhanced liquidity aggregation

(use-trait sip010 .sip-010-trait.sip-010-trait)
(impl-trait .vault-admin-trait.vault-admin-trait)

;; Cross-DeFi token integration for competitor protocols
(define-map supported-tokens
  { token: principal }
  { 
    enabled: bool,
    weight: uint,        ;; Allocation weight (bps)
    strategy: principal, ;; Strategy contract for this token
    risk-rating: uint,   ;; 1-5 risk score
    min-balance: uint,   ;; Minimum balance to maintain
    max-allocation: uint ;; Maximum % of vault TVL
  }
)

;; Token balance tracking per supported asset
(define-map token-balances
  { token: principal }
  { balance: uint }
)

;; Yield tracking per token for performance analysis
(define-map token-yields
  { token: principal, period: uint }
  { yield: uint, timestamp: uint }
)

;; Constants for multi-token operations
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_TOKEN_NOT_SUPPORTED u110)
(define-constant ERR_ALLOCATION_EXCEEDED u111)
(define-constant ERR_INSUFFICIENT_BALANCE u112)
(define-constant ERR_INVALID_WEIGHT u113)
(define-constant ERR_RISK_TOO_HIGH u114)
(define-constant BPS_DENOM u10000)
(define-constant MAX_RISK_RATING u5)

(define-data-var admin principal .timelock)
(define-data-var total-supported-tokens uint u0)
(define-data-var rebalance-enabled bool false)
(define-data-var max-tokens uint u10) ;; Maximum supported tokens
(define-data-var min-rebalance-threshold uint u100) ;; 1% threshold

;; Admin functions for token management
(define-public (add-supported-token 
  (token principal) 
  (weight uint) 
  (strategy principal) 
  (risk-rating uint)
  (min-balance uint)
  (max-allocation uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= (var-get total-supported-tokens) (var-get max-tokens)) (err ERR_ALLOCATION_EXCEEDED))
    (asserts! (<= weight BPS_DENOM) (err ERR_INVALID_WEIGHT))
    (asserts! (<= risk-rating MAX_RISK_RATING) (err ERR_RISK_TOO_HIGH))
    (asserts! (<= max-allocation BPS_DENOM) (err ERR_ALLOCATION_EXCEEDED))
    
    (map-set supported-tokens
      { token: token }
      {
        enabled: true,
        weight: weight,
        strategy: strategy,
        risk-rating: risk-rating,
        min-balance: min-balance,
        max-allocation: max-allocation
      }
    )
    
    (map-set token-balances { token: token } { balance: u0 })
    (var-set total-supported-tokens (+ (var-get total-supported-tokens) u1))
    
    (print {
      event: "token-added",
      token: token,
      weight: weight,
      strategy: strategy,
      risk-rating: risk-rating
    })
    (ok true)
  )
)

(define-public (update-token-weight (token principal) (new-weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= new-weight BPS_DENOM) (err ERR_INVALID_WEIGHT))
    
    (let ((token-info (unwrap! (map-get? supported-tokens { token: token }) (err ERR_TOKEN_NOT_SUPPORTED))))
      (map-set supported-tokens 
        { token: token }
        (merge token-info { weight: new-weight }))
      
      (print {
        event: "weight-updated",
        token: token,
        old-weight: (get weight token-info),
        new-weight: new-weight
      })
      (ok true)
    )
  )
)

(define-public (disable-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_NOT_AUTHORIZED))
    
    (let ((token-info (unwrap! (map-get? supported-tokens { token: token }) (err ERR_TOKEN_NOT_SUPPORTED))))
      (map-set supported-tokens 
        { token: token }
        (merge token-info { enabled: false }))
      
      (print {
        event: "token-disabled",
        token: token
      })
      (ok true)
    )
  )
)

;; Multi-token deposit function
(define-public (deposit-multi-token (token <sip010>) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    
    (let ((token-principal (contract-of token))
          (token-info (unwrap! (map-get? supported-tokens { token: token-principal }) (err ERR_TOKEN_NOT_SUPPORTED))))
      
      (asserts! (get enabled token-info) (err ERR_TOKEN_NOT_SUPPORTED))
      
      ;; Check allocation limits
      (let ((current-balance (default-to u0 (get balance (map-get? token-balances { token: token-principal }))))
            (vault-tvl (contract-call? .vault get-tvl))
            (max-allowed (/ (* vault-tvl (get max-allocation token-info)) BPS_DENOM)))
        
        (asserts! (<= (+ current-balance amount) max-allowed) (err ERR_ALLOCATION_EXCEEDED))
        
        ;; Transfer tokens to vault
        (unwrap! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none) (err u200))
        
        ;; Update balances
        (map-set token-balances 
          { token: token-principal } 
          { balance: (+ current-balance amount) })
        
        ;; Calculate equivalent vault shares based on token weight
        (let ((weighted-amount (/ (* amount (get weight token-info)) BPS_DENOM))
              (vault-shares (unwrap! (contract-call? .vault calculate-shares weighted-amount) (err u201))))
          
          (print {
            event: "multi-token-deposit",
            token: token-principal,
            amount: amount,
            weighted-amount: weighted-amount,
            shares: vault-shares,
            caller: tx-sender
          })
          
          (ok vault-shares)
        )
      )
    )
  )
)

;; Automated rebalancing across supported tokens
(define-public (rebalance-portfolio)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (var-get rebalance-enabled) (err u102))
    
    (let ((vault-tvl (contract-call? .vault get-tvl)))
      ;; Iterate through supported tokens and rebalance
      ;; This is a simplified version - production would use iterative rebalancing
      (print {
        event: "rebalance-initiated",
        tvl: vault-tvl,
        timestamp: block-height
      })
      (ok true)
    )
  )
)

;; Cross-protocol yield optimization
(define-public (optimize-yields)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_NOT_AUTHORIZED))
    
    ;; Analyze yields across supported tokens and rebalance for maximum returns
    (let ((optimization-result (calculate-optimal-allocation)))
      (print {
        event: "yield-optimization",
        result: optimization-result,
        timestamp: block-height
      })
      (ok optimization-result)
    )
  )
)

;; Read-only functions
(define-read-only (get-supported-token (token principal))
  (map-get? supported-tokens { token: token })
)

(define-read-only (get-token-balance (token principal))
  (default-to u0 (get balance (map-get? token-balances { token: token })))
)

(define-read-only (get-total-supported-tokens)
  (var-get total-supported-tokens)
)

(define-read-only (is-token-supported (token principal))
  (match (map-get? supported-tokens { token: token })
    token-info (get enabled token-info)
    false
  )
)

(define-read-only (get-portfolio-allocation)
  {
    total-tokens: (var-get total-supported-tokens),
    rebalance-enabled: (var-get rebalance-enabled),
    max-tokens: (var-get max-tokens)
  }
)

;; Private helper functions
(define-private (calculate-optimal-allocation)
  ;; Simplified yield optimization calculation
  ;; Production version would integrate with external yield data
  u100 ;; Return optimization score
)

(define-private (get-token-yield (token principal) (period uint))
  (default-to u0 (get yield (map-get? token-yields { token: token, period: period })))
)

;; Initialize with common Stacks DeFi tokens
(define-private (initialize-default-tokens)
  (begin
    ;; Add STX as base token (example - would be configured by admin)
    ;; Additional tokens would be added via governance proposals
    true
  )
)
