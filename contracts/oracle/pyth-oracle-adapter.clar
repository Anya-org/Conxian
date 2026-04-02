;; pyth-oracle-adapter.clar
;; Sovereign Oracle Adapter for Conxian Protocol
;; Aligned with Chappies Ethos: Reactive, Non-Custodial, Bitcoin-Native

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PYTH_FAILED (err u1001))
(define-constant ERR_FEED_NOT_SET (err u1002))
(define-constant ERR_PYTH_CORE_NOT_SET (err u1003))
(define-constant ERR_AGGREGATOR_NOT_SET (err u1004))
(define-constant ERR_AGGREGATOR_FAILED (err u1005))

(define-data-var admin principal tx-sender)
(define-map authorized-updaters principal bool)

;; Principal Injection
(define-data-var pyth-core-contract (optional principal) none)
(define-data-var oracle-aggregator-contract (optional principal) none)

;; --- Optimization: Cached Price Mapping ---
(define-map asset-to-pyth-feed principal principal)

;; --- Public Functions ---

;; @desc Update price and push to aggregator (The Sovereign "Pull" Pattern)
(define-public (update-and-submit-price (asset principal) (vaa-data (buff 2048)))
  (let (
    (is-authorized
      (or
        (is-eq tx-sender (var-get admin))
        (is-eq contract-caller (var-get admin))
        (default-to false (map-get? authorized-updaters tx-sender))
        (default-to false (map-get? authorized-updaters contract-caller))
      )
    )
    (pyth-core (unwrap! (var-get pyth-core-contract) ERR_PYTH_CORE_NOT_SET))
    (oracle-aggregator (unwrap! (var-get oracle-aggregator-contract) ERR_AGGREGATOR_NOT_SET))
    (pyth-feed (unwrap! (map-get? asset-to-pyth-feed asset) ERR_FEED_NOT_SET))
  )
    (begin
      (asserts! is-authorized ERR_UNAUTHORIZED)
      ;; 1. Update Pyth Storage with fresh VAA
      (unwrap! (contract-call? pyth-core verify-and-update-price-feeds vaa-data) ERR_PYTH_FAILED)
      
      ;; 2. Read the newly verified price
      (let (
        (price (unwrap! (contract-call? pyth-core get-price pyth-feed) ERR_PYTH_FAILED))
      )
        ;; 3. Submit to the Conxian Aggregator
        (unwrap! (contract-call? oracle-aggregator submit-price asset price) ERR_AGGREGATOR_FAILED)
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

(define-public (set-updater (updater principal) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-updaters updater enabled)
    (ok true)
  )
)

(define-read-only (get-pyth-core-contract)
  (var-get pyth-core-contract)
)

(define-read-only (get-oracle-aggregator-contract)
  (var-get oracle-aggregator-contract)
)

(define-public (set-pyth-core-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set pyth-core-contract (some contract))
    (ok true)
  )
)

(define-public (set-oracle-aggregator-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set oracle-aggregator-contract (some contract))
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
