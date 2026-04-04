;; jurisdictional-sharding.clar
;; Guardian: Sovereignty
;; Jurisdictional sharding + SARB/SARS monitoring for ZAR-linked settlements.

(define-constant ERR_UNAUTHORIZED (err u7100))
(define-constant ERR_TX_REPLAY_MISMATCH (err u7101))

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

;; SARB mandate thresholds (ZAR/year)
(define-constant SDA_LIMIT_ZAR u1500000)
(define-constant FIA_LIMIT_ZAR u12000000)

;; Sovereign shard triggers
(define-constant ONSHORE_TRIGGER_ZAR u50000)

(define-data-var jurisdiction-country (string-ascii 3) "ZAF")
(define-data-var jurisdiction-region uint REGION_SADC)
(define-data-var onshore-trigger-zar uint ONSHORE_TRIGGER_ZAR)

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
  { sender: principal, receiver: principal, amount-zar: uint, tier1-rail: bool }
)

;; (shard, user, year) -> total ZAR egress
(define-map annual-zar-egress
  { shard: uint, user: principal, year: uint }
  { total: uint }
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
  (match (map-get? country-regions { country: country })
    entry
      (get region entry)
    (if (is-sadc-country country)
      REGION_SADC
      REGION_UNKNOWN
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

(define-read-only (compute-shard
    (sender principal)
    (receiver principal)
    (amount-zar uint)
    (tier1-rail bool)
  )
  (let (
      (sender-country (get country (contract-call? .kyc-registry get-identity-status sender)))
      (receiver-country (get country (contract-call? .kyc-registry get-identity-status receiver)))
      (jurisdiction (var-get jurisdiction-country))
      (jurisdiction-region (var-get jurisdiction-region))
      (receiver-region (get-country-region receiver-country))
    )
    (if tier1-rail
      SHARD_GLOBAL
      (if (or (not (is-eq sender-country jurisdiction)) (not (is-eq receiver-region jurisdiction-region)))
        SHARD_OFFSHORE
        (if (and (is-eq sender-country jurisdiction) (is-eq receiver-country jurisdiction) (> amount-zar (var-get onshore-trigger-zar)))
          SHARD_ONSHORE
          SHARD_GLOBAL
        )
      )
    )
  )
)

(define-private (get-annual-total
    (shard uint)
    (user principal)
    (year uint)
  )
  (get total (default-to { total: u0 } (map-get? annual-zar-egress { shard: shard, user: user, year: year })))
)

(define-public (record-zar-settlement
    (tx-id (buff 32))
    (sender principal)
    (receiver principal)
    (amount-zar uint)
    (tier1-rail bool)
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
                (is-eq tier1-rail (get tier1-rail existing))
              )
              (ok { tx-id: tx-id, shard: existing-shard })
              ERR_TX_REPLAY_MISMATCH
            )
          ERR_TX_REPLAY_MISMATCH
        )
      (let (
          (block-time (unwrap-panic (get-block-info? time block-height)))
          (year (year-from-unix-time block-time))
          (shard (compute-shard sender receiver amount-zar tier1-rail))
        )
        (begin
          (map-set settlement-shards tx-id shard)
          (map-set settlement-fingerprints tx-id {
            sender: sender,
            receiver: receiver,
            amount-zar: amount-zar,
            tier1-rail: tier1-rail
          })
          (let ((prev-total (get-annual-total shard sender year)))
            (map-set annual-zar-egress { shard: shard, user: sender, year: year } { total: (+ prev-total amount-zar) })
          )
          (print {
            event: "zar-settlement-recorded",
            tx-id: tx-id,
            shard: shard,
            sender: sender,
            receiver: receiver,
            amount-zar: amount-zar,
            year: year,
            timestamp: block-time
          })
          (ok { tx-id: tx-id, shard: shard })
        )
      )
    )
  )
)

(define-read-only (get-current-year)
  (let ((block-time (unwrap-panic (get-block-info? time block-height))))
    (ok (year-from-unix-time block-time))
  )
)

(define-read-only (get-shard-for-tx (tx-id (buff 32)))
  (map-get? settlement-shards tx-id)
)

(define-read-only (get-annual-zar-egress (shard uint) (user principal) (year uint))
  (ok (get-annual-total shard user year))
)

(define-read-only (get-allowance-status (shard uint) (user principal) (year uint))
  (let ((total (get-annual-total shard user year)))
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
    (var-set compliance-czar new-czar)
    (ok true)
  )
)

(define-public (set-jurisdiction
    (country (string-ascii 3))
    (region uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set jurisdiction-country country)
    (var-set jurisdiction-region region)
    (ok true)
  )
)

(define-public (set-country-region
    (country (string-ascii 3))
    (region uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set country-regions { country: country } { region: region })
    (ok true)
  )
)

(define-public (delete-country-region (country (string-ascii 3)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-delete country-regions { country: country })
    (ok true)
  )
)

(define-public (set-onshore-trigger-zar (new-trigger-zar uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set onshore-trigger-zar new-trigger-zar)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
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
  (ok (get-country-region country))
)
