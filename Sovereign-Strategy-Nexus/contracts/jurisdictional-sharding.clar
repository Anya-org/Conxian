;; jurisdictional-sharding.clar
;; Guardian: Sovereignty
;; Jurisdictional sharding + SARB/SARS monitoring for ZAR-linked settlements.

(define-constant ERR_UNAUTHORIZED (err u7100))
(define-constant ERR_TX_REPLAY_MISMATCH (err u7101))
(define-constant ERR_INVALID_REGION (err u7102))
(define-constant ERR_UNSUPPORTED_YEAR (err u7103))
(define-constant ERR_BLOCK_TIME_UNAVAILABLE (err u7104))

(define-constant SHARD_ONSHORE u0)
(define-constant SHARD_OFFSHORE u1)
(define-constant SHARD_GLOBAL u2)

(define-constant REGION_UNKNOWN u0)
(define-constant REGION_SADC u1)

(define-constant YEAR_2024_START u1704067200)
(define-constant YEAR_2025_START u1735689600)
(define-constant YEAR_2026_START u1767225600)
(define-constant YEAR_2027_START u1798761600)
(define-constant YEAR_2028_START u1830297600)
(define-constant YEAR_2029_START u1861920000)
(define-constant YEAR_2030_START u1893456000)
(define-constant YEAR_2031_START u1924992000)
(define-constant YEAR_2032_START u1956528000)
(define-constant YEAR_2033_START u1988150400)
(define-constant YEAR_2034_START u2019686400)
(define-constant YEAR_2035_START u2051222400)
(define-constant YEAR_2036_START u2082758400)
(define-constant YEAR_2037_START u2114380800)
(define-constant YEAR_2038_START u2145916800)
(define-constant YEAR_2039_START u2177452800)
(define-constant YEAR_2040_START u2208988800)
(define-constant YEAR_2041_START u2240611200)
(define-constant YEAR_2042_START u2272147200)
(define-constant YEAR_2043_START u2303683200)

;; Supported settlement years: 2024–2042 inclusive.
;; Calls that rely on block time will return ERR_UNSUPPORTED_YEAR once block-time >= YEAR_2043_START.

;; SARB mandate thresholds (ZAR/year)
(define-constant SDA_LIMIT_ZAR u1500000)
(define-constant FIA_LIMIT_ZAR u12000000)

;; Sovereign shard triggers
(define-constant ONSHORE_TRIGGER_ZAR u50000)

(define-data-var jurisdiction-country (string-ascii 3) "ZAF")
(define-data-var jurisdiction-region uint REGION_SADC)
(define-data-var onshore-trigger-zar uint ONSHORE_TRIGGER_ZAR)
(define-data-var enable-sadc-fallback bool true)

(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-czar principal tx-sender)

;; country -> region
(define-map country-regions
  { country: (string-ascii 3) }
  { region: uint }
)

;; tx-id -> shard
(define-map settlement-shards (buff 32) uint)

;; tx-id -> settlement fingerprint
(define-map settlement-fingerprints
  (buff 32)
  { sender: principal, receiver: principal, amount-zar: uint }
)

;; (shard, user, year) -> total ZAR egress
(define-map annual-zar-egress
  { shard: uint, user: principal, year: uint }
  { total: uint }
)

;; Tier-1 rails / counterparties are maintained on-chain and used to derive `tier1-rail`.
(define-map tier1-counterparties principal bool)

;; (user, year) -> total ZAR egress used for allowance checks (SDA/FIA)
(define-map annual-zar-allowance-egress
  { user: principal, year: uint }
  uint
)

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-czar)
  (is-eq tx-sender (var-get compliance-czar))
)

(define-private (is-sadc-country (country (string-ascii 3)))
  (or
    (is-eq country "AGO")
    (is-eq country "BWA")
    (is-eq country "COD")
    (is-eq country "COM")
    (is-eq country "LSO")
    (is-eq country "MDG")
    (is-eq country "MOZ")
    (is-eq country "MUS")
    (is-eq country "MWI")
    (is-eq country "NAM")
    (is-eq country "SYC")
    (is-eq country "SWZ")
    (is-eq country "TZA")
    (is-eq country "ZAF")
    (is-eq country "ZMB")
    (is-eq country "ZWE")
  )
)

(define-private (get-country-region (country (string-ascii 3)))
  (if (is-eq country (var-get jurisdiction-country))
    (var-get jurisdiction-region)
    (match (map-get? country-regions { country: country })
      entry
        (get region entry)
      (if (and (var-get enable-sadc-fallback) (is-sadc-country country))
        REGION_SADC
        REGION_UNKNOWN
      )
    )
  )
)

(define-private (assert-supported-block-time (block-time uint))
  (asserts! (and (>= block-time YEAR_2024_START) (< block-time YEAR_2043_START)) ERR_UNSUPPORTED_YEAR)
)

(define-private (is-tier1-rail (sender principal) (receiver principal))
  (or
    (default-to false (map-get? tier1-counterparties sender))
    (default-to false (map-get? tier1-counterparties receiver))
  )
)

(define-private (is-allowance-egress
    (sender-country (string-ascii 3))
    (receiver-country (string-ascii 3))
  )
  (let ((jurisdiction (var-get jurisdiction-country)))
    (and
      (is-eq sender-country jurisdiction)
      (not (is-eq receiver-country jurisdiction))
    )
  )
)

(define-private (year-from-unix-time (unix-time uint))
  (if (< unix-time YEAR_2025_START)
    u2024
    (if (< unix-time YEAR_2026_START)
      u2025
      (if (< unix-time YEAR_2027_START)
        u2026
        (if (< unix-time YEAR_2028_START)
          u2027
          (if (< unix-time YEAR_2029_START)
            u2028
            (if (< unix-time YEAR_2030_START)
              u2029
              (if (< unix-time YEAR_2031_START)
                u2030
                (if (< unix-time YEAR_2032_START)
                  u2031
                  (if (< unix-time YEAR_2033_START)
                    u2032
                    (if (< unix-time YEAR_2034_START)
                      u2033
                      (if (< unix-time YEAR_2035_START)
                        u2034
                        (if (< unix-time YEAR_2036_START)
                          u2035
                          (if (< unix-time YEAR_2037_START)
                            u2036
                            (if (< unix-time YEAR_2038_START)
                              u2037
                              (if (< unix-time YEAR_2039_START)
                                u2038
                                (if (< unix-time YEAR_2040_START)
                                  u2039
                                  (if (< unix-time YEAR_2041_START)
                                    u2040
                                    (if (< unix-time YEAR_2042_START)
                                      u2041
                                      u2042
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-private (compute-shard-by-country
    (sender-country (string-ascii 3))
    (receiver-country (string-ascii 3))
    (amount-zar uint)
    (tier1-rail bool)
  )
  (let (
      (jurisdiction (var-get jurisdiction-country))
      (jur-region (var-get jurisdiction-region))
      (receiver-region (get-country-region receiver-country))
    )
    (if tier1-rail
      SHARD_GLOBAL
      (if (or (not (is-eq sender-country jurisdiction)) (not (is-eq receiver-region jur-region)))
        SHARD_OFFSHORE
        (if (and (is-eq sender-country jurisdiction) (is-eq receiver-country jurisdiction) (> amount-zar (var-get onshore-trigger-zar)))
          SHARD_ONSHORE
          SHARD_GLOBAL
        )
      )
    )
  )
)

(define-read-only (compute-shard
    (sender principal)
    (receiver principal)
    (amount-zar uint)
  )
  (let (
      (sender-country (get country (contract-call? .kyc-registry get-identity-status sender)))
      (receiver-country (get country (contract-call? .kyc-registry get-identity-status receiver)))
      (tier1-rail (is-tier1-rail sender receiver))
    )
    (compute-shard-by-country sender-country receiver-country amount-zar tier1-rail)
  )
)

(define-private (get-annual-total
    (shard uint)
    (user principal)
    (year uint)
  )
  (get total (default-to { total: u0 } (map-get? annual-zar-egress { shard: shard, user: user, year: year })))
)

(define-private (get-allowance-total
    (user principal)
    (year uint)
  )
  (default-to u0 (map-get? annual-zar-allowance-egress { user: user, year: year }))
)

(define-public (record-zar-settlement
    (tx-id (buff 32))
    (sender principal)
    (receiver principal)
    (amount-zar uint)
  )
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (match (map-get? settlement-shards tx-id)
      existing-shard
        (match (map-get? settlement-fingerprints tx-id)
          existing
            (if (and
                (is-eq sender (get sender existing))
                (is-eq receiver (get receiver existing))
                (is-eq amount-zar (get amount-zar existing))
              )
              (ok { tx-id: tx-id, shard: existing-shard })
              ERR_TX_REPLAY_MISMATCH
            )
          ERR_TX_REPLAY_MISMATCH
        )
      (let (
          (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
          (sender-country (get country (contract-call? .kyc-registry get-identity-status sender)))
          (receiver-country (get country (contract-call? .kyc-registry get-identity-status receiver)))
          (tier1-rail (is-tier1-rail sender receiver))
          (shard (compute-shard-by-country sender-country receiver-country amount-zar tier1-rail))
        )
        (begin
          (assert-supported-block-time block-time)
          (let ((year (year-from-unix-time block-time)))
            (begin
              (map-set settlement-shards tx-id shard)
              (map-set settlement-fingerprints tx-id {
                sender: sender,
                receiver: receiver,
                amount-zar: amount-zar
              })
              (let ((prev-total (get-annual-total shard sender year)))
                (map-set annual-zar-egress { shard: shard, user: sender, year: year } { total: (+ prev-total amount-zar) })
              )
              (if (is-allowance-egress sender-country receiver-country)
                (let ((prev-allowance-total (get-allowance-total sender year)))
                  (map-set annual-zar-allowance-egress { user: sender, year: year } (+ prev-allowance-total amount-zar))
                )
                true
              )
              (print {
                event: "zar-settlement-recorded",
                tx-id: tx-id,
                shard: shard,
                sender: sender,
                receiver: receiver,
                amount-zar: amount-zar,
                year: year,
                tier1-rail: tier1-rail,
                block-time: block-time,
                block-height: block-height,
                burn-block-height: burn-block-height
              })
              (ok { tx-id: tx-id, shard: shard })
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-current-year)
  (let ((block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE)))
    (begin
      (assert-supported-block-time block-time)
      (ok (year-from-unix-time block-time))
    )
  )
)

(define-read-only (get-network-time)
  (let ((block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE)))
    (begin
      (assert-supported-block-time block-time)
      (ok {
        block-time: block-time,
        block-height: block-height,
        burn-block-height: burn-block-height,
        year: (year-from-unix-time block-time)
      })
    )
  )
)

(define-read-only (get-shard-for-tx (tx-id (buff 32)))
  (map-get? settlement-shards tx-id)
)

(define-read-only (get-annual-zar-egress (shard uint) (user principal) (year uint))
  (ok (get-annual-total shard user year))
)

(define-read-only (get-annual-zar-allowance-egress (user principal) (year uint))
  (ok (get-allowance-total user year))
)

(define-read-only (get-allowance-status (user principal) (year uint))
  (let ((total (get-allowance-total user year)))
    (ok {
      total: total,
      exceeds-sda: (>= total SDA_LIMIT_ZAR),
      exceeds-fia: (>= total FIA_LIMIT_ZAR)
    })
  )
)

(define-public (set-compliance-czar (new-czar principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev-czar (var-get compliance-czar))
      )
      (begin
        (assert-supported-block-time block-time)
        (var-set compliance-czar new-czar)
        (print {
          event: "compliance-czar-updated",
          prev-czar: prev-czar,
          new-czar: new-czar,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (set-jurisdiction
    (country (string-ascii 3))
    (region uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq region REGION_UNKNOWN)) ERR_INVALID_REGION)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev-country (var-get jurisdiction-country))
        (prev-region (var-get jurisdiction-region))
      )
      (begin
        (assert-supported-block-time block-time)
        (var-set jurisdiction-country country)
        (var-set jurisdiction-region region)
        (print {
          event: "jurisdiction-updated",
          prev-country: prev-country,
          prev-region: prev-region,
          new-country: country,
          new-region: region,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (set-country-region
    (country (string-ascii 3))
    (region uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev (map-get? country-regions { country: country }))
      )
      (begin
        (assert-supported-block-time block-time)
        (map-set country-regions { country: country } { region: region })
        (print {
          event: "country-region-set",
          country: country,
          prev-region: (get region (default-to { region: REGION_UNKNOWN } prev)),
          new-region: region,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (delete-country-region (country (string-ascii 3)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev (map-get? country-regions { country: country }))
      )
      (begin
        (assert-supported-block-time block-time)
        (map-delete country-regions { country: country })
        (print {
          event: "country-region-deleted",
          country: country,
          prev-region: (get region (default-to { region: REGION_UNKNOWN } prev)),
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (set-onshore-trigger-zar (new-trigger-zar uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev-trigger-zar (var-get onshore-trigger-zar))
      )
      (begin
        (assert-supported-block-time block-time)
        (var-set onshore-trigger-zar new-trigger-zar)
        (print {
          event: "onshore-trigger-updated",
          prev-onshore-trigger-zar: prev-trigger-zar,
          new-onshore-trigger-zar: new-trigger-zar,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (set-tier1-counterparty (counterparty principal) (enabled bool))
  (begin
    (asserts! (or (is-owner) (is-czar)) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev (default-to false (map-get? tier1-counterparties counterparty)))
      )
      (begin
        (assert-supported-block-time block-time)
        (if enabled
          (map-set tier1-counterparties counterparty true)
          (map-delete tier1-counterparties counterparty)
        )
        (print {
          event: "tier1-counterparty-updated",
          counterparty: counterparty,
          prev-enabled: prev,
          new-enabled: enabled,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-read-only (is-tier1-counterparty (counterparty principal))
  (ok (default-to false (map-get? tier1-counterparties counterparty)))
)

(define-public (set-sadc-fallback-enabled (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev-enabled (var-get enable-sadc-fallback))
      )
      (begin
        (assert-supported-block-time block-time)
        (var-set enable-sadc-fallback enabled)
        (print {
          event: "sadc-fallback-updated",
          prev-enabled: prev-enabled,
          new-enabled: enabled,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
        (block-time (unwrap! (get-block-info? time block-height) ERR_BLOCK_TIME_UNAVAILABLE))
        (prev-owner (var-get contract-owner))
      )
      (begin
        (assert-supported-block-time block-time)
        (var-set contract-owner new-owner)
        (print {
          event: "ownership-transferred",
          prev-owner: prev-owner,
          new-owner: new-owner,
          block-time: block-time,
          block-height: block-height,
          burn-block-height: burn-block-height
        })
        (ok true)
      )
    )
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-compliance-czar)
  (ok (var-get compliance-czar))
)

(define-read-only (get-jurisdiction)
  (ok {
    country: (var-get jurisdiction-country),
    region: (var-get jurisdiction-region),
    onshore-trigger-zar: (var-get onshore-trigger-zar)
  })
)

(define-read-only (get-region-for-country (country (string-ascii 3)))
  (let ((jurisdiction (var-get jurisdiction-country)))
    (ok (if (is-eq country jurisdiction)
      (var-get jurisdiction-region)
      (get-country-region country)
    ))
  )
)
