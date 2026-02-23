;; ico-offering.clar
;; Conxian Protocol Standard Contract

;; ico-offering.clar
;; Initial Coin Offering Contract
;; Fixed price crowdsale logic with compliance gating and caps
;;
;; REPAIRED: Added compliance checks, purchase caps, admin authorization, and events

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_SALE_NOT_ACTIVE u1000)
(define-constant ERR_MIN_BUY u1001)
(define-constant ERR_MAX_BUY u1002)
(define-constant ERR_UNAUTHORIZED u1003)
(define-constant ERR_COMPLIANCE_FAILED u1004)
(define-constant ERR_SALE_CAP_REACHED u1005)
(define-constant ERR_INDIVIDUAL_CAP_REACHED u1006)
(define-constant ERR_INVALID_AMOUNT u1007)

;; Data Vars
(define-data-var token-price uint u100) ;; STX per Token (microSTX/microToken ratio)
(define-data-var sale-active bool false)
(define-data-var treasury-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var sale-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Compliance
(define-data-var regulatory-adapter principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var compliance-required bool true)

;; Sale Caps
(define-data-var sale-cap uint u1000000000000) ;; Max tokens for sale (1M with 6 decimals)
(define-data-var individual-cap uint u10000000000) ;; Max per buyer (10K with 6 decimals)
(define-data-var min-purchase uint u1000000) ;; Min purchase (1 token with 6 decimals)
(define-data-var tokens-sold uint u0)

;; Purchase tracking
(define-map buyer-contributions principal uint)

;; Events
(define-private (emit-purchase (buyer principal) (amount uint) (cost uint))
    (print {
        event: "ico-purchase",
        buyer: buyer,
        amount: amount,
        cost: cost,
        timestamp: burn-block-height
    })
)

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get sale-owner))
)

;; Compliance check
(define-private (check-compliance (user principal))
    (if (var-get compliance-required)
        (contract-call? .regulatory-adapter check-clean-hands-compliance user)
        true
    )
)

;; Public Interface

;; @desc Buy tokens
;; @returns (response bool uint)
(define-public (buy-tokens (amount uint) (token <sip-010-trait>))
    (let (
        (buyer tx-sender)
        (cost (* amount (var-get token-price)))
        (current-contribution (default-to u0 (map-get? buyer-contributions buyer)))
        (new-contribution (+ current-contribution amount))
    )
        ;; Checks
        (asserts! (var-get sale-active) (err ERR_SALE_NOT_ACTIVE))
        (asserts! (>= amount (var-get min-purchase)) (err ERR_MIN_BUY))
        (asserts! (<= new-contribution (var-get individual-cap)) (err ERR_INDIVIDUAL_CAP_REACHED))
        (asserts! (<= (+ (var-get tokens-sold) amount) (var-get sale-cap)) (err ERR_SALE_CAP_REACHED))
        (asserts! (check-compliance buyer) (err ERR_COMPLIANCE_FAILED))
        
        ;; Update state
        (map-set buyer-contributions buyer new-contribution)
        (var-set tokens-sold (+ (var-get tokens-sold) amount))
        
        ;; Transfer STX to Treasury
        (try! (stx-transfer? cost buyer (var-get treasury-address)))
        
        ;; Transfer Tokens to Buyer (from contract balance)
        (try! (as-contract (contract-call? token transfer amount tx-sender buyer none)))
        
        ;; Emit event
        (emit-purchase buyer amount cost)
        
        (ok true)
    )
)

;; Admin Functions

;; @desc Set sale active
;; @returns (response bool uint)
(define-public (set-sale-active (active bool))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set sale-active active)
        (print {
            event: "ico-sale-state-changed",
            active: active,
            timestamp: burn-block-height
        })
        (ok true)
    )
)


;; @desc Set token price
;; @returns (response bool uint)
(define-public (set-token-price (new-price uint))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (asserts! (> new-price u0) (err ERR_INVALID_AMOUNT))
        (var-set token-price new-price)
        (ok true)
    )
)


;; @desc Set treasury address
;; @returns (response bool uint)
(define-public (set-treasury-address (new-address principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set treasury-address new-address)
        (ok true)
    )
)


;; @desc Set sale caps
;; @returns (response bool uint)
(define-public (set-sale-caps (new-sale-cap uint) (new-individual-cap uint))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set sale-cap new-sale-cap)
        (var-set individual-cap new-individual-cap)
        (ok true)
    )
)


;; @desc Set compliance required
;; @returns (response bool uint)
(define-public (set-compliance-required (required bool))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set compliance-required required)
        (ok true)
    )
)


;; @desc Transfer ownership
;; @returns (response bool uint)
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-owner) (err ERR_UNAUTHORIZED))
        (var-set sale-owner new-owner)
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-sale-status)
    {
        active: (var-get sale-active),
        token-price: (var-get token-price),
        tokens-sold: (var-get tokens-sold),
        sale-cap: (var-get sale-cap),
        individual-cap: (var-get individual-cap),
        min-purchase: (var-get min-purchase),
        compliance-required: (var-get compliance-required)
    }
)

(define-read-only (get-buyer-contribution (buyer principal))
    (default-to u0 (map-get? buyer-contributions buyer))
)
