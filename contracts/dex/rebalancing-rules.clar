;; rebalancing-rules.clar
;; Conxian Protocol: Rebalancing rules and automated portfolio management

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVALID_RULE (err 31001))
(define-constant ERR_RULE_NOT_FOUND (err 31002))
(define-constant ERR_INSUFFICIENT_BALANCE (err 31003))
(define-constant ERR_REBALANCE_FAILED (err 31004))
(define-constant ERR_RULE_NOT_ACTIVE (err 31005))

;; Rebalancing parameters
(define-constant MIN_REBALANCE_THRESHOLD u500) ;; 5% threshold
(define-constant MAX_REBALANCE_FREQUENCY u1000) ;; Every 1000 blocks
(define-constant MIN_PORTFOLIO_VALUE u1000000) ;; 1 STX equivalent
(define-constant MAX_SLIPPAGE u300) ;; 3% max slippage
(define-constant REBALANCE_FEE u100) ;; 0.1% fee

;; Data variables
(define-data-var rebalancing-active bool true)
(define-data-var total-rules uint u0)
(define-data-var total-rebalances uint u0)
(define-data-var last-rebalance uint u0)

;; Storage maps
(define-map rebalancing-rules { rule-id: (string-ascii 32) } { 
  name: (string-ascii 64),
  description: (string-ascii 256),
  portfolio: principal,
  target-allocations: (list 10 { token: principal, percentage: uint }),
  rebalance-threshold: uint,
  frequency: uint,
  max-slippage: uint,
  active: bool,
  last-executed: uint,
  execution-count: uint,
  total-value: uint
})

(define-map portfolio-state { portfolio: principal } { 
  current-allocations: (list 10 { token: principal, amount: uint, value: uint }),
  total-value: uint,
  last-updated: uint,
  rebalancing-enabled: bool
})

(define-map rebalance-history { rebalance-id: (buff 32) } { 
  rule-id: (string-ascii 32),
  timestamp: uint,
  before-allocations: (list 10 { token: principal, percentage: uint }),
  after-allocations: (list 10 { token: principal, percentage: uint }),
  trades-executed: uint,
  total-cost: uint,
  success: bool,
  error: (optional (string-ascii 256))
})

(define-map rule-performance { rule-id: (string-ascii 32) } { 
  total-executions: uint,
  successful-executions: uint,
  average-deviation: uint,
  total-cost: uint,
  last-execution: uint,
  performance-score: uint
})

;; Events
(define-event (rule-created (rule-id (string-ascii 32)) (name (string-ascii 64)) (portfolio principal)))
(define-event (rule-executed (rule-id (string-ascii 32)) (rebalance-id (buff 32)) (success bool)))
(define-event (rebalance-completed (rule-id (string-ascii 32)) (portfolio principal) (total-value uint)))
(define-event (rule-deactivated (rule-id (string-ascii 32)))
(define-event (threshold-exceeded (rule-id (string-ascii 32)) (deviation uint)))

;; Read-only functions

(define-read-only (get-rebalancing-rule (rule-id (string-ascii 32)))
  (map-get? rebalancing-rules { rule-id: rule-id }))

(define-read-only (get-rule-name (rule-id (string-ascii 32)))
  (match (get-rebalancing-rule rule_id)
    rule (ok (get rule name))
    none (ok "")
  )
)

(define-read-only (get-rule-portfolio (rule_id (string-ascii 32)))
  (match (get-rebalancing-rule rule_id)
    rule (ok (get rule portfolio))
    none (ok tx-sender)
  )
)

(define-read-only (get-rule-target-allocations (rule_id (string-ascii 32)))
  (match (get-rebalancing-rule rule_id)
    rule (ok (get rule target-allocations))
    none (ok (list 0 { token: principal, percentage: uint }))
  )
)

(define-read-only (is-rule-active (rule_id (string-ascii 32)))
  (match (get-rebalancing-rule rule_id)
    rule (ok (get rule active))
    none (ok false)
  )
)

(define-read-only (get-portfolio-state (portfolio principal))
  (map-get? portfolio-state { portfolio: portfolio }))

(define-read-only (get-rebalance-history (rebalance_id (buff 32)))
  (map-get? rebalance-history { rebalance-id: rebalance_id }))

(define-read-only (get-rule-performance (rule_id (string-ascii 32)))
  (map-get? rule-performance { rule-id: rule_id }))

(define-read-only (is-rebalancing-active)
  (var-get rebalancing-active))

(define-read-only (get-total-rules)
  (var-get total-rules))

(define-read-only (get-total-rebalances)
  (var-get total-rebalances))

;; Public functions

(define-public (create-rebalancing-rule 
  (rule-id (string-ascii 32)) 
  (name (string-ascii 64)) 
  (description (string-ascii 256))
  (portfolio principal)
  (target-allocations (list 10 { token: principal, percentage: uint }))
  (rebalance-threshold uint)
  (frequency uint)
  (max-slippage uint)
)
  (begin
    ;; Validate inputs
    (asserts! (> (len rule-id) u0) ERR_INVALID_RULE)
    (asserts! (> (len name) u0) ERR_INVALID_RULE)
    (asserts! (> (len description) u0) ERR_INVALID_RULE)
    (asserts! (principal? portfolio) ERR_INVALID_RULE)
    (asserts! (> (len target-allocations) u0) ERR_INVALID_RULE)
    (asserts! (> rebalance-threshold u0) ERR_INVALID_RULE)
    (asserts! (> frequency u0) ERR_INVALID_RULE)
    (asserts! (> max-slippage u0) ERR_INVALID_RULE)
    (asserts! (<= max-slippage u10000) ERR_INVALID_RULE)
    (asserts! (var-get rebalancing-active) ERR_RULE_NOT_ACTIVE)
    
    ;; Validate target allocations sum to 100%
    (asserts! (validate-allocation-percentages target-allocations) ERR_INVALID_RULE)
    
    ;; Create rule
    (map-set rebalancing-rules { rule-id: rule-id } {
      name: name,
      description: description,
      portfolio: portfolio,
      target-allocations: target-allocations,
      rebalance-threshold: rebalance-threshold,
      frequency: frequency,
      max-slippage: max-slippage,
      active: true,
      last-executed: u0,
      execution-count: u0,
      total-value: u0
    })
    
    ;; Initialize portfolio state if needed
    (let ((portfolio_info (get-portfolio-state portfolio)))
      (if (is-none portfolio_info)
          (map-set portfolio-state { portfolio: portfolio } {
            current-allocations: (list 0 { token: principal, amount: uint, value: uint }),
            total-value: u0,
            last-updated: block-height,
            rebalancing-enabled: true
          })
          true
      )
    )
    
    ;; Initialize performance tracking
    (map-set rule-performance { rule-id: rule-id } {
      total-executions: u0,
      successful-executions: u0,
      average-deviation: u0,
      total-cost: u0,
      last-execution: u0,
      performance-score: u10000
    })
    
    ;; Update totals
    (var-set total-rules (+ (var-get total-rules) u1))
    
    ;; Emit event
    (emit-event (rule-created rule_id name portfolio))
    
    (ok true)
  )
)

(define-public (execute-rebalancing (rule_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len rule_id) u0) ERR_INVALID_RULE)
    (asserts! (var-get rebalancing-active) ERR_RULE_NOT_ACTIVE)
    
    ;; Check if rule exists and is active
    (let ((rule_info (get-rebalancing-rule rule_id)))
      (asserts! (is-some rule_info) ERR_RULE_NOT_FOUND)
      
      (let ((rule (unwrap-optional rule_info)))
        (asserts! (get rule active) ERR_RULE_NOT_ACTIVE)
        
        ;; Check frequency constraint
        (let ((blocks-since-last (- block-height (get rule last-executed))))
          (asserts! (>= blocks-since-last (get rule frequency)) ERR_REBALANCE_FAILED)
          
          ;; Get current portfolio state
          (let ((portfolio_info (get-portfolio-state (get rule portfolio))))
            (asserts! (is-some portfolio_info) ERR_INSUFFICIENT_BALANCE)
            
            (let ((portfolio (unwrap-optional portfolio_info)))
              ;; Check if rebalancing is needed
              (let ((deviation (calculate-allocation-deviation (get rule target-allocations) (get portfolio current-allocations))))
                (asserts! (>= deviation (get rule rebalance-threshold)) ERR_REBALANCE_FAILED)
                
                ;; Generate rebalance ID
                (let ((rebalance-id (hash160 (concat (string-ascii rule_id) (int-to-buff block-height))))
                      (before-allocations (get-current-percentages (get portfolio current-allocations))))
                  
                  ;; Execute rebalancing
                  (let ((rebalance_result (execute-rebalance-trades rule portfolio deviation)))
                    (match rebalance_result
                      success
                        (begin
                          ;; Update rule state
                          (map-set rebalancing-rules { rule-id: rule_id } {
                            name: (get rule name),
                            description: (get rule description),
                            portfolio: (get rule portfolio),
                            target-allocations: (get rule target-allocations),
                            rebalance-threshold: (get rule rebalance-threshold),
                            frequency: (get rule frequency),
                            max-slippage: (get rule max-slippage),
                            active: (get rule active),
                            last-executed: block-height,
                            execution-count: (+ (get rule execution-count) u1),
                            total-value: (get success total-value)
                          })
                          
                          ;; Update portfolio state
                          (map-set portfolio-state { portfolio: (get rule portfolio) } {
                            current-allocations: (get success new-allocations),
                            total-value: (get success total-value),
                            last-updated: block-height,
                            rebalancing-enabled: (get portfolio rebalancing-enabled)
                          })
                          
                          ;; Create rebalance history record
                          (map-set rebalance-history { rebalance-id: rebalance_id } {
                            rule-id: rule_id,
                            timestamp: block-height,
                            before-allocations: before-allocations,
                            after-allocations: (get-current-percentages (get success new-allocations)),
                            trades-executed: (get success trades-executed),
                            total-cost: (get success total-cost),
                            success: true,
                            error: none
                          })
                          
                          ;; Update performance tracking
                          (update-rule-performance rule_id deviation (get success total-cost) true)
                          
                          ;; Update global counters
                          (var-set total-rebalances (+ (var-get total-rebalances) u1))
                          (var-set last-rebalance block-height)
                          
                          ;; Emit events
                          (emit-event (rule-executed rule_id rebalance_id true))
                          (emit-event (rebalance-completed rule_id (get rule portfolio) (get success total-value)))
                          
                          (ok {
                            rebalance-id: rebalance_id,
                            trades-executed: (get success trades-executed),
                            total-cost: (get success total-cost),
                            new-total-value: (get success total-value)
                          })
                        )
                      error
                        (begin
                          ;; Create failed rebalance record
                          (map-set rebalance-history { rebalance-id: rebalance_id } {
                            rule-id: rule_id,
                            timestamp: block-height,
                            before-allocations: before-allocations,
                            after-allocations: before-allocations,
                            trades-executed: u0,
                            total-cost: u0,
                            success: false,
                            error: (some (unwrap-panic error))
                          })
                          
                          ;; Update performance tracking
                          (update-rule-performance rule_id deviation u0 false)
                          
                          ;; Emit event
                          (emit-event (rule-executed rule_id rebalance_id false))
                          
                          error
                        )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-public (update-portfolio-state (portfolio principal) (allocations (list 10 { token: principal, amount: uint, value: uint })))
  (begin
    ;; Validate inputs
    (asserts! (principal? portfolio) ERR_INVALID_RULE)
    (asserts! (> (len allocations) u0) ERR_INVALID_RULE)
    (asserts! (var-get rebalancing-active) ERR_RULE_NOT_ACTIVE)
    
    ;; Calculate total value
    (let ((total-value (fold allocations u0
      (lambda ((sum uint) (allocation { token: principal, amount: uint, value: uint }))
        (+ sum (get allocation value))
      )
    )))
      
      ;; Update portfolio state
      (map-set portfolio-state { portfolio: portfolio } {
        current-allocations: allocations,
        total-value: total-value,
        last-updated: block-height,
        rebalancing-enabled: true
      })
      
      (ok {
        portfolio: portfolio,
        total-value: total-value,
        allocation-count: (len allocations)
      })
    )
  )
)

(define-public (check-rebalancing-needed (rule_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len rule_id) u0) ERR_INVALID_RULE)
    (asserts! (var-get rebalancing-active) ERR_RULE_NOT_ACTIVE)
    
    ;; Check if rule exists and is active
    (let ((rule_info (get-rebalancing-rule rule_id)))
      (asserts! (is-some rule_info) ERR_RULE_NOT_FOUND)
      
      (let ((rule (unwrap-optional rule_info)))
        (asserts! (get rule active) ERR_RULE_NOT_ACTIVE)
        
        ;; Get current portfolio state
        (let ((portfolio_info (get-portfolio-state (get rule portfolio))))
          (asserts! (is-some portfolio_info) ERR_INSUFFICIENT_BALANCE)
          
          (let ((portfolio (unwrap-optional portfolio_info)))
            ;; Calculate deviation
            (let ((deviation (calculate-allocation-deviation (get rule target-allocations) (get portfolio current-allocations))))
              
              ;; Check if rebalancing is needed
              (let ((needs-rebalance (and (>= deviation (get rule rebalance-threshold))
                                        (>= (- block-height (get rule last-executed)) (get rule frequency)))))
                
                ;; Emit alert if threshold exceeded
                (if (>= deviation (get rule rebalance-threshold))
                    (emit-event (threshold-exceeded rule_id deviation))
                    true
                )
                
                (ok {
                  rule-id: rule_id,
                  deviation: deviation,
                  threshold: (get rule rebalance-threshold),
                  needs-rebalance: needs-rebalance,
                  blocks-since-last: (- block-height (get rule last-executed))
                })
              )
            )
          )
        )
      )
    )
  )
)

(define-public (deactivate-rule (rule_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len rule_id) u0) ERR_INVALID_RULE)
    (asserts! (var-get rebalancing-active) ERR_RULE_NOT_ACTIVE)
    
    ;; Check if rule exists
    (let ((rule_info (get-rebalancing-rule rule_id)))
      (asserts! (is-some rule_info) ERR_RULE_NOT_FOUND)
      
      (let ((rule (unwrap-optional rule_info)))
        ;; Deactivate rule
        (map-set rebalancing-rules { rule-id: rule_id } {
          name: (get rule name),
          description: (get rule description),
          portfolio: (get rule portfolio),
          target-allocations: (get rule target-allocations),
          rebalance-threshold: (get rule rebalance-threshold),
          frequency: (get rule frequency),
          max-slippage: (get rule max-slippage),
          active: false,
          last-executed: (get rule last-executed),
          execution-count: (get rule execution-count),
          total-value: (get rule total-value)
        })
        
        ;; Emit event
        (emit-event (rule-deactivated rule_id))
        
        (ok true)
      )
    )
  )
)

(define-public (set-rebalancing-active (active bool))
  (begin
    ;; Only admin can set rebalancing status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_RULE_NOT_ACTIVE)
    
    (var-set rebalancing-active active)
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { current-allocations: (list 0 { token: principal, amount: uint, value: uint }), total-value: uint, last-updated: uint, rebalancing-enabled: bool } option))

(define-private (validate-allocation-percentages (allocations (list 10 { token: principal, percentage: uint })))
  (begin
    ;; Check that percentages sum to 10000 (100%)
    (let ((total-percentage (fold allocations u0
      (lambda ((sum uint) (allocation { token: principal, percentage: uint }))
        (+ sum (get allocation percentage))
      )
    )))
      (is-eq total-percentage u10000)
    )
  )
)

(define-private (calculate-allocation-deviation (target-allocations (list 10 { token: principal, percentage: uint })) (current-allocations (list 10 { token: principal, amount: uint, value: uint })))
  (begin
    ;; Calculate deviation between target and current allocations
    (let ((current-percentages (get-current-percentages current-allocations)))
      
      ;; Calculate absolute deviation for each token
      (fold target-allocations u0
        (lambda ((total-deviation uint) (target { token: principal, percentage: uint }))
          (let ((current-percentage (get-current-percentage current-percentages (get target token))))
            (+ total-deviation (abs (- (get target percentage) current-percentage)))
          )
        )
      )
    )
  )
)

(define-private (get-current-percentages (allocations (list 10 { token: principal, amount: uint, value: uint })))
  (begin
    ;; Calculate current allocation percentages
    (let ((total-value (fold allocations u0
      (lambda ((sum uint) (allocation { token: principal, amount: uint, value: uint }))
        (+ sum (get allocation value))
      )
    )))
      
      (if (> total-value u0)
          (map allocations
            (lambda ((allocation { token: principal, amount: uint, value: uint }))
              { token: (get allocation token), percentage: (/ (* (get allocation value) u10000) total-value) }
            )
          )
          (list 0 { token: principal, percentage: uint })
      )
    )
  )
)

(define-private (get-current-percentage (percentages (list 10 { token: principal, percentage: uint })) (token principal))
  (begin
    ;; Get percentage for specific token
    (fold percentages u0
      (lambda ((result uint) (percentage { token: principal, percentage: uint }))
        (if (is-eq (get percentage token) token)
            (get percentage percentage)
            result
        )
      )
    )
  )
)

(define-private (execute-rebalance-trades (rule { name: (string-ascii 64), description: (string-ascii 256), portfolio: principal, target-allocations: (list 10 { token: principal, percentage: uint }), rebalance-threshold: uint, frequency: uint, max-slippage: uint, active: bool, last-executed: uint, execution-count: uint, total-value: uint }) (portfolio { current-allocations: (list 10 { token: principal, amount: uint, value: uint }), total-value: uint, last-updated: uint, rebalancing-enabled: bool }) (deviation uint))
  (begin
    ;; Calculate required trades
    (let ((required-trades (calculate-required-trades (get rule target-allocations) (get portfolio current-allocations) (get portfolio total-value))))
      
      ;; Execute trades (simplified - would use actual DEX trades)
      (let ((trade-results (execute-trades required-trades (get rule max-slippage))))
        (match trade-results
          success
            (begin
              ;; Calculate new allocations
              (let ((new-allocations (calculate-new-allocations (get portfolio current-allocations) (get success trades))))
                
                (ok {
                  new-allocations: new-allocations,
                  total-value: (get portfolio total-value), // Would update with actual value
                  trades-executed: (len (get success trades)),
                  total-cost: (get success total-cost)
                })
              )
            )
          error error
        )
      )
    )
  )
)

(define-private (calculate-required-trades (target-allocations (list 10 { token: principal, percentage: uint })) (current-allocations (list 10 { token: principal, amount: uint, value: uint })) (total-value uint))
  (begin
    ;; Calculate required trades to reach target allocations
    (let ((current-percentages (get-current-percentages current-allocations)))
      
      (fold target-allocations (list 0 { token: principal, amount: uint, action: (string-ascii 8) })
        (lambda ((trades (list 10 { token: principal, amount: uint, action: (string-ascii 8) })) (target { token: principal, percentage: uint }))
          (let ((current-percentage (get-current-percentage current-percentages (get target token)))
                (target-value (/ (* total-value (get target percentage)) u10000))
                (current-value (/ (* total-value current-percentage) u10000))
                (difference (- target-value current-value)))
            
            (if (> difference u0)
                ;; Need to buy this token
                (append trades { token: (get target token), amount: difference, action: "buy" })
                ;; Need to sell this token
                (append trades { token: (get target token), amount: (abs difference), action: "sell" })
            )
          )
        )
      )
    )
  )
)

(define-private (execute-trades (trades (list 10 { token: principal, amount: uint, action: (string-ascii 8) })) (max-slippage uint))
  (begin
    ;; Execute trades (simplified implementation)
    ;; In practice, would use actual DEX contracts
    
    (let ((total-cost u0)
          (successful-trades (list 0 { token: principal, amount: uint, price: uint })))
      
      (fold trades { trades: successful-trades, total-cost: total-cost }
        (lambda ((result { trades: (list 10 { token: principal, amount: uint, price: uint }), total-cost: uint }) (trade { token: principal, amount: uint, action: (string-ascii 8) }))
          (begin
            ;; Simulate trade execution
            (let ((trade-price u1000000) // Mock price
                  (trade-cost (/ (* (get trade amount) REBALANCE_FEE) u10000)))
              
              {
                trades: (append (get result trades) { token: (get trade token), amount: (get trade amount), price: trade-price }),
                total-cost: (+ (get result total-cost) trade-cost)
              }
            )
          )
        )
      )
    )
  )
)

(define-private (calculate-new-allocations (current-allocations (list 10 { token: principal, amount: uint, value: uint })) (trades (list 10 { token: principal, amount: uint, price: uint })))
  (begin
    ;; Calculate new allocations after trades
    ;; Simplified implementation
    
    current-allocations
  )
)

(define-private (update-rule-performance (rule_id (string-ascii 32)) (deviation uint) (cost uint) (success bool))
  (begin
    ;; Get current performance
    (let ((performance (get-rule-performance rule_id)))
      (if (is-some performance)
          (begin
            (let ((current-performance (unwrap-optional performance))
                  (total-executions (get current-performance total-executions)))
              
              ;; Update performance
              (map-set rule-performance { rule-id: rule_id } {
                total-executions: (+ total-executions u1),
                successful-executions: (+ (get current-performance successful-executions) (if success u1 u0)),
                average-deviation: (/ (+ (* (get current-performance average-deviation) total-executions) deviation) (+ total-executions u1)),
                total-cost: (+ (get current-performance total-cost) cost),
                last-execution: block-height,
                performance-score: (calculate-performance-score (+ total-executions u1) (+ (get current-performance successful-executions) (if success u1 u0)))
              })
            )
          )
          ;; Create new performance record
          (map-set rule-performance { rule-id: rule_id } {
            total-executions: u1,
            successful-executions: (if success u1 u0),
            average-deviation: deviation,
            total-cost: cost,
            last-execution: block-height,
            performance-score: (if success u10000 u0)
          })
      )
    )
  )
)

(define-private (calculate-performance-score (total-executions uint) (successful-executions uint))
  (begin
    ;; Calculate performance score based on success rate
    (if (> total-executions u0)
        (/ (* successful-executions u10000) total-executions)
        u0
    )
  )
)

;; Utility functions

(define-read-only (get-rebalancing-status)
  {
    active: (var-get rebalancing-active),
    total-rules: (var-get total-rules),
    total-rebalances: (var-get total-rebalances),
    last-rebalance: (var-get last-rebalance)
  }
)

(define-read-only (get-rule-summary (rule_id (string-ascii 32)))
  (match (get-rebalancing-rule rule_id)
    rule
      (ok {
        name: (get rule name),
        portfolio: (get rule portfolio),
        active: (get rule active),
        execution-count: (get rule execution-count),
        last-executed: (get rule last-executed),
        total-value: (get rule total-value)
      })
    none (err ERR_RULE_NOT_FOUND)
  )
)
