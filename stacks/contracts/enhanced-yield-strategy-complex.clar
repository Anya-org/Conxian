;; =============================================================================
;; ENHANCED YIELD STRATEGY (COMPLEX VARIANT) - HARDENED
;; Implements multi-strategy management with share-based accounting.
;; Added: trait compliance wrappers, accurate share supply tracking, events for
;; all admin/state transitions, safer math placeholders (still simplified).
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
;; Correct trait name inside strategy-trait contract
(use-trait strategy-trait .strategy-trait.auto-strategy-trait)

;; Error codes (u800+ reserved for strategy complex)
(define-constant ERR_UNAUTHORIZED (err u800))
(define-constant ERR_STRATEGY_PAUSED (err u801))
(define-constant ERR_INSUFFICIENT_BALANCE (err u802))
(define-constant ERR_INVALID_STRATEGY (err u803))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u804))
(define-constant ERR_RISK_LIMIT_EXCEEDED (err u805))
(define-constant ERR_COOLDOWN_ACTIVE (err u806))
(define-constant ERR_INVALID_ALLOCATION (err u807))

;; Constants
(define-constant MAX_STRATEGIES u10)
(define-constant MAX_ALLOCATION_BPS u10000) ;; 100%
(define-constant REBALANCE_COOLDOWN u144) ;; ~24 hours
(define-constant MIN_HARVEST_INTERVAL u6)
(define-constant PERFORMANCE_FEE_BPS u500) ;; 5%

;; Strategy registry
(define-map strategies
  uint
  {
    name: (string-ascii 50),
    contract: principal,
    active: bool,
    risk-level: uint,
    target-apy: uint,
    current-allocation: uint,
    max-allocation: uint,
    total-assets: uint,
    last-harvest: uint,
    performance-fee: uint
  })

;; Optional yield period history (simplified)
(define-map yield-history
  {strategy-id: uint, period: uint}
  {
    start-block: uint,
    end-block: uint,
    starting-assets: uint,
    ending-assets: uint,
    yield-earned: uint,
    apy-achieved: uint
  })

;; User allocations (amount & shares)
(define-map user-allocations
  {user: principal, strategy-id: uint}
  {
    amount: uint,
    shares: uint,
    entry-block: uint,
    last-compound: uint
  })

;; Performance metrics (simplified placeholders)
(define-map performance-metrics
  uint
  {
    total-yield-generated: uint,
    total-fees-collected: uint,
    best-apy: uint,
    worst-apy: uint,
    avg-apy: uint,
    sharpe-ratio: uint,
    max-drawdown: uint
  })

;; Total issued shares per strategy
(define-map strategy-share-supply uint uint)

;; State variables
(define-data-var strategy-manager principal tx-sender)
(define-data-var next-strategy-id uint u1)
(define-data-var total-assets-under-management uint u0)
(define-data-var auto-compound-enabled bool true)
(define-data-var risk-tolerance uint u3)
(define-data-var last-rebalance uint u0)
(define-data-var default-strategy-id uint u0) ;; for trait wrapper
(define-data-var default-token principal 'SP000000000000000000002Q6VF78) ;; placeholder

;; =============================================================================
;; CORE YIELD STRATEGY FUNCTIONS
;; =============================================================================

;; Deposit into yield strategy (simplified balanced structure)
(define-public (deposit-to-strategy (strategy-id uint) (token <ft-trait>) (amount uint) (min-shares uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    (asserts! (get active strategy) ERR_STRATEGY_PAUSED)
    (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
    (let ((new-allocation (+ (get current-allocation strategy) amount)))
      (asserts! (<= new-allocation (get max-allocation strategy)) ERR_INVALID_ALLOCATION)
      (let ((existing-total (get total-assets strategy))
            (issued (get-strategy-total-shares strategy-id)))
        (let ((shares (if (is-eq existing-total u0)
                        amount
                        (/ (* amount issued) (if (is-eq existing-total u0) u1 existing-total)))))
          (asserts! (>= shares min-shares) ERR_SLIPPAGE_EXCEEDED)
          (try! (contract-call? token transfer amount tx-sender (get contract strategy) none))
          (try! (execute-strategy-deposit strategy-id amount))
          (map-set user-allocations {user: tx-sender, strategy-id: strategy-id} {
            amount: (+ amount (get-user-allocation tx-sender strategy-id)),
            shares: (+ shares (get-user-shares tx-sender strategy-id)),
            entry-block: block-height,
            last-compound: block-height
          })
          (map-set strategy-share-supply strategy-id (+ shares issued))
          (map-set strategies strategy-id (merge strategy {
            current-allocation: new-allocation,
            total-assets: (+ (get total-assets strategy) amount)
          }))
          (var-set total-assets-under-management (+ (var-get total-assets-under-management) amount))
          (print {event: "strategy-deposit", user: tx-sender, strategy-id: strategy-id, amount: amount, shares: shares, new-total: new-allocation})
          (ok shares)))))

;; Withdraw from yield strategy (simplified balanced structure)
(define-public (withdraw-from-strategy (strategy-id uint) (shares uint) (min-amount uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY))
        (user-allocation (get-user-allocation-record tx-sender strategy-id)))
    (asserts! (>= (get shares user-allocation) shares) ERR_INSUFFICIENT_BALANCE)
    (let ((total-shares (get-strategy-total-shares strategy-id))
          (strategy-assets (get total-assets strategy)))
      (let ((withdrawal-amount (if (or (is-eq total-shares u0) (is-eq strategy-assets u0)) u0 (/ (* shares strategy-assets) (if (is-eq total-shares u0) u1 total-shares)))))
        (asserts! (>= withdrawal-amount min-amount) ERR_SLIPPAGE_EXCEEDED)
        (let ((actual-amount (try! (execute-strategy-withdrawal strategy-id withdrawal-amount))))
          (map-set user-allocations {user: tx-sender, strategy-id: strategy-id}
            (merge user-allocation {amount: (- (get amount user-allocation) actual-amount), shares: (- (get shares user-allocation) shares)}))
          (let ((s (get-strategy-total-shares strategy-id)))
            (map-set strategy-share-supply strategy-id (if (> s shares) (- s shares) u0)))
          (map-set strategies strategy-id (merge strategy {current-allocation: (- (get current-allocation strategy) actual-amount), total-assets: (- (get total-assets strategy) actual-amount)}))
          (var-set total-assets-under-management (- (var-get total-assets-under-management) actual-amount))
          (print {event: "strategy-withdrawal", user: tx-sender, strategy-id: strategy-id, shares: shares, amount: actual-amount})
          (ok actual-amount))))))

;; =============================================================================
;; STRATEGY EXECUTION
;; =============================================================================

;; Execute strategy-specific deposit (balanced)
(define-private (execute-strategy-deposit (strategy-id uint) (amount uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY))
        (strategy-name (get name strategy)))
    (if (is-eq strategy-name "stacking")
      (execute-stacking-deposit strategy-id amount)
      (if (is-eq strategy-name "alex-farming")
        (execute-alex-farming-deposit strategy-id amount)
        (if (is-eq strategy-name "liquidity-mining")
          (execute-lm-deposit strategy-id amount)
          (if (is-eq strategy-name "yield-aggregator")
            (execute-aggregator-deposit strategy-id amount)
            (ok amount))))))

;; Execute strategy-specific withdrawal (balanced)
(define-private (execute-strategy-withdrawal (strategy-id uint) (amount uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY))
        (strategy-name (get name strategy)))
    (if (is-eq strategy-name "stacking")
      (execute-stacking-withdrawal strategy-id amount)
      (if (is-eq strategy-name "alex-farming")
        (execute-alex-farming-withdrawal strategy-id amount)
        (if (is-eq strategy-name "liquidity-mining")
          (execute-lm-withdrawal strategy-id amount)
          (if (is-eq strategy-name "yield-aggregator")
            (execute-aggregator-withdrawal strategy-id amount)
            (ok amount))))))

;; =============================================================================
;; SPECIFIC STRATEGY IMPLEMENTATIONS
;; =============================================================================

;; Stacking strategy (Bitcoin-native yield)
(define-private (execute-stacking-deposit (strategy-id uint) (amount uint))
  ;; Implement Stacking protocol integration
  ;; This would delegate STX to Stacking pools
  (print {event: "stacking-deposit", strategy-id: strategy-id, amount: amount})
  (ok amount))

(define-private (execute-stacking-withdrawal (strategy-id uint) (amount uint))
  ;; Implement Stacking withdrawal
  (print {event: "stacking-withdrawal", strategy-id: strategy-id, amount: amount})
  (ok amount))

;; ALEX protocol farming strategy
(define-private (execute-alex-farming-deposit (strategy-id uint) (amount uint))
  ;; Implement ALEX LP farming integration
  (print {event: "alex-farming-deposit", strategy-id: strategy-id, amount: amount})
  (ok amount))

(define-private (execute-alex-farming-withdrawal (strategy-id uint) (amount uint))
  ;; Implement ALEX farming withdrawal
  (print {event: "alex-farming-withdrawal", strategy-id: strategy-id, amount: amount})
  (ok amount))

;; Liquidity mining strategy
(define-private (execute-lm-deposit (strategy-id uint) (amount uint))
  ;; Implement liquidity mining integration
  (print {event: "lm-deposit", strategy-id: strategy-id, amount: amount})
  (ok amount))

(define-private (execute-lm-withdrawal (strategy-id uint) (amount uint))
  ;; Implement liquidity mining withdrawal
  (print {event: "lm-withdrawal", strategy-id: strategy-id, amount: amount})
  (ok amount))

;; Yield aggregator strategy
(define-private (execute-aggregator-deposit (strategy-id uint) (amount uint))
  ;; Implement multi-protocol yield aggregation
  (print {event: "aggregator-deposit", strategy-id: strategy-id, amount: amount})
  (ok amount))

(define-private (execute-aggregator-withdrawal (strategy-id uint) (amount uint))
  ;; Implement aggregator withdrawal
  (print {event: "aggregator-withdrawal", strategy-id: strategy-id, amount: amount})
  (ok amount))

;; =============================================================================
;; YIELD HARVESTING & COMPOUNDING
;; =============================================================================

;; Harvest yields from strategy
(define-public (harvest-strategy (strategy-id uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    
    (asserts! (get active strategy) ERR_STRATEGY_PAUSED)
    (asserts! (>= (- block-height (get last-harvest strategy)) MIN_HARVEST_INTERVAL) 
              ERR_COOLDOWN_ACTIVE)
    
    ;; Execute harvest
    (let ((yield-earned (try! (execute-strategy-harvest strategy-id))))
      
      ;; Calculate performance fee
      (let ((performance-fee (/ (* yield-earned PERFORMANCE_FEE_BPS) MAX_ALLOCATION_BPS))
            (net-yield (- yield-earned performance-fee)))
        
        ;; Update strategy state
        (map-set strategies strategy-id (merge strategy {
          last-harvest: block-height,
          total-assets: (+ (get total-assets strategy) net-yield)
        }))
        
        ;; Update performance metrics
        (update-performance-metrics strategy-id yield-earned)
        
        ;; Auto-compound if enabled
        (if (var-get auto-compound-enabled)
          (try! (compound-strategy strategy-id net-yield))
          (ok true))
        
        ;; Emit harvest event
        (print {
          event: "strategy-harvested",
          strategy-id: strategy-id,
          yield-earned: yield-earned,
          performance-fee: performance-fee,
          net-yield: net-yield
        })
        
        (ok yield-earned)))))

;; Execute strategy-specific harvest
(define-private (execute-strategy-harvest (strategy-id uint))
  ;; Simplified - would implement actual harvest logic
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    (ok (/ (get total-assets strategy) u100)))) ;; Simulate 1% yield

;; Compound harvested yields
(define-private (compound-strategy (strategy-id uint) (amount uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    
    ;; Reinvest the yield
    (try! (execute-strategy-deposit strategy-id amount))
    
    (print {
      event: "strategy-compounded",
      strategy-id: strategy-id,
      amount: amount
    })
    
    (ok true)))

;; =============================================================================
;; PORTFOLIO REBALANCING
;; =============================================================================

;; Rebalance portfolio across strategies
(define-public (rebalance-portfolio)
  (begin
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-rebalance)) REBALANCE_COOLDOWN) 
              ERR_COOLDOWN_ACTIVE)
    
    ;; Calculate optimal allocations based on risk tolerance and performance
    (let ((rebalance-plan (calculate-optimal-allocations)))
      
      ;; Execute rebalancing
      (try! (execute-rebalancing rebalance-plan))
      
      ;; Update last rebalance time
      (var-set last-rebalance block-height)
      
      (print {
        event: "portfolio-rebalanced",
        timestamp: block-height,
        total-assets: (var-get total-assets-under-management)
      })
      
      (ok true))))

;; Calculate optimal allocations
(define-private (calculate-optimal-allocations)
  ;; Simplified allocation logic - would implement sophisticated optimization
  (list))

;; Execute rebalancing plan
(define-private (execute-rebalancing (plan (list 10 {strategy-id: uint, target-allocation: uint})))
  ;; Simplified - would implement actual rebalancing logic
  (ok true))

;; =============================================================================
;; STRATEGY MANAGEMENT
;; =============================================================================

;; Add new yield strategy
(define-public (add-strategy
  (name (string-ascii 50))
  (contract-principal principal)
  (risk-level uint)
  (target-apy uint)
  (max-allocation uint))
  (let ((strategy-id (var-get next-strategy-id)))
    
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (asserts! (<= risk-level u5) ERR_INVALID_STRATEGY)
    
    (map-set strategies strategy-id {
      name: name,
      contract: contract-principal,
      active: true,
      risk-level: risk-level,
      target-apy: target-apy,
      current-allocation: u0,
      max-allocation: max-allocation,
      total-assets: u0,
      last-harvest: block-height,
      performance-fee: PERFORMANCE_FEE_BPS
    })
    
    ;; Initialize performance metrics
    (map-set performance-metrics strategy-id {
      total-yield-generated: u0,
      total-fees-collected: u0,
      best-apy: u0,
      worst-apy: u0,
      avg-apy: u0,
      sharpe-ratio: u0,
      max-drawdown: u0
    })
    
    (var-set next-strategy-id (+ strategy-id u1))
    
    (print {
      event: "strategy-added",
      strategy-id: strategy-id,
      name: name,
      risk-level: risk-level,
      target-apy: target-apy
    })
    
    (ok strategy-id)))

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

;; Get user allocation amount
(define-private (get-user-allocation (user principal) (strategy-id uint))
  (match (map-get? user-allocations {user: user, strategy-id: strategy-id})
    allocation (get amount allocation)
    u0))

;; Get user shares
(define-private (get-user-shares (user principal) (strategy-id uint))
  (match (map-get? user-allocations {user: user, strategy-id: strategy-id})
    allocation (get shares allocation)
    u0))

;; Get user allocation record
(define-private (get-user-allocation-record (user principal) (strategy-id uint))
  (default-to 
    {amount: u0, shares: u0, entry-block: u0, last-compound: u0}
    (map-get? user-allocations {user: user, strategy-id: strategy-id})))

;; Total issued shares (u0 if none)
(define-private (get-strategy-total-shares (strategy-id uint))
  (default-to u0 (map-get? strategy-share-supply strategy-id)))

;; Update performance metrics
(define-private (update-performance-metrics (strategy-id uint) (yield-earned uint))
  (let ((current-metrics (default-to 
                           {total-yield-generated: u0, total-fees-collected: u0, best-apy: u0, 
                            worst-apy: u0, avg-apy: u0, sharpe-ratio: u0, max-drawdown: u0}
                           (map-get? performance-metrics strategy-id))))
    
    (map-set performance-metrics strategy-id (merge current-metrics {
      total-yield-generated: (+ (get total-yield-generated current-metrics) yield-earned)
    }))
    
    true))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-strategy (strategy-id uint))
  (map-get? strategies strategy-id))

(define-read-only (get-user-position (user principal) (strategy-id uint))
  (map-get? user-allocations {user: user, strategy-id: strategy-id}))

(define-read-only (get-portfolio-summary (user principal))
  {
    total-deposited: (calculate-user-total-deposits user),
    current-value: (calculate-user-current-value user),
    total-yield: (calculate-user-total-yield user),
    active-strategies: (count-user-active-strategies user)
  })

(define-read-only (get-strategy-performance (strategy-id uint))
  (map-get? performance-metrics strategy-id))

(define-read-only (get-total-aum)
  (var-get total-assets-under-management))

;; Simplified helper functions for read-only operations
(define-private (calculate-user-total-deposits (user principal)) u0)
(define-private (calculate-user-current-value (user principal)) u0)
(define-private (calculate-user-total-yield (user principal)) u0)
(define-private (count-user-active-strategies (user principal)) u0)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-auto-compound (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (var-set auto-compound-enabled enabled)
    (print {event: "set-auto-compound", enabled: enabled})
    (ok true)))

(define-public (set-risk-tolerance (new-tolerance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (asserts! (<= new-tolerance u5) ERR_INVALID_STRATEGY)
    (var-set risk-tolerance new-tolerance)
    (print {event: "set-risk-tolerance", value: new-tolerance})
    (ok true)))

(define-public (pause-strategy (strategy-id uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    
    (map-set strategies strategy-id (merge strategy {active: false}))
    
    (print {event: "strategy-paused", strategy-id: strategy-id})
    (ok true)))

(define-public (transfer-management (new-manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (var-set strategy-manager new-manager)
    (print {event: "strategy-manager-transferred", new-manager: new-manager})
    (ok true)))

;; =============================
;; Trait compliance wrappers
;; =============================
(define-public (set-default-strategy (strategy-id uint) (token <ft-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get strategy-manager)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? strategies strategy-id)) ERR_INVALID_STRATEGY)
    (var-set default-strategy-id strategy-id)
    (var-set default-token (contract-of token))
    (print {event: "default-strategy-set", strategy-id: strategy-id, token: (var-get default-token)})
    (ok true)))

(define-private (ensure-default-config)
  (asserts! (> (var-get default-strategy-id) u0) ERR_INVALID_STRATEGY))

(define-public (deposit (amount uint))
  (begin (ensure-default-config) (deposit-to-strategy (var-get default-strategy-id) (var-get default-token) amount amount)))

(define-public (withdraw (shares uint))
  (begin (ensure-default-config) (withdraw-from-strategy (var-get default-strategy-id) shares shares)))

(define-public (harvest)
  (begin (ensure-default-config) (harvest-strategy (var-get default-strategy-id))))

(define-public (get-tvl)
  (begin
    (ensure-default-config)
    (let ((sid (var-get default-strategy-id)))
      (match (map-get? strategies sid)
        strategy (ok (get total-assets strategy))
        ERR_INVALID_STRATEGY))))
