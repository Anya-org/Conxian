;; revenue-distributor.clar
;; Distributes collected protocol revenue based on Allocation Policy
;; Implements the Whitepaper 60/20/20 Split

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))

;; Data Vars for Distribution Destinations
(define-data-var staking-vault principal .cxd-staking)
(define-data-var dev-treasury principal .operational-treasury)
(define-data-var insurance-vault principal .operational-treasury) ;; Placeholder

(define-public (distribute (token .sip-standards.sip-010-ft-trait) (amount uint))
    (let (
        (policy (unwrap-panic (contract-call? .allocation-policy get-allocation-percentages)))
        (staking-amt (/ (* amount (get staking policy)) u10000))
        (dev-amt (/ (* amount (get dev policy)) u10000))
        (ins-amt (/ (* amount (get insurance policy)) u10000))
    )
        ;; Execute actual transfers
        (try! (as-contract (contract-call? token transfer staking-amt tx-sender (var-get staking-vault) none)))
        (try! (as-contract (contract-call? token transfer dev-amt tx-sender (var-get dev-treasury) none)))
        (try! (as-contract (contract-call? token transfer ins-amt tx-sender (var-get insurance-vault) none)))
        
        (print { 
            event: "revenue-distributed", 
            amount: amount, 
            token: (contract-of token),
            staking: staking-amt,
            dev: dev-amt,
            insurance: ins-amt
        })
        (ok true)
    )
)

;; Admin Functions
(define-public (set-staking-vault (vault principal))
    (ok (var-set staking-vault vault))
)

(define-public (set-dev-treasury (treasury principal))
    (ok (var-set dev-treasury treasury))
)

(define-public (set-insurance-vault (vault principal))
    (ok (var-set insurance-vault vault))
)
