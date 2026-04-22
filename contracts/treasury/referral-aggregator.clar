;; Conxian Protocol: Referral Aggregator
;; Distributes sovereign yield using a 95% Worker / 5% Referrer split.
;; Copyright (c) 2026 Conxian-Labs.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_TRANSFER_FAILED (err u402))
(define-constant ERR_NOT_FOUND (err u404))

;; Roles & Config
(define-data-var admin principal tx-sender)
(define-data-var worker-share-bps uint u8500) ;; 85%
(define-data-var referrer-share-bps uint u500) ;; 5%
(define-data-var referee-bonus-bps uint u500) ;; 5%
(define-data-var health-lock-bps uint u500) ;; 5%
(define-data-var health-lock-address principal tx-sender) ;; Placeholder for protocol health lock

;; Mapping of Referrals: Worker -> Referrer
(define-map worker-referrals principal principal)

;; @desc Register a referrer for a specific worker (referee)
(define-public (register-referral (worker principal) (referrer principal))
    (begin
        (asserts! (or (is-eq tx-sender worker) (is-eq tx-sender (var-get admin))) ERR_UNAUTHORIZED)
        (map-set worker-referrals worker referrer)
        (print { event: "referral-registered", worker: worker, referrer: referrer })
        (ok true)
    )
)

;; @desc Disburse STX payment using 5-5-5 split (5% Referrer, 5% Referee, 5% Health Lock)
(define-public (disburse-stx-payment (worker principal) (amount uint))
    (let (
        (referrer (map-get? worker-referrals worker))
        (has-referrer (is-some referrer))
        (referrer-fee (if has-referrer (/ (* amount (var-get referrer-share-bps)) u10000) u0))
        (referee-bonus (if has-referrer (/ (* amount (var-get referee-bonus-bps)) u10000) u0))
        (health-lock-fee (if has-referrer (/ (* amount (var-get health-lock-bps)) u10000) u0))
        (worker-net (if has-referrer 
                        (- amount (+ referrer-fee health-lock-fee)) ;; Worker gets the remainder (85% + 5% bonus = 90%, but we just subtract the fees that go elsewhere)
                        amount))
    )
        (begin
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            
            ;; Pay Worker (Referee) - They get their base share + referee bonus if referred
            (unwrap! (stx-transfer? worker-net tx-sender worker) ERR_TRANSFER_FAILED)
            
            ;; Pay Referrer and Health Lock if referred
            (if has-referrer
                (begin
                    (unwrap! (stx-transfer? referrer-fee tx-sender (unwrap! referrer ERR_NOT_FOUND)) ERR_TRANSFER_FAILED)
                    (unwrap! (stx-transfer? health-lock-fee tx-sender (var-get health-lock-address)) ERR_TRANSFER_FAILED)
                    true
                )
                true
            )
            
            (print { event: "payment-disbursed-stx-555", worker: worker, amount: worker-net, referrer: referrer, referrer-fee: referrer-fee, health-lock-fee: health-lock-fee })
            (ok true)
        )
    )
)

;; @desc Disburse SIP-010 token payment using 5-5-5 split
(define-public (disburse-sip010-payment (worker principal) (amount uint) (token <sip-010-ft-trait>))
    (let (
        (referrer (map-get? worker-referrals worker))
        (has-referrer (is-some referrer))
        (referrer-fee (if has-referrer (/ (* amount (var-get referrer-share-bps)) u10000) u0))
        (referee-bonus (if has-referrer (/ (* amount (var-get referee-bonus-bps)) u10000) u0))
        (health-lock-fee (if has-referrer (/ (* amount (var-get health-lock-bps)) u10000) u0))
        (worker-net (if has-referrer 
                        (- amount (+ referrer-fee health-lock-fee))
                        amount))
    )
        (begin
            (asserts! (> amount u0) ERR_INVALID_AMOUNT)
            
            ;; Pay Worker
            (unwrap! (contract-call? token transfer worker-net tx-sender worker none) ERR_TRANSFER_FAILED)
            
            ;; Pay Referrer and Health Lock
            (if has-referrer
                (begin
                    (unwrap! (contract-call? token transfer referrer-fee tx-sender (unwrap! referrer ERR_NOT_FOUND) none) ERR_TRANSFER_FAILED)
                    (unwrap! (contract-call? token transfer health-lock-fee tx-sender (var-get health-lock-address) none) ERR_TRANSFER_FAILED)
                    true
                )
                true
            )
            
            (print { event: "payment-disbursed-sip010-555", worker: worker, amount: worker-net, referrer: referrer, referrer-fee: referrer-fee, health-lock-fee: health-lock-fee })
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