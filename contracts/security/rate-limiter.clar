;; rate-limiter.clar
;; Conxian Security: Rate limiting for sensitive operations
;; Prevents spam and protects against certain attack vectors
;;
;; REPAIRED: Full implementation of rate limiting with window-based tracking

;; Constants
(define-constant ERR_RATE_LIMIT_EXCEEDED u7000)
(define-constant ERR_UNAUTHORIZED u7001)
(define-constant ERR_INVALID_WINDOW u7002)

;; Default rate limits (operations per window)
(define-constant DEFAULT_WINDOW_SIZE uint u600) ;; 10 minutes in blocks (assuming 1 block/sec)
(define-constant DEFAULT_MAX_OPERATIONS uint u10) ;; 10 operations per window

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var window-size uint u600) ;; Configurable window size

;; Rate tracking: user -> operation-type -> {count, last-operation}
(define-map rate-limits
    { user: principal, operation: (string-ascii 32) }
    {
        count: uint,
        window-start: uint
    }
)

;; Custom limits per operation type
(define-map operation-config
    (string-ascii 32)
    {
        max-operations: uint,
        enabled: bool
    }
)

;; Events
(define-private (emit-rate-limit-hit (user principal) (operation (string-ascii 32)))
    (print {
        event: "rate-limit-exceeded",
        user: user,
        operation: operation,
        timestamp: block-height
    })
)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; @desc Check if operation is allowed for user
(define-public (check-operation (user principal) (operation (string-ascii 32)))
    (let (
        (config (default-to { max-operations: DEFAULT_MAX_OPERATIONS, enabled: true } 
                         (map-get? operation-config operation)))
        (current-block block-height)
        (window-start (var-get window-size))
        (rate-data (map-get? rate-limits { user: user, operation: operation }))
      )
        ;; Check if operation type is enabled
        (asserts! (get enabled config) (ok true))
        
        (match rate-data
            existing-data
            ;; Check if we're in a new window
            (if (> current-block (+ (get window-start existing-data) window-start))
                ;; New window, reset count
                (begin
                    (map-set rate-limits { user: user, operation: operation } {
                        count: u1,
                        window-start: current-block
                    })
                    (ok true)
                )
                ;; Same window, check count
                (if (< (get count existing-data) (get max-operations config))
                    (begin
                        (map-set rate-limits { user: user, operation: operation } {
                            count: (+ (get count existing-data) u1),
                            window-start: (get window-start existing-data)
                        })
                        (ok true)
                    )
                    (begin
                        (emit-rate-limit-hit user operation)
                        (err ERR_RATE_LIMIT_EXCEEDED)
                    )
                )
            )
            ;; First operation for this user/operation
            (begin
                (map-set rate-limits { user: user, operation: operation } {
                    count: u1,
                    window-start: current-block
                })
                (ok true)
            )
        )
    )
)

;; Admin Functions
(define-public (set-window-size (new-size uint))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set window-size new-size)
        (ok true)
    )
)

(define-public (set-operation-config 
    (operation (string-ascii 32)) 
    (max-ops uint) 
    (enabled bool)
  )
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (map-set operation-config operation {
            max-operations: max-ops,
            enabled: enabled
        })
        (ok true)
    )
)

(define-public (reset-user-limit (user principal) (operation (string-ascii 32)))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (map-delete rate-limits { user: user, operation: operation })
        (ok true)
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; Read-only
(define-read-only (get-user-rate-info (user principal) (operation (string-ascii 32)))
    (map-get? rate-limits { user: user, operation: operation })
)

(define-read-only (get-operation-config (operation (string-ascii 32)))
    (map-get? operation-config operation)
)

(define-read-only (get-window-size)
    (ok (var-get window-size))
)
