;; yield-optimizer.clar
;; Analyzes strategies and rebalances funds for optimal APY
;; Enhanced with Strategy Selection and Risk Scoring

(use-trait vault-trait .vault-trait.vault-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_STRATEGY_NOT_FOUND (err u6001))
(define-constant ERR_RISK_TOO_HIGH (err u6002))

(define-data-var contract-owner principal tx-sender)

;; Strategy storage
(define-map strategies
    principal ;; vault address
    {
        active: bool,
        risk-score: uint, ;; 1-100, lower is safer
        estimated-apy: uint ;; basis points
    }
)

(define-data-var max-risk-tolerance uint u50)

;; @desc Registers or updates a strategy
(define-public (update-strategy (vault principal) (risk-score uint) (apy uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set strategies vault {
            active: true,
            risk-score: risk-score,
            estimated-apy: apy
        })
        (ok true)
    )
)

;; @desc Rebalances funds from one vault to another
(define-public (rebalance (vault-from <vault-trait>) (vault-to <vault-trait>) (amount uint))
    (let
        (
            (strategy-to (unwrap! (map-get? strategies (contract-of vault-to)) ERR_STRATEGY_NOT_FOUND))
        )
        ;; Check risk tolerance
        (asserts! (<= (get risk-score strategy-to) (var-get max-risk-tolerance)) ERR_RISK_TOO_HIGH)
        
        ;; Logic to withdraw from A and deposit to B
        (try! (contract-call? vault-from withdraw amount tx-sender))
        (try! (contract-call? vault-to deposit amount tx-sender))
        (ok true)
    )
)

;; @desc Auto-selects the best strategy from a given list
;; Returns the principal of the best strategy
(define-read-only (get-best-strategy (candidates (list 10 principal)))
    (fold best-strategy-reducer candidates (ok tx-sender)) ;; returns (ok best-principal) or error
)

(define-private (best-strategy-reducer (candidate principal) (current-best (response principal uint)))
    (match current-best
        best-principal 
        (let
            (
                (strat-cand (map-get? strategies candidate))
                (strat-best (map-get? strategies best-principal))
            )
            (match strat-cand
                c (match strat-best
                    b (if (and (get active c) (> (get estimated-apy c) (get estimated-apy b)) (<= (get risk-score c) (var-get max-risk-tolerance)))
                        (ok candidate)
                        (ok best-principal)
                    )
                    (if (and (get active c) (<= (get risk-score c) (var-get max-risk-tolerance))) (ok candidate) (ok best-principal)) ;; If current best is invalid/dummy, take candidate
                )
                (ok best-principal) ;; Candidate not found
            )
        )
        err-val current-best
    )
)
