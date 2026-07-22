;; protocol-fee-source-trait.clar
;;
;; Source-custody callback interface for the canonical protocol-fee collector.
;; A collector callback receives only the collector-computed debit, the
;; collector's fixed recipient, and (for SIP-010) the collector-selected token.
;; Implementations must authenticate the immediate caller before spending their
;; own custody. A production source should create its pending debit privately
;; and immediately invoke the collector from one atomic entrypoint; the
;; collector authenticates source/callback/delta but cannot use block-height
;; equality as proof that a separately prepared record is same-transaction.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-trait protocol-fee-source-trait
  (
    (prepay-stx-fee
      (uint principal)
      (response bool uint))
    (prepay-ft-fee
      (<sip-010-ft-trait> uint principal)
      (response bool uint))
  )
)
