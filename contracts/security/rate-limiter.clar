;; rate-limiter.clar
;; Conxian Security: Rate Limiting System
;; Prevents spam and protects against rapid-fire exploits

;; Constants
(define-constant ERR_UNAUTHORIZED u7000)
(define-constant ERR_RATE_LIMIT_EXCEEDED u7001)
(define-constant ERR_INVALID_PARAMS u7002)

(define-constant DEFAULT_WINDOW_SIZE u600) ;; 10 minutes in blocks (assuming 1 block/sec)
(define-constant DEFAULT_MAX_OPERATIONS u10) ;; 10 operations per window

;; Data variables
(define-data-var contract-owner principal tx-sender)

;; Maps
(define-map user-rate-limits
    principal
    {
        window-start: uint,
        operation-count: uint,
        custom-window-size: (optional uint),
        custom-max-operations: (optional uint)
    }
)

;; Private functions
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; @desc Validates if a user is within their allowed rate limit.
;; @param user: The principal to check.
;; @return (response bool uint) - Returns ok(true) if within limits, or err(ERR_RATE_LIMIT_EXCEEDED).
(define-public (check-rate-limit (user principal))
    (let
        (
            (current-block burn-block-height)
            (user-data (default-to
                {
                    window-start: current-block,
                    operation-count: u0,
                    custom-window-size: none,
                    custom-max-operations: none
                }
                (map-get? user-rate-limits user)
            ))
            (window-size (default-to DEFAULT_WINDOW_SIZE (get custom-window-size user-data)))
            (max-ops (default-to DEFAULT_MAX_OPERATIONS (get custom-max-operations user-data)))
        )
        (if (>= (- current-block (get window-start user-data)) window-size)
            ;; New window
            (begin
                (map-set user-rate-limits user (merge user-data {
                    window-start: current-block,
                    operation-count: u1
                }))
                (ok true)
            )
            ;; Same window
            (if (< (get operation-count user-data) max-ops)
                (begin
                    (map-set user-rate-limits user (merge user-data {
                        operation-count: (+ (get operation-count user-data) u1)
                    }))
                    (ok true)
                )
                (err ERR_RATE_LIMIT_EXCEEDED)
            )
        )
    )
)

;; @desc Configures a custom rate limit for a specific user. Owner only.
;; @param user: The principal to configure.
;; @param window-size: Optional custom window duration in blocks.
;; @param max-ops: Optional custom maximum operations per window.
;; @return (response bool uint) - Returns ok(true) on success, or an error.
(define-public (set-custom-limit (user principal) (window-size (optional uint)) (max-ops (optional uint)))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (let
            (
                (user-data (default-to
                    {
                        window-start: burn-block-height,
                        operation-count: u0,
                        custom-window-size: none,
                        custom-max-operations: none
                    }
                    (map-get? user-rate-limits user)
                ))
            )
            (map-set user-rate-limits user (merge user-data {
                custom-window-size: window-size,
                custom-max-operations: max-ops
            }))
            (ok true)
        )
    )
)

;; @desc Transfers contract ownership to a new principal. Owner only.
;; @param new-owner: The new owner principal.
;; @return (response bool uint) - Returns ok(true) on success, or an error.
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; @desc Retrieves the current rate limit data for a specific user.
;; @param user: The principal to query.
(define-read-only (get-user-data (user principal))
    (map-get? user-rate-limits user)
)
