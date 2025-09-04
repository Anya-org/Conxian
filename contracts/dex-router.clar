;; Conxian DEX Router - User-friendly interface for DEX interactions
;; Provides single-hop trading and liquidity management with slippage protection

(use-trait sip10 .sip-010-trait.sip-010-trait)
(use-trait pool .pool-trait.pool-trait)

;; Constants
(define-constant ERR_INVALID_POOL (err u4001))
(define-constant ERR_INVALID_PATH (err u4002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u4003))
(define-constant ERR_DEADLINE_PASSED (err u4004))
(define-constant ERR_INVALID_AMOUNT (err u4005))

;; Read-only functions
(define-read-only (resolve-pool (token-x principal) (token-y principal))
  (contract-call? .dex-factory get-pool token-x token-y))

(define-read-only (get-amount-out-direct (pool <pool>) (amount-in uint) (x-to-y bool))
  "Get expected output amount for a trade"
  (let ((reserves (unwrap! (contract-call? pool get-reserves) ERR_INVALID_POOL))
        (fee-info (unwrap! (contract-call? pool get-fee-info) ERR_INVALID_POOL))
        (reserve-in (if x-to-y (get reserve-a reserves) (get reserve-b reserves)))
        (reserve-out (if x-to-y (get reserve-b reserves) (get reserve-a reserves)))
        (lp-fee-bps (get lp-fee-bps fee-info))
        (amount-in-with-fee (- amount-in (/ (* amount-in lp-fee-bps) u10000))))
    (ok (/ (* amount-in-with-fee reserve-out) (+ reserve-in amount-in-with-fee)))))

(define-read-only (get-amounts-out (amount-in uint) (path (list 3 principal)))
  "Get expected output amounts for a trading path"
  (if (is-eq (len path) u2)
      ;; Single hop
      (match (resolve-pool (unwrap! (element-at path u0) ERR_INVALID_PATH)
                          (unwrap! (element-at path u1) ERR_INVALID_PATH))
        pool-addr (let ((pool-contract (unwrap! (contract-of pool-addr) ERR_INVALID_POOL)))
                    (get-amount-out-direct pool-contract amount-in true))
        ERR_INVALID_POOL)
      ;; Multi-hop not implemented yet
      ERR_INVALID_PATH))

;; Core router functions
(define-public (add-liquidity-direct (pool <pool>) (dx uint) (dy uint) (min-shares uint) (deadline uint))
  "Add liquidity to a specific pool"
  (begin
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (asserts! (and (> dx u0) (> dy u0)) ERR_INVALID_AMOUNT)
    
    ;; Get pool tokens for transfers
    (let ((token-a (unwrap! (contract-call? pool get-token-a) ERR_INVALID_POOL))
          (token-b (unwrap! (contract-call? pool get-token-b) ERR_INVALID_POOL)))
      
      ;; Transfer tokens from user to pool
      (try! (contract-call? token-a transfer dx tx-sender (contract-of pool) none))
      (try! (contract-call? token-b transfer dy tx-sender (contract-of pool) none))
      
      ;; Add liquidity to pool
      (contract-call? pool add-liquidity dx dy min-shares))))

(define-public (remove-liquidity-direct (pool <pool>) (shares uint) (min-dx uint) (min-dy uint) (deadline uint))
  "Remove liquidity from a specific pool"
  (begin
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    
    ;; Remove liquidity from pool
    (let ((result (try! (contract-call? pool remove-liquidity shares min-dx min-dy))))
      
      ;; Get pool tokens for transfers
      (let ((token-a (unwrap! (contract-call? pool get-token-a) ERR_INVALID_POOL))
            (token-b (unwrap! (contract-call? pool get-token-b) ERR_INVALID_POOL))
            (amount-a (get amount-a result))
            (amount-b (get amount-b result)))
        
        ;; Transfer tokens from pool to user
        (try! (as-contract (contract-call? token-a transfer amount-a 
                                         (contract-of pool) tx-sender none)))
        (try! (as-contract (contract-call? token-b transfer amount-b 
                                         (contract-of pool) tx-sender none)))
        
        (ok result)))))

(define-public (swap-exact-in-direct (pool <pool>) (amount-in uint) (min-out uint) (x-to-y bool) (deadline uint))
  "Swap exact input amount for minimum output amount"
  (begin
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    
    ;; Get pool tokens
    (let ((token-a (unwrap! (contract-call? pool get-token-a) ERR_INVALID_POOL))
          (token-b (unwrap! (contract-call? pool get-token-b) ERR_INVALID_POOL))
          (token-in (if x-to-y token-a token-b))
          (token-out (if x-to-y token-b token-a)))
      
      ;; Transfer input token from user to pool
      (try! (contract-call? token-in transfer amount-in tx-sender (contract-of pool) none))
      
      ;; Execute swap
      (let ((swap-result (try! (contract-call? pool swap-exact-in amount-in min-out x-to-y deadline))))
        
        ;; Transfer output token from pool to user
        (try! (as-contract (contract-call? token-out transfer 
                                         (get amount-out swap-result)
                                         (contract-of pool) tx-sender none)))
        
        (ok swap-result)))))

(define-public (swap-exact-out-direct (pool <pool>) (max-in uint) (amount-out uint) (x-to-y bool) (deadline uint))
  "Swap maximum input for exact output amount (simplified implementation)"
  (begin
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (asserts! (> amount-out u0) ERR_INVALID_AMOUNT)
    
    ;; For now, calculate required input and use swap-exact-in
    ;; In production, would need actual swap-exact-out implementation
    (let ((reserves (unwrap! (contract-call? pool get-reserves) ERR_INVALID_POOL))
          (fee-info (unwrap! (contract-call? pool get-fee-info) ERR_INVALID_POOL))
          (reserve-in (if x-to-y (get reserve-a reserves) (get reserve-b reserves)))
          (reserve-out (if x-to-y (get reserve-b reserves) (get reserve-a reserves)))
          (lp-fee-bps (get lp-fee-bps fee-info))
          ;; Calculate required input (approximate)
          (required-input (/ (* amount-out reserve-in) (- reserve-out amount-out)))
          (required-input-with-fee (/ (* required-input u10000) (- u10000 lp-fee-bps))))
      
      (asserts! (<= required-input-with-fee max-in) ERR_INSUFFICIENT_OUTPUT)
      
      ;; Use swap-exact-in with calculated input
      (swap-exact-in-direct pool required-input-with-fee amount-out x-to-y deadline))))

;; Multi-hop trading (basic implementation)
(define-public (swap-exact-tokens-for-tokens (amount-in uint) (min-amount-out uint) (path (list 3 principal)) (deadline uint))
  "Swap tokens through a trading path"
  (begin
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    
    (if (is-eq (len path) u2)
        ;; Single hop swap
        (let ((token-a (unwrap! (element-at path u0) ERR_INVALID_PATH))
              (token-b (unwrap! (element-at path u1) ERR_INVALID_PATH)))
          (match (resolve-pool token-a token-b)
            pool-addr (let ((pool-contract (unwrap! (contract-of pool-addr) ERR_INVALID_POOL)))
                        (swap-exact-in-direct pool-contract amount-in min-amount-out true deadline))
            ERR_INVALID_POOL))
        ;; Multi-hop not implemented
        ERR_INVALID_PATH)))

;; Liquidity management helpers
(define-public (create-pool-and-add-liquidity (token-a <sip10>) (token-b <sip10>) 
                                              (amount-a uint) (amount-b uint) 
                                              (fee-bps uint) (min-shares uint) (deadline uint))
  "Create a new pool and add initial liquidity"
  (let ((token-a-principal (contract-of token-a))
        (token-b-principal (contract-of token-b)))
    
    ;; Create pool
    (let ((pool-addr (try! (contract-call? .dex-factory create-pool token-a-principal token-b-principal fee-bps))))
      
      ;; Add liquidity to new pool
      (let ((pool-contract (unwrap! (contract-of pool-addr) ERR_INVALID_POOL)))
        (add-liquidity-direct pool-contract amount-a amount-b min-shares deadline)))))

;; Quote functions for frontend integration
(define-read-only (quote (amount-a uint) (reserve-a uint) (reserve-b uint))
  "Calculate equivalent amount of token B for amount of token A"
  (if (and (> amount-a u0) (> reserve-a u0) (> reserve-b u0))
      (ok (/ (* amount-a reserve-b) reserve-a))
      (ok u0)))

(define-read-only (get-amount-in (amount-out uint) (reserve-in uint) (reserve-out uint) (fee-bps uint))
  "Calculate required input amount for desired output"
  (if (and (> amount-out u0) (> reserve-in u0) (> reserve-out amount-out))
      (let ((numerator (* reserve-in amount-out u10000))
            (denominator (* (- reserve-out amount-out) (- u10000 fee-bps))))
        (ok (+ (/ numerator denominator) u1)))
      (ok u0)))

;; Emergency functions
(define-public (emergency-withdraw-stuck-tokens (token <sip10>) (amount uint) (recipient principal))
  "Emergency function to recover stuck tokens (admin only)"
  (begin
    ;; In production, would check admin permissions
    (as-contract (contract-call? token transfer amount (as-contract tx-sender) recipient none))))

;; Integration with enhanced tokenomics
(define-public (update-router-rewards)
  "Update router rewards integration"
  (begin
    (contract-call? .token-system-coordinator update-dex-router-rewards (as-contract tx-sender))
    (ok true)))

;; Helper for getting optimal pool for trading
(define-read-only (get-optimal-pool (token-a principal) (token-b principal) (amount uint))
  "Get the best pool for trading between two tokens"
  (match (resolve-pool token-a token-b)
    pool (let ((stats (unwrap-panic (contract-call? .dex-factory get-pool-stats pool))))
           (ok (tuple (pool pool) (liquidity (get liquidity stats)))))
    (err ERR_INVALID_POOL)))
