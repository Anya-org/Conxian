;; Error Utilities Library
;; Utility functions for error handling and validation

;; Import error codes
(use-trait .error-codes-trait)

;; Validation functions
(define-public (validate-amount (amount uint) (min-amount uint) (max-amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= amount min-amount) ERR_INVALID_AMOUNT)
    (asserts! (<= amount max-amount) ERR_INVALID_AMOUNT)
    (ok true)
  )
)

(define-public (validate-address (address principal))
  (begin
    (asserts! (is-principal address) ERR_INVALID_ADDRESS)
    (ok true)
  )
)

(define-public (validate-timestamp (timestamp uint) (max-age uint))
  (begin
    (asserts! (> timestamp u0) ERR_INVALID_TIMESTAMP)
    (asserts! (>= (- block-height timestamp) max-age) ERR_INVALID_TIMESTAMP)
    (ok true)
  )
)

(define-public (validate-balance (account principal) (required-amount uint))
  (begin
    (asserts! (>= (stx-get-balance account) required-amount) ERR_INSUFFICIENT_BALANCE)
    (ok true)
  )
)

(define-public (validate-token-balance (token-contract principal) (account principal) (required-amount uint))
  (begin
    (asserts! (>= (contract-call? token-contract get-balance account) required-amount) ERR_INSUFFICIENT_TOKENS)
    (ok true)
  )
)

;; Error formatting functions
(define-read-only (format-error (error-code uint) (context (string-ascii 256)))
  (let ((message (contract-call? .error-codes get-error-message error-code))
        (category (contract-call? .error-codes get-error-category error-code))
        (severity (contract-call? .error-codes get-error-severity error-code)))
    (concat (concat (concat (concat (concat (concat category ": ") message) " (") context) ") [") severity) "]")
  )
)

(define-read-only (format-amount-error (amount uint) (min-amount uint) (max-amount uint))
  (format-error ERR_INVALID_AMOUNT (concat (concat (concat "Amount: " (to-uint amount)) ", min: ") (to-uint min-amount)))
)

(define-read-only (format-balance-error (required uint) (available uint))
  (format-error ERR_INSUFFICIENT_BALANCE (concat (concat "Required: " (to-uint required)) ", available: "))
)

;; Error recovery functions
(define-public (handle-retry (operation (response 10 uint)) (max-retries uint))
  (begin
    (asserts! (> max-retries u0) ERR_OPERATION_FAILED)
    
    ;; Simplified retry logic - in practice would need more sophisticated implementation
    (match operation
      success success
      error
        (if (> max-retries u1)
            (handle-retry operation (- max-retries u1))
            error
        )
    )
  )
)

(define-public (handle-circuit-breaker (operation (response 10 uint)) (failure-threshold uint))
  (begin
    ;; Check if circuit breaker should be triggered
    (match operation
      success (ok success)
      error
        (begin
          (asserts! (< failure-threshold u1) ERR_CIRCUIT_BREAKER_TRIGGERED)
          error
        )
    )
  )
)

;; Logging functions
(define-read-only (log-error (error-code uint) (context (string-ascii 256)) (additional-info (optional (string-ascii 256))))
  (let ((formatted-error (format-error error-code context))
        (timestamp block-height))
    (print {
      event: "error_logged",
      error-code: error-code,
      message: formatted-error,
      timestamp: timestamp,
      context: context,
      additional-info: additional-info
    })
    formatted-error
  )
)

(define-read-only (log-operation-failure (operation (string-ascii 64)) (error (response 10 uint)))
  (match error
    err-code (log-error err-code operation none)
    success "Operation succeeded"
  )
)

;; Validation helpers
(define-public (validate-not-zero (value uint) (field-name (string-ascii 32)))
  (begin
    (asserts! (> value u0) (format-error ERR_INVALID_AMOUNT (concat field-name " cannot be zero")))
    (ok true)
  )
)

(define-public (validate-positive (value uint) (field-name (string-ascii 32)))
  (begin
    (asserts! (> value u0) (format-error ERR_INVALID_AMOUNT (concat field-name " must be positive")))
    (ok true)
  )
)

(define-public (validate-range (value uint) (min-val uint) (max-val uint) (field-name (string-ascii 32)))
  (begin
    (asserts! (>= value min-val) (format-error ERR_INVALID_AMOUNT (concat (concat field-name " below minimum: ") (to-uint min-val))))
    (asserts! (<= value max-val) (format-error ERR_INVALID_AMOUNT (concat (concat field-name " above maximum: ") (to-uint max-val))))
    (ok true)
  )
)

(define-public (validate-percentage (value uint) (field-name (string-ascii 32)))
  (begin
    (asserts! (<= value u10000) (format-error ERR_INVALID_AMOUNT (concat field-name " must be <= 10000 (100%)")))
    (ok true)
  )
)

;; Batch validation
(define-public (validate-batch-amounts (amounts (list 20 uint)) (min-amount uint) (max-amount uint))
  (begin
    (fold amounts u0
      (lambda ((result uint) (amount uint))
        (match (validate-amount amount min-amount max-amount)
          success (+ result u1)
          error result
        )
      )
    )
    (ok true)
  )
)

(define-public (validate-batch-addresses (addresses (list 20 principal)))
  (begin
    (fold addresses u0
      (lambda ((result uint) (address principal))
        (match (validate-address address)
          success (+ result u1)
          error result
        )
      )
    )
    (ok true)
  )
)

;; Error aggregation
(define-read-only (aggregate-errors (errors (list 20 uint)))
  (let ((error-count (len errors)))
    (if (> error-count u0)
        (ok {
          total-errors: error-count,
          most-common: (get-most-common-error errors),
          severity-distribution: (get-severity-distribution errors)
        })
        (ok { total-errors: u0, most-common: u0, severity-distribution: {} })
    )
  )
)

;; Helper functions
(define-private (get-most-common-error (errors (list 20 uint)))
  (begin
    ;; Simplified - would need proper counting implementation
    (get errors u0)
  )
)

(define-private (get-severity-distribution (errors (list 20 uint)))
  (begin
    ;; Simplified - would need proper counting implementation
    { critical: u0, high: u0, medium: u0, low: u0 }
  )
)

;; Safety checks
(define-public (safe-divide (numerator uint) (denominator uint))
  (begin
    (asserts! (> denominator u0) ERR_INVALID_AMOUNT)
    (ok (/ numerator denominator))
  )
)

(define-public (safe-subtract (a uint) (b uint))
  (begin
    (asserts! (>= a b) ERR_INVALID_AMOUNT)
    (ok (- a b))
  )
)

(define-public (safe-add (a uint) (b uint) (max-value uint))
  (begin
    (asserts! (<= (+ a b) max-value) ERR_INVALID_AMOUNT)
    (ok (+ a b))
  )
)

;; Rate limiting
(define-map rate-limits { identifier: principal } { last-action: uint, action-count: uint })
(define-data-var rate-limit-window uint u100) ;; 100 blocks
(define-data-var max-actions-per-window uint u10)

(define-public (check-rate-limit (identifier principal))
  (begin
    (match (map-get? rate-limits { identifier: identifier })
      limit
        (begin
          (let ((current-block block-height)
                (last-action (get limit last-action))
                (action-count (get limit action-count)))
            
            (if (>= (- current-block last-action) (var-get rate-limit-window))
                ;; Reset window
                (begin
                  (map-set rate-limits { identifier: identifier } {
                    last-action: current-block,
                    action-count: u1
                  })
                  (ok true)
                )
                ;; Check if within limit
                (begin
                  (asserts! (< action-count (var-get max-actions-per-window)) ERR_RATE_LIMIT_EXCEEDED)
                  (map-set rate-limits { identifier: identifier } {
                    last-action: current-block,
                    action-count: (+ action-count u1)
                  })
                  (ok true)
                )
            )
          )
        )
        ;; First action
        (begin
          (map-set rate-limits { identifier: identifier } {
            last-action: block-height,
            action-count: u1
          })
          (ok true)
        )
    )
  )
)
