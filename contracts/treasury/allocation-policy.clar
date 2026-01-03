;; allocation-policy.clar
;; Defines protocol revenue allocation percentages
;; Basis points: 10000 = 100%

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_SHARE (err u1001))

(define-data-var staking-share uint u6000) ;; 60%
(define-data-var dev-fund-share uint u2000) ;; 20%
(define-data-var insurance-share uint u2000) ;; 20%

(define-data-var admin principal tx-sender)

(define-read-only (get-allocation-percentages)
    (ok {
        staking: (var-get staking-share),
        dev: (var-get dev-fund-share),
        insurance: (var-get insurance-share)
    })
)

(define-public (set-allocations (staking uint) (dev uint) (insurance uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (+ staking (+ dev insurance)) u10000) ERR_INVALID_SHARE)
        (var-set staking-share staking)
        (var-set dev-fund-share dev)
        (var-set insurance-share insurance)
        (ok true)
    )
)
