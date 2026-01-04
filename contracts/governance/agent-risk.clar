;; agent-risk.clar
;; The Autonomous CRO (Chief Risk Officer)
;; Implements autonomous, on-chain risk management, including automated
;; circuit breakers and solvency monitoring.

;; ---
;; @SECTION
;; TRAITS & DEPENDENCIES
;; ---

(use-trait roles-trait .core-traits.rbac-trait)
(use-trait oracle-trait .oracle-pricing.oracle-trait)

;; ---
;; @SECTION
;; CONSTANTS & ERRORS
;; ---

(define-constant ROLE_ADMIN u1)
(define-constant ROLE_KEEPER u2)
(define-constant ROLE_CEO_AGENT u3) ;; Special role for the CEO Agent

(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_VOLATILITY_THRESHOLD_EXCEEDED (err u7001))
(define-constant ERR_INVALID_THRESHOLD (err u7002))

;; ---
;; @SECTION
;; STATE & CONFIGURATION
;; ---

(define-data-var contract-owner principal tx-sender)
(define-data-var rbac-contract principal .rbac)
(define-data-var oracle-contract principal .oracle)
(define-data-var volatility-threshold uint u1000) ;; 10% price deviation

;; Map of paused contracts
(define-map paused-contracts principal bool)
(define-map last-prices principal uint)

;; ---
;; @SECTION
;; CORE LOGIC
;; ---

;; @desc Checks if the sender has the required authorization.
;; @param role The required role (uint).
;; @returns bool
(define-private (is-authorized (role uint))
    (if (is-eq tx-sender (var-get contract-owner))
        true
        (contract-call? .rbac has-role tx-sender role)
    )
)

;; @desc Pauses or unpauses a target contract. Can only be called by an authorized address.
;; @param target The principal of the contract to pause/unpause.
;; @param paused A boolean indicating the new paused state.
(define-public (set-contract-paused (target principal) (paused bool))
    (begin
        (asserts! (or (is-authorized ROLE_ADMIN) (is-authorized ROLE_CEO_AGENT)) ERR_UNAUTHORIZED)
        (map-set paused-contracts target paused)
        (print { event: "set-contract-paused", target: target, paused: paused, triggered-by: tx-sender })
        (ok true)
    )
)

;; @desc The core autonomous function of the CRO. A keeper calls this function to check
;; the price volatility of a given asset. If the volatility exceeds the threshold,
;; it triggers a circuit breaker for a specified target contract.
;; @param token The token to check (as a principal).
;; @param target-contract The contract to pause if the threshold is exceeded.
(define-public (monitor-market-volatility (token principal) (target-contract principal))
    (begin
        (asserts! (is-authorized ROLE_KEEPER) ERR_UNAUTHORIZED)

        ;; In a real implementation, this would involve comparing two oracle prices over time.
        ;; Here, we simulate by fetching the price and comparing it to a mock baseline.
        (let
            (
                (price (try! (contract-call? .oracle get-price token)))
                (last-price (default-to price (map-get? last-prices token)))
                (deviation (if (> price last-price)
                    (- price last-price)
                    (- last-price price)
                ))
                (threshold-breached (> (/ (* deviation u10000) last-price) (var-get volatility-threshold)))
            )
            (if threshold-breached
                (begin
                    (map-set last-prices token price)
                    (try! (set-contract-paused target-contract true))
                    (err ERR_VOLATILITY_THRESHOLD_EXCEEDED)
                )
                (begin
                    (map-set last-prices token price)
                    (ok true)
                )
            )
        )
    )
)

;; ---
;; @SECTION
;; READ-ONLY FUNCTIONS
;; ---

;; @desc Checks if a specific contract is currently paused.
;; @param target The principal of the contract to check.
;; @returns (response bool bool)
(define-read-only (is-contract-paused (target principal))
    (ok (default-to false (map-get? paused-contracts target)))
)

;; ---
;; @SECTION
;; ADMIN & CONFIGURATION
;; ---

;; @desc Sets the volatility threshold for the monitor.
;; @param new-threshold The new threshold in basis points (100 = 1%).
(define-public (set-volatility-threshold (new-threshold uint))
    (begin
        (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
        (asserts! (< new-threshold u5000) ERR_INVALID_THRESHOLD) ;; Max 50%
        (var-set volatility-threshold new-threshold)
        (ok true)
    )
)

(define-public (set-oracle-contract (new-oracle principal))
    (begin
        (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
        (var-set oracle-contract new-oracle)
        (ok true)
    )
)
