;; precision-calculator.clar
;; Conxian Protocol: Precision calculation utilities for financial operations

;; Constants
(define-constant ERR_INVALID_PRECISION (err 25001))
(define-constant ERR_PRECISION_TOO_HIGH (err 25002))
(define-constant ERR_DIVISION_BY_ZERO (err 25003))
(define-constant ERR_INVALID_INPUT (err 25004))
(define-constant ERR_OVERFLOW (err 25005))

;; Precision constants
(define-constant BASE_PRECISION u1000000) ;; 6 decimal places
(define-constant HIGH_PRECISION u100000000) ;; 8 decimal places
(define-constant MAX_PRECISION u1000000000000000000) ;; 18 decimal places
(define-constant PRECISION_MULTIPLIER u10)

;; Data variables
(define-data-var default-precision uint BASE_PRECISION)
(define-data-var calculator-active bool true)

;; Storage maps
(define-map precision-caches { operation-id: (buff 32) } { 
  input-a: uint,
  input-b: uint,
  result: uint,
  precision: uint,
  operation: (string-ascii 16),
  timestamp: uint
})

(define-map precision-configs { context: (string-ascii 32) } { 
  precision: uint,
  rounding-mode: (string-ascii 8),
  max-decimals: uint,
  active: bool
})

(define-map calculation-history { user: principal } { 
  operations: (list 10 { operation: (string-ascii 16), result: uint, precision: uint, timestamp: uint }),
  total-calculations: uint,
  last-calculation: uint
})

;; Events
(define-event (precision-calculated (operation (string-ascii 16)) (result uint) (precision uint)))
(define-event (precision-updated (context (string-ascii 32)) (old-precision uint) (new-precision uint)))
(define-event (cache-hit (operation-id (buff 32)) (result uint)))
(define-event (overflow-detected (operation (string-ascii 16)) (inputs (list 2 uint))))

;; Read-only functions

(define-read-only (get-default-precision)
  (var-get default-precision))

(define-read-only (get-precision-config (context (string-ascii 32)))
  (map-get? precision-configs { context: context }))

(define-read-only (get-context-precision (context (string-ascii 32)))
  (match (get-precision-config context)
    config (ok (get config precision))
    none (ok (var-get default-precision))
  )
)

(define-read-only (get-cached-result (operation-id (buff 32)))
  (map-get? precision-caches { operation-id: operation-id }))

(define-read-only (get-calculation-history (user principal))
  (map-get? calculation-history { user: user }))

(define-read-only (is-calculator-active)
  (var-get calculator-active))

(define-read-only (get-total-calculations (user principal))
  (match (get-calculation-history user)
    history (ok (get history total-calculations))
    none (ok u0)
  )
)

;; Public functions

(define-public (set-default-precision (precision uint))
  (begin
    ;; Validate precision
    (asserts! (> precision u0) ERR_INVALID_PRECISION)
    (asserts! (<= precision MAX_PRECISION) ERR_PRECISION_TOO_HIGH)
    
    ;; Check if calculator is active
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Update default precision
    (var-set default-precision precision)
    
    (ok true)
  )
)

(define-public (set-context-precision (context (string-ascii 32)) (precision uint) (rounding-mode (string-ascii 8)) (max-decimals uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len context) u0) ERR_INVALID_INPUT)
    (asserts! (> precision u0) ERR_INVALID_PRECISION)
    (asserts! (<= precision MAX_PRECISION) ERR_PRECISION_TOO_HIGH)
    (asserts! (> (len rounding-mode) u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-rounding-mode rounding-mode) ERR_INVALID_INPUT)
    (asserts! (<= max-decimals precision) ERR_INVALID_INPUT)
    
    ;; Check if calculator is active
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get old precision for event
    (let ((old-precision (get-context-precision context)))
      
      ;; Update context precision
      (map-set precision-configs { context: context } {
        precision: precision,
        rounding-mode: rounding-mode,
        max-decimals: max-decimals,
        active: true
      })
      
      ;; Emit event
      (emit-event (precision-updated context (unwrap-optional old-precision) precision))
      
      (ok true)
    )
  )
)

(define-public (add-with-precision (a uint) (b uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (get-context-precision context)))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "add" a b precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Perform calculation
              (let ((result (+ a b)))
                ;; Store in cache
                (map-set precision-caches { operation-id: operation-id } {
                  input-a: a,
                  input-b: b,
                  result: result,
                  precision: (unwrap-optional precision),
                  operation: "add",
                  timestamp: block-height
                })
                
                ;; Update user history
                (update-calculation-history tx-sender "add" result (unwrap-optional precision))
                
                ;; Emit event
                (emit-event (precision-calculated "add" result (unwrap-optional precision)))
                
                (ok result)
              )
            )
        )
      )
    )
  )
)

(define-public (subtract-with-precision (a uint) (b uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (get-context-precision context)))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "subtract" a b precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Check for underflow
              (asserts! (>= a b) ERR_OVERFLOW)
              
              ;; Perform calculation
              (let ((result (- a b)))
                ;; Store in cache
                (map-set precision-caches { operation-id: operation-id } {
                  input-a: a,
                  input-b: b,
                  result: result,
                  precision: (unwrap-optional precision),
                  operation: "subtract",
                  timestamp: block-height
                })
                
                ;; Update user history
                (update-calculation-history tx-sender "subtract" result (unwrap-optional precision))
                
                ;; Emit event
                (emit-event (precision-calculated "subtract" result (unwrap-optional precision)))
                
                (ok result)
              )
            )
        )
      )
    )
  )
)

(define-public (multiply-with-precision (a uint) (b uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (get-context-precision context)))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "multiply" a b precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Check for overflow
              (let ((max-result (/ MAX_UINT b)))
                (asserts! (<= a max-result) ERR_OVERFLOW)
                
                ;; Perform calculation
                (let ((result (* a b)))
                  ;; Store in cache
                  (map-set precision-caches { operation-id: operation-id } {
                    input-a: a,
                    input-b: b,
                    result: result,
                    precision: (unwrap-optional precision),
                    operation: "multiply",
                    timestamp: block-height
                  })
                  
                  ;; Update user history
                  (update-calculation-history tx-sender "multiply" result (unwrap-optional precision))
                  
                  ;; Emit event
                  (emit-event (precision-calculated "multiply" result (unwrap-optional precision)))
                  
                  (ok result)
                )
              )
            )
        )
      )
    )
  )
)

(define-public (divide-with-precision (a uint) (b uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> b u0) ERR_DIVISION_BY_ZERO)
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (unwrap-optional (get-context-precision context))))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "divide" a b precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Perform calculation with precision
              (let ((result (/ (* a precision) b)))
                ;; Store in cache
                (map-set precision-caches { operation-id: operation-id } {
                  input-a: a,
                  input-b: b,
                  result: result,
                  precision: precision,
                  operation: "divide",
                  timestamp: block-height
                })
                
                ;; Update user history
                (update-calculation-history tx-sender "divide" result precision)
                
                ;; Emit event
                (emit-event (precision-calculated "divide" result precision))
                
                (ok result)
              )
            )
        )
      )
    )
  )
)

(define-public (power-with-precision (base uint) (exponent uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (unwrap-optional (get-context-precision context))))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "power" base exponent precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Perform calculation
              (let ((result (pow base exponent)))
                ;; Store in cache
                (map-set precision-caches { operation-id: operation-id } {
                  input-a: base,
                  input-b: exponent,
                  result: result,
                  precision: precision,
                  operation: "power",
                  timestamp: block-height
                })
                
                ;; Update user history
                (update-calculation-history tx-sender "power" result precision)
                
                ;; Emit event
                (emit-event (precision-calculated "power" result precision))
                
                (ok result)
              )
            )
        )
      )
    )
  )
)

(define-public (round-with-precision (value uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision config
    (let ((config (get-precision-config context)))
      (if (is-some config)
          (let ((precision (get-optional config).precision)
                (rounding-mode (get-optional config).rounding-mode)))
            
            ;; Perform rounding based on mode
            (let ((rounded-result (apply-rounding-mode value rounding-mode precision)))
              ;; Update user history
              (update-calculation-history tx-sender "round" rounded-result precision)
              
              (ok rounded-result)
            )
          )
          ;; Use default precision
          (let ((default-precision (var-get default-precision)))
            (let ((rounded-result (round-to-nearest value default-precision)))
              ;; Update user history
              (update-calculation-history tx-sender "round" rounded-result default-precision)
              
              (ok rounded-result)
            )
          )
      )
    )
  )
)

(define-public (calculate-percentage (part uint) (total uint) (context (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> total u0) ERR_DIVISION_BY_ZERO)
    (asserts! (var-get calculator-active) ERR_INVALID_INPUT)
    
    ;; Get precision for context
    (let ((precision (unwrap-optional (get-context-precision context))))
      
      ;; Check cache first
      (let ((operation-id (calculate-operation-id "percentage" part total precision)))
        (match (get-cached-result operation-id)
          cache
            (begin
              ;; Emit cache hit event
              (emit-event (cache-hit operation-id (get cache result)))
              
              (ok (get cache result))
            )
          none
            (begin
              ;; Calculate percentage with precision
              (let ((result (/ (* part u10000 precision) total)))
                ;; Store in cache
                (map-set precision-caches { operation-id: operation-id } {
                  input-a: part,
                  input-b: total,
                  result: result,
                  precision: precision,
                  operation: "percentage",
                  timestamp: block-height
                })
                
                ;; Update user history
                (update-calculation-history tx-sender "percentage" result precision)
                
                ;; Emit event
                (emit-event (precision-calculated "percentage" result precision))
                
                (ok result)
              )
            )
        )
      )
    )
  )
)

(define-public (clear-cache)
  (begin
    ;; Only admin can clear cache
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_INPUT)
    
    ;; Clear all cache entries
    ;; This would iterate through all cache entries
    ;; Simplified implementation
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { precision: u1000000, rounding-mode: (string-ascii 8), max-decimals: u6, active: bool } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (calculate-operation-id (operation (string-ascii 16)) (a uint) (b uint) (precision uint))
  (begin
    ;; Generate unique operation ID
    (hash160 (concat (concat (concat (string-ascii operation) (int-to-buff a)) (int-to-buff b)) (int-to-buff precision)))
  )
)

(define-private (update-calculation-history (user principal) (operation (string-ascii 16)) (result uint) (precision uint))
  (begin
    ;; Get current history
    (let ((history (get-calculation-history user)))
      (if (is-some history)
          (begin
            (let ((current-history (unwrap-optional history)))
              ;; Add new operation to history
              (let ((new-operations (list { operation: operation, result: result, precision: precision, timestamp: block-height })))
                (map-set calculation-history { user: user } {
                  operations: (append (get current-history operations) new-operations),
                  total-calculations: (+ (get current-history total-calculations) u1),
                  last-calculation: block-height
                })
              )
            )
          )
          ;; Create new history
          (map-set calculation-history { user: user } {
            operations: (list { operation: operation, result: result, precision: precision, timestamp: block-height }),
            total-calculations: u1,
            last-calculation: block_height
          })
      )
    )
  )
)

(define-private (is-valid-rounding-mode (mode (string-ascii 8)))
  (or 
    (is-eq mode "nearest")
    (is-eq mode "down")
    (is-eq mode "up")
    (is-eq mode "truncate")
  )
)

(define-private (apply-rounding-mode (value uint) (mode (string-ascii 8)) (precision uint))
  (begin
    (match mode
      "nearest" (round-to-nearest value precision)
      "down" (round-down value precision)
      "up" (round-up value precision)
      "truncate" (truncate value precision)
      (round-to-nearest value precision) ;; Default
    )
  )
)

(define-private (round-to-nearest (value uint) (precision uint))
  (begin
    (let ((half-precision (/ precision u2)))
      (if (>= (mod value precision) half-precision)
          (+ value (- precision (mod value precision)))
          (- value (mod value precision))
      )
    )
  )
)

(define-private (round-down (value uint) (precision uint))
  (- value (mod value precision))
)

(define-private (round-up (value uint) (precision uint))
  (if (is-eq (mod value precision) u0)
      value
      (+ value (- precision (mod value precision)))
  )
)

(define-private (truncate (value uint) (precision uint))
  (- value (mod value precision))
)

;; Admin functions

(define-public (set-calculator-active (active bool))
  (begin
    ;; Only admin can set calculator status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_INPUT)
    
    (var-set calculator-active active)
    (ok true)
  )
)

;; Utility functions

(define-read-only (get-calculator-status)
  {
    active: (var-get calculator-active),
    default-precision: (var-get default-precision),
    cache-size: u0, // Would count actual cache entries
    total-calculations: u0 // Would sum all user calculations
  }
)

(define-read-only (validate-precision (precision uint))
  (and (> precision u0) (<= precision MAX_PRECISION))
)
