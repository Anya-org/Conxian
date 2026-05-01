;; jurisdictional-sharding.clar
;; @desc Global Jurisdictional Sharding for Phase 7 - Multi-Currency Multi-Jurisdiction
;; @dev Implements shard computation for all currencies and jurisdictions (Guardian: Sovereignty)
;; @note Fully onchain global DeFi protocol with jurisdiction sharding for every jurisdiction and all currencies

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_BLOCK_TIME_UNAVAILABLE (err u402))
(define-constant ERR_UNSUPPORTED_COUNTRY (err u403))
(define-constant ERR_UNSUPPORTED_CURRENCY (err u404))
(define-constant ERR_INVALID_CURRENCY_CODE (err u405))
(define-constant ERR_INVALID_COUNTRY_CODE (err u406))
(define-constant ERR_CURRENCY_ALREADY_REGISTERED (err u407))
(define-constant ERR_JURISDICTION_ALREADY_REGISTERED (err u408))

(define-constant MAX_CURRENCY_CODE_LENGTH u3)  ;; ISO 4217 codes are 3 chars
(define-constant MAX_COUNTRY_CODE_LENGTH u2)   ;; ISO 3166-1 alpha-2 codes are 2 chars
(define-constant SHARD_PREFIX "SHARD_")

(define-data-var czar principal tx-sender)
(define-data-var admin principal tx-sender)

;; ============================================================================
;; CURRENCY REGISTRY
;; ============================================================================

(define-data-var next-currency-id uint u0)

(define-map currency-registry uint {
  code: (string-ascii 10), principal: (optional principal), is-fiat: bool, is-stablecoin: bool, decimal-places: uint, risk-tier: uint, is-active: bool
})

(define-map currency-code-to-id (string-ascii 10) uint)
(define-map token-to-currency-id principal uint)

;; ============================================================================
;; JURISDICTION REGISTRY
;; ============================================================================

(define-data-var next-jurisdiction-id uint u0)

(define-map jurisdiction-registry uint {
  country-code: (string-ascii 2), region-code: (string-ascii 3), name: (string-ascii 50), compliance-tier: uint, requires-kyc: bool, requires-travel-rule: bool, is-active: bool
})

(define-map country-to-jurisdiction-id (string-ascii 2) uint)

;; ============================================================================
;; SHARD COMPUTATION LOGIC
;; ============================================================================

(define-map settlement-shards (buff 32) (string-ascii 45))

(define-map kyc-registry principal {
  country: (string-ascii 2), region: (string-ascii 3), status: (string-ascii 10), risk-score: uint, last-verified: uint
})

;; ============================================================================
;; AUTHORIZATION & VALIDATION
;; ============================================================================

(define-private (is-owner)
  (is-eq tx-sender (var-get admin)))

(define-private (is-czar)
  (is-eq tx-sender (var-get czar)))

(define-private (validate-currency-code (code (string-ascii 10)))
  (<= (len code) MAX_CURRENCY_CODE_LENGTH))

(define-private (validate-country-code (code (string-ascii 2)))
  (is-eq (len code) MAX_COUNTRY_CODE_LENGTH))

;; ============================================================================
;; CURRENCY MANAGEMENT
;; ============================================================================

(define-public (register-currency 
    (code (string-ascii 10))
    (token-principal (optional principal))
    (is-fiat bool)
    (is-stablecoin bool)
    (decimal-places uint)
    (risk-tier uint))
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? currency-code-to-id code)) ERR_CURRENCY_ALREADY_REGISTERED)
    (asserts! (if is-fiat (is-none token-principal) (is-some token-principal)) ERR_INVALID_CURRENCY_CODE)
    (asserts! (<= risk-tier u2) ERR_INVALID_CURRENCY_CODE)
    (asserts! (<= decimal-places u18) ERR_INVALID_CURRENCY_CODE)
    (let ((currency-id (var-get next-currency-id)))
      (map-set currency-registry currency-id
        { code: code, principal: token-principal, is-fiat: is-fiat, is-stablecoin: is-stablecoin, decimal-places: decimal-places, risk-tier: risk-tier, is-active: true })
      (map-set currency-code-to-id code currency-id)
      (if (is-some token-principal)
        (map-set token-to-currency-id (unwrap-panic token-principal) currency-id)
        false)
      (var-set next-currency-id (+ currency-id u1))
      (ok currency-id))))

(define-read-only (get-currency (currency-id uint))
  (map-get? currency-registry currency-id))

(define-read-only (get-currency-id-by-code (code (string-ascii 10)))
  (map-get? currency-code-to-id code))

(define-read-only (get-currency-id-by-token (token principal))
  (map-get? token-to-currency-id token))

;; ============================================================================
;; JURISDICTION MANAGEMENT
;; ============================================================================

(define-public (register-jurisdiction
    (country-code (string-ascii 2))
    (region-code (string-ascii 3))
    (name (string-ascii 50))
    (compliance-tier uint)
    (requires-kyc bool)
    (requires-travel-rule bool))
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (asserts! (validate-country-code country-code) ERR_INVALID_COUNTRY_CODE)
    (asserts! (is-none (map-get? country-to-jurisdiction-id country-code)) ERR_JURISDICTION_ALREADY_REGISTERED)
    (let ((jurisdiction-id (var-get next-jurisdiction-id)))
      (map-set jurisdiction-registry jurisdiction-id
        { country-code: country-code, region-code: region-code, name: name, compliance-tier: compliance-tier, requires-kyc: requires-kyc, requires-travel-rule: requires-travel-rule, is-active: true })
      (map-set country-to-jurisdiction-id country-code jurisdiction-id)
      (var-set next-jurisdiction-id (+ jurisdiction-id u1))
      (ok jurisdiction-id))))

(define-read-only (get-jurisdiction (jurisdiction-id uint))
  (map-get? jurisdiction-registry jurisdiction-id))

(define-read-only (get-jurisdiction-id-by-country (country-code (string-ascii 2)))
  (map-get? country-to-jurisdiction-id country-code))

;; ============================================================================
;; SHARD COMPUTATION ENGINE
;; ============================================================================

(define-private (compute-global-shard
    (sender-country (string-ascii 2))
    (receiver-country (string-ascii 2))
    (currency-id uint)
    (amount uint)
    (sender-risk-score uint)
    (receiver-risk-score uint))
  (let (
    (sender-jurisdiction (unwrap! (map-get? country-to-jurisdiction-id sender-country) ERR_UNSUPPORTED_COUNTRY))
    (receiver-jurisdiction (unwrap! (map-get? country-to-jurisdiction-id receiver-country) ERR_UNSUPPORTED_COUNTRY))
    (currency-info (unwrap! (map-get? currency-registry currency-id) ERR_UNSUPPORTED_CURRENCY))
    (sender-j-info (unwrap! (map-get? jurisdiction-registry sender-jurisdiction) ERR_UNSUPPORTED_COUNTRY))
    (receiver-j-info (unwrap! (map-get? jurisdiction-registry receiver-jurisdiction) ERR_UNSUPPORTED_COUNTRY))
    (sender-compliance (get compliance-tier sender-j-info))
    (receiver-compliance (get compliance-tier receiver-j-info))
    (same-country (is-eq sender-country receiver-country))
    (same-region (is-eq (get region-code sender-j-info) (get region-code receiver-j-info)))
    (base-shard (if (get is-stablecoin currency-info) "STABLE"
                    (if (get is-fiat currency-info) "FIAT" "TOKEN")))
    (compliance-shard (if (and (>= sender-compliance u2) (>= receiver-compliance u2)) "HIGH_COMP"
                          (if (or (<= sender-compliance u1) (<= receiver-compliance u1)) "LOW_COMP" "MED_COMP")))
    (risk-shard (if (or (>= sender-risk-score u70) (>= receiver-risk-score u70)) "HIGH_RISK"
                    (if (or (<= sender-risk-score u30) (<= receiver-risk-score u30)) "LOW_RISK" "MED_RISK")))
    (geo-shard (if same-country "DOMESTIC"
                   (if same-region "REGIONAL" "CROSS_REGION")))
  )
    (ok (concat SHARD_PREFIX (concat base-shard (concat "_" (concat compliance-shard (concat "_" (concat risk-shard (concat "_" geo-shard))))))))
  )
)

;; ============================================================================
;; SETTLEMENT RECORDING (MULTI-CURRENCY)
;; ============================================================================

(define-public (register-kyc-extended
    (user principal)
    (country (string-ascii 2))
    (region (string-ascii 3))
    (risk-score uint))
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (asserts! (validate-country-code country) ERR_INVALID_COUNTRY_CODE)
    (map-set kyc-registry user
      { country: country, region: region, status: "verified", risk-score: risk-score, last-verified: (unwrap! (get-block-info? time stacks-block-height) ERR_BLOCK_TIME_UNAVAILABLE) })
    (ok true)))

(define-public (record-global-settlement
    (tx-id (buff 32))
    (sender principal)
    (receiver principal)
    (currency-id uint)
    (amount uint))
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (let (
      (sender-data (unwrap! (map-get? kyc-registry sender) ERR_UNSUPPORTED_COUNTRY))
      (receiver-data (unwrap! (map-get? kyc-registry receiver) ERR_UNSUPPORTED_COUNTRY))
      (sender-country (get country sender-data))
      (receiver-country (get country receiver-data))
      (sender-risk (get risk-score sender-data))
      (receiver-risk (get risk-score receiver-data))
      (shard (unwrap! (compute-global-shard sender-country receiver-country currency-id amount sender-risk receiver-risk) ERR_UNSUPPORTED_COUNTRY)))
      (map-set settlement-shards tx-id shard)
      (print { event: "global-settlement-recorded", tx-id: tx-id, shard: shard, sender: sender, receiver: receiver, currency-id: currency-id, amount: amount, sender-country: sender-country, receiver-country: receiver-country })
      (ok { tx-id: tx-id, shard: shard, currency-id: currency-id }))))

;; ============================================================================
;; BACKWARD COMPATIBILITY LAYER
;; ============================================================================

(define-public (record-zar-settlement (tx-id (buff 32)) (sender principal) (receiver principal) (amount-zar uint))
  (let ((zar-currency-id (unwrap! (map-get? currency-code-to-id "ZAR") ERR_UNSUPPORTED_CURRENCY)))
    (record-global-settlement tx-id sender receiver zar-currency-id amount-zar)))

;; ============================================================================
;; QUERY FUNCTIONS
;; ============================================================================

(define-read-only (get-settlement-shard (tx-id (buff 32)))
  (map-get? settlement-shards tx-id))

(define-read-only (get-kyc-status (user principal))
  (map-get? kyc-registry user))

(define-read-only (get-currency-count)
  (var-get next-currency-id))

(define-read-only (get-jurisdiction-count)
  (var-get next-jurisdiction-id))

;; ============================================================================
;; INITIALIZATION
;; ============================================================================

(define-public (initialize-protocol-currencies)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (try! (register-currency "USD" none true true u2 u2))
    (try! (register-currency "EUR" none true true u2 u2))
    (try! (register-currency "GBP" none true true u2 u2))
    (try! (register-currency "JPY" none true false u0 u2))
    (try! (register-currency "CNY" none true false u2 u1))
    (try! (register-currency "ZAR" none true false u2 u1))
    (try! (register-jurisdiction "US" "NA" "United States" u0 true true))
    (try! (register-jurisdiction "GB" "EU" "United Kingdom" u0 true true))
    (try! (register-jurisdiction "DE" "EU" "Germany" u0 true true))
    (try! (register-jurisdiction "JP" "AP" "Japan" u0 true true))
    (try! (register-jurisdiction "CN" "AP" "China" u1 true true))
    (try! (register-jurisdiction "ZA" "AF" "South Africa" u1 true false))
    (try! (register-jurisdiction "SG" "AP" "Singapore" u2 false false))
    (ok true)))
