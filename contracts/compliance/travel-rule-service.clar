;; travel-rule-service.clar
;; Conxian Enterprise Standard: Travel Rule Service (IVMS101 Compliant Audit Trail)
;; Implements FATF Recommendation 16 for on-chain audit of off-chain data exchange.
;; Tier 0: Automated Compliance Logging

;; Constants
(define-constant ERR_UNAUTHORIZED u9000)
(define-constant ERR_INVALID_DATA u9001)

;; Data Vars
(define-data-var compliance-admin principal tx-sender)

;; Events
(define-private (emit-event (event (string-ascii 32)) (data (optional (buff 256))))
    (print { event: event, data: data, block: stacks-block-time })
)

;; @desc Log IVMS101 Data Hash for Travel Rule Compliance
;; This function creates an immutable record that Travel Rule data was exchanged for a transaction.
;; The actual PII (IVMS101 payload) is exchanged off-chain between VASPs or Wallets.
;; The hash anchors that data to the blockchain for auditability.
(define-public (log-travel-rule-data 
        (transaction-ref (buff 32)) ;; Unique ID for the transfer (e.g. hash of inputs)
        (ivms101-hash (buff 32))    ;; SHA256 of the IVMS101 JSON payload
        (originator-vasp (string-ascii 20)) ;; LEI or VASP ID
        (beneficiary-vasp (string-ascii 20)) ;; LEI or VASP ID
        (amount uint)
        (token principal)
    )
    (begin
        ;; In a full system, we might verify the caller is a registered VASP or the Vault.
;; For now, we allow any compliant entity to log (Open Audit).
        (print {
            event: "travel-rule-log",
            tx-ref: transaction-ref,
            data-hash: ivms101-hash,
            originator: originator-vasp,
            beneficiary: beneficiary-vasp,
            amount: amount,
            token: token,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; @desc Validate if a transfer requires Travel Rule data
;; Returns true if amount > threshold (e.g. 1000 USD/EUR equiv)
(define-read-only (requires-travel-rule (amount uint))
    ;; Mock threshold logic. Ideally calls an Oracle for Fiat value.
    ;; Assuming 1 unit = 1 satoshi for sBTC. 100,000,000 sats = 1 BTC.
    ;; Threshold: ~$1000. If BTC = $100k, then 0.01 BTC = 1,000,000 sats.
    (> amount u1000000)
)
