;; Conxian Protocol: Referral Aggregator
;; Distributes sovereign yield using a 95% Worker / 5% Referrer split.
;; Copyright (c) 2026 Conxian-Labs.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_TRANSFER_FAILED (err u402))
(define-constant ERR_NOT_FOUND (err u404))

;; Roles & Config
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var worker-share-bps uint u9500) ;; 95%
(define-data-var referrer-share-bps uint u500) ;; 5%

;; Mapping of Referrals: Worker -> Referrer
(define-map worker-referrals principal principal)

;; @desc Register a referrer for a specific worker
(define-public (register-referral (worker principal) (referrer principal))
    (begin
        (asserts! (or (is-eq tx-sender worker) (is-eq tx-sender (var-get admin))) ERR_UNAUTHORIZED)
        (map-set worker-referrals worker referrer)
        (print { event: "referral-registered" worker: worker referrer: referrer })
        (ok true)
    )
)

;; @desc Disburse STX payment splitting between worker and their referrer
(define-public (disburse-stx-payment (worker principal) (amount uint))
    (let (
        (referrer (map-get? worker-referrals worker))
        (referrer-fee (if (is-some referrer) (/ (* amount (var-get referrer-share-bps)) u10000) u0))
        (worker-net (- amount referrer-fee))
    )
        (begin
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            ;; Pay Worker
            (unwrap! (stx-transfer? worker-net tx-sender worker) ERR_TRANSFER_FAILED)
            
            ;; Pay Referrer if exists
            (if (is-some referrer)
                (unwrap! (stx-transfer? referrer-fee tx-sender (unwrap! referrer ERR_NOT_FOUND)) ERR_TRANSFER_FAILED)
                true
            )
            
            (print { event: "payment-disbursed-stx" worker: worker amount: worker-net referrer: referrer referrer-fee: referrer-fee })
            (ok true)
        )
    )
)

;; @desc Disburse SIP-010 token payment splitting between worker and their referrer
(define-public (disburse-sip010-payment (worker principal) (amount uint) (token <sip-010-ft-trait>))
    (let (
        (referrer (map-get? worker-referrals worker))
        (referrer-fee (if (is-some referrer) (/ (* amount (var-get referrer-share-bps)) u10000) u0))
        (worker-net (- amount referrer-fee))
    )
        (begin
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            ;; Pay Worker
            (unwrap! (contract-call? token transfer worker-net tx-sender worker none) ERR_TRANSFER_FAILED)
            
            ;; Pay Referrer if exists
            (if (is-some referrer)
                (unwrap! (contract-call? token transfer referrer-fee tx-sender (unwrap! referrer ERR_NOT_FOUND) none) ERR_TRANSFER_FAILED)
                true
            )
            
            (print { event: "payment-disbursed-sip010" worker: worker amount: worker-net referrer: referrer referrer-fee: referrer-fee })
            (ok true)
        )
    )
)

;; @desc Admin function to update the split ratio
(define-public (set-split-ratio (worker-bps uint) (referrer-bps uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (+ worker-bps referrer-bps) u10000) ERR_INVALID_AMOUNT)
        (var-set worker-share-bps worker-bps)
        (var-set referrer-share-bps referrer-bps)
        (ok true)
    )
)