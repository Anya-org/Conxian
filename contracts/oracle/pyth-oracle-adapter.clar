;; pyth-oracle-adapter.clar
;; Sovereign Oracle Adapter for Conxian Protocol
;; Aligned with Chappies Ethos: Reactive Non-Custodial Bitcoin-Native

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PYTH_FAILED (err u1001))

(define-data-var admin principal tx-sender)

;; --- Optimization: Cached Price Mapping ---
(define-map asset-to-pyth-feed principal principal)

;; --- Public Functions ---

;; @desc Update price and push to aggregator (The Sovereign "Pull" Pattern)
(define-public (update-and-submit-price (asset principal) (vaa-data (buff 2048)))
  (let (
    (pyth-feed (unwrap! (map-get? asset-to-pyth-feed asset) (err u404)))
  )
    (begin
      ;; 1. Update Pyth Storage with fresh VAA
      (unwrap-panic (contract-call? .pyth-oracle-v4 verify-and-update-price-feeds vaa-data))
      
      ;; 2. Read the newly verified price
      (let (
        (price (unwrap! (contract-call? .pyth-oracle-v4 get-price pyth-feed) ERR_PYTH_FAILED))
      )
        ;; 3. Submit to the Conxian Aggregator
        (contract-call? .oracle-aggregator submit-price asset price)
      )
    )
  )
)

;; --- Admin Functions ---

(define-public (set-feed-mapping (asset principal) (pyth-feed principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-to-pyth-feed asset pyth-feed)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
