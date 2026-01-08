;; CXD Token Price Initializer
;; Initializes the price for the CXD governance token

(define-public (initialize-cxd-price (initial-price uint))
  (begin
    ;; Validate initial price
    (asserts! (> initial-price u0) (err 3001))
    (asserts! (<= initial-price u1000000000) (err 3002)) ;; Max 10,000 STX
    
    ;; Set initial price in the oracle
    (contract-call? .oracle-aggregator-v2 set-price 
      (contract-call? .cxd-token get-token-id) 
      initial-price
    )
    
    ;; Emit initialization event
    (print {event: "cxd-price-initialized", price: initial-price})
    
    (ok true)
  )
)

;; Get current CXD price
(define-public (get-cxd-price)
  (begin
    (match (contract-call? .oracle-aggregator-v2 get-price 
           (contract-call? .cxd-token get-token-id))
      price (ok price)
      error (err 3003)
    )
  )
)

;; Update CXD price (only callable by authorized oracle)
(define-public (update-cxd-price (new-price uint))
  (begin
    ;; Check authorization
    (asserts! (is-eq tx-sender (contract-call? .oracle-aggregator-v2 get-oracle-owner)) (err 3004))
    
    ;; Validate new price
    (asserts! (> new-price u0) (err 3005))
    (asserts! (<= new-price u1000000000) (err 3006)) ;; Max 10,000 STX
    
    ;; Get current price for validation
    (match (get-cxd-price)
      current-price
        (begin
          ;; Validate price change is within reasonable bounds (max 10% change per update)
          (let ((price-change (/ (* (- new-price current-price) u10000) current-price)))
            (asserts! (<= (absolute-value price-change) u1000) (err 3007)) ;; Max 10% change
          )
          
          ;; Update price
          (contract-call? .oracle-aggregator-v2 set-price 
            (contract-call? .cxd-token get-token-id) 
            new-price
          )
          
          ;; Emit update event
          (print {event: "cxd-price-updated", old-price: current-price, new-price: new-price})
          
          (ok true)
        )
      error error
    )
  )
)

;; Validate price is within acceptable range
(define-public (validate-price-range (price uint))
  (begin
    (asserts! (> price u0) (err 3008))
    
    ;; Get reference price from other oracles for validation
    (match (contract-call? .oracle-aggregator-v2 get-reference-price 
           (contract-call? .cxd-token get-token-id))
      reference-price
        (begin
          ;; Allow 20% deviation from reference
          (let ((max-deviation (/ (* reference-price u2000) u10000)))
            (asserts! (<= (absolute-value (- (to-int price) (to-int reference-price))) (to-int max-deviation)) (err 3009))
            (ok true)
          )
        )
      error
        ;; If no reference price, just validate it's positive
        (ok true)
    )
  )
)

;; Emergency price reset (only callable by protocol admin)
(define-public (emergency-reset-price (new-price uint))
  (begin
    ;; Check admin authorization
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) (err 3010))
    
    ;; Validate new price
    (asserts! (> new-price u0) (err 3011))
    (asserts! (<= new-price u1000000000) (err 3012))
    
    ;; Reset price
    (contract-call? .oracle-aggregator-v2 emergency-set-price 
      (contract-call? .cxd-token get-token-id) 
      new-price
    )
    
    ;; Emit emergency reset event
    (print {event: "cxd-price-emergency-reset", price: new-price})
    
    (ok true)
  )
)

;; Get price history
(define-public (get-price-history (limit uint))
  (begin
    (asserts! (> limit u0) (err 3013))
    (asserts! (<= limit u100) (err 3014)) ;; Max 100 historical prices
    
    (contract-call? .oracle-aggregator-v2 get-price-history 
      (contract-call? .cxd-token get-token-id) 
      limit
    )
  )
)

;; Calculate price volatility
(define-public (calculate-volatility (period uint))
  (begin
    (asserts! (> period u0) (err 3015))
    (asserts! (<= period u365) (err 3016)) ;; Max 1 year
    
    (match (get-price-history period)
      history
        (begin
          (asserts! (>= (len history) u2) (err 3017)) ;; Need at least 2 prices
          
          (let ((prices history))
            ;; Calculate standard deviation of price changes
            (let ((price-changes (map 
              (lambda ((price-entry {price: uint, timestamp: uint})))
                (get price-entry price)
              )
              prices)))
              
            (contract-call? .conxian-math standard-deviation price-changes)
          )
        )
      error error
    )
  )
)

;; Helper function for absolute value
(define-private (absolute-value (value int))
  (if (< value 0) (- value) value)
)
