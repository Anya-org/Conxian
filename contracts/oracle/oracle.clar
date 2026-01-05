;; oracle.clar
;; Conxian Enterprise Standard: Oracle Implementation
;; Provides price feeds for DeFi operations with security and reliability

(use-trait oracle-trait .oracle.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_PAIR (err u8001))
(define-constant ERR_STALE_PRICE (err u8002))
(define-constant ERR_INVALID_PRICE (err u8003))
(define-constant PRICE_STALE_BLOCKS u100) ;; Price considered stale after 100 blocks (~8.3 minutes)

;; Data Vars
(define-data-var oracle-admin principal tx-sender)
(define-data-var is-active bool true)

;; Price storage: base-asset => quote-asset => price data
(define-map price-feeds 
  { base: (string-ascii 32), quote: (string-ascii 32) }
  { price: uint, confidence: uint, timestamp: uint, source: principal }
)

;; Authorized price sources
(define-map authorized-sources principal bool)

;; Implementation
(impl-trait .oracle.oracle-trait)

;; Public functions
(define-public (get-price 
  (base (string-ascii 32)) 
  (quote (string-ascii 32))
) 
  (begin
    (asserts! (is-active) (err u9999))
    
    (match (map-get? price-fees { base: base, quote: quote })
      price-data 
      (begin
        (asserts! 
          (<= (- block-height (get timestamp price-data)) PRICE_STALE_BLOCKS)
          ERR_STALE_PRICE
        )
        (ok (get price price-data))
      )
      (err u9999)
    )
  )
)

(define-public (get-price-with-confidence 
  (base (string-ascii 32)) 
  (quote (string-ascii 32))
) 
  (begin
    (asserts! (is-active) (err u9999))
    
    (match (map-get? price-fees { base: base, quote: quote })
      price-data 
      (begin
        (asserts! 
          (<= (- block-height (get timestamp price-data)) PRICE_STALE_BLOCKS)
          ERR_STALE_PRICE
        )
        (ok {
          price: (get price price-data),
          confidence: (get confidence price-data),
          timestamp: (get timestamp price-data)
        })
      )
      (err u9999)
    )
  )
)

(define-public (update-price 
  (base (string-ascii 32)) 
  (quote (string-ascii 32)) 
  (price uint) 
  (confidence uint)
) 
  (begin
    ;; Check authorization
    (asserts! 
      (or 
        (is-eq tx-sender (var-get oracle-admin))
        (default-to false (map-get? authorized-sources tx-sender))
      )
      ERR_UNAUTHORIZED
    )
    
    ;; Validate price
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (<= confidence u10000) ERR_INVALID_PRICE) ;; Confidence as basis points
    
    ;; Store price data
    (map-set price-fees 
      { base: base, quote: quote }
      { 
        price: price, 
        confidence: confidence, 
        timestamp: block-height, 
        source: tx-sender 
      }
    )
    
    (ok true)
  )
)

(define-read-only (is-valid) 
  (ok (and (var-get is-active) (> block-height u0)))
)

(define-read-only (get-last-update 
  (base (string-ascii 32)) 
  (quote (string-ascii 32))
) 
  (match (map-get? price-fees { base: base, quote: quote })
    price-data 
    (ok (get timestamp price-data))
    (err u9999)
  )
)

;; Admin functions
(define-public (set-oracle-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set oracle-admin new-admin)
    (ok true)
  )
)

(define-public (toggle-oracle-status)
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (var-set is-active (not (var-get is-active)))
    (ok true)
  )
)

(define-public (authorize-source (source principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERR_UNAUTHORIZED)
    (map-set authorized-sources source authorized)
    (ok true)
  )
)

