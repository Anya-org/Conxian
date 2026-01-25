;; pyth-oracle-adapter.clar
;; Conxian Oracle Standard: Pyth Network Adapter (Efficiency Layer)
;; Pull-model implementation for low-latency DEX feeds

;; Traits
(use-trait oracle-trait .defi-traits.oracle-trait)
(use-trait pyth-core-trait .pyth-traits.pyth-core-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_STALE_PRICE (err u7001))
(define-constant PYTH_PRECISION u100000000) ;; 10^8

;; Data Vars
(define-data-var pyth-contract principal .pyth-oracle-v2-mock)
(define-data-var block-utils-contract principal .block-utils)
(define-data-var conxian-protocol-contract principal .conxian-protocol)

;; @desc Updates the price feed with a VAA (Pull Model)
(define-public (update-price-feed
    (vaa (buff 2048))
    (pyth <pyth-core-trait>)
  )
  (begin
    (asserts! (is-eq (contract-of pyth) (var-get pyth-contract)) ERR_UNAUTHORIZED)
    (contract-call? pyth verify-and-update-price-feeds vaa)
  )
)

;; @desc Fetches the price from Pyth (Normalized to 8 decimals)
(define-public (get-price (asset principal))
  (let (
      (tenure-id (contract-call? (var-get block-utils-contract) get-current-tenure-id))
      (price-data (unwrap! (contract-call? (var-get pyth-contract) get-price asset)
        (err u7002)
      ))
    )
    (begin
      (print {
        event: "pyth-price-update",
        asset: asset,
        price: price-data,
        tenure-id: tenure-id,
      })
      (ok price-data)
    )
  )
)

;; @desc Admin function to switch the Pyth provider
(define-public (set-pyth-provider (new-provider principal))
  (begin
    (asserts!
      (is-eq tx-sender
        (unwrap-panic (contract-call? (var-get conxian-protocol-contract) get-admin))
      )
      ERR_UNAUTHORIZED
    )
    (var-set pyth-contract new-provider)
    (ok true)
  )
)

;; Read Only
(define-read-only (get-name)
  (ok "Pyth-Efficiency-Layer")
)
