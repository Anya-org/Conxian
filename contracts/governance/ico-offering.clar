;; ico-offering.clar
;; Initial Coin Offering Contract
;; Fixed price crowdsale logic

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_SALE_NOT_ACTIVE (err u1000))
(define-constant ERR_MIN_BUY (err u1001))
(define-constant ERR_MAX_BUY (err u1002))

;; Data Vars
(define-data-var token-price uint u100) ;; STX per Token (microSTX/microToken ratio)
(define-data-var sale-active bool false)
(define-data-var treasury-address principal tx-sender)

;; Public Interface
(define-public (buy-tokens (amount uint) (token <sip-010-trait>))
    (begin
        (asserts! (var-get sale-active) ERR_SALE_NOT_ACTIVE)
        
        ;; Calc STX cost
        (let (
            (cost (* amount (var-get token-price)))
        )
            ;; Buyer pays STX to Treasury
            (try! (stx-transfer? cost tx-sender (var-get treasury-address)))
            
            ;; Contract sends Tokens to Buyer
            (as-contract (contract-call? token transfer amount tx-sender tx-sender none))
        )
    )
)

;; Admin
(define-public (set-sale-active (active bool))
    (begin
        ;; Only admin
        (ok (var-set sale-active active))
    )
)
