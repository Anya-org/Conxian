;; operational-treasury.clar
;; Conxian Enterprise Standard: Operational Treasury
;; Collects fees from PaaS Factory, AMM, and other modules.
;; Tier 0: "Hands-Off" Management via Agent Treasury / Timelock.
;; Extended in April 2026: Principal Registry for Sovereign Handoff.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; Data Vars
(define-data-var contract-owner principal tx-sender)

;; Principal Registry
(define-map protocol-principals (string-ascii 50) principal)

;; Authorization
(define-private (is-authorized)
  (or
    (is-eq tx-sender (var-get contract-owner))
    (is-eq tx-sender .fiscal-orchestrator) ;; The Autonomous Sovereign-Financial-Office
    (is-eq tx-sender .ops-engine) ;; The Executive
  )
)

;; Registry Logic

;; @desc Sets a protocol principal by name. Owner only.
(define-public (set-protocol-principal (name (string-ascii 50)) (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set protocol-principals name address)
    (ok true)
  )
)

;; @desc Gets a protocol principal by name.
(define-read-only (get-protocol-principal (name (string-ascii 50)))
  (map-get? protocol-principals name)
)

;; Core Logic

;; @desc Deposit STX (Fee Collection)
(define-public (deposit-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; @desc Withdraw STX (Budget Allocation / Ops Expenses)
(define-public (withdraw-stx
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; @desc Withdraw SIP-010 Tokens
(define-public (withdraw-token
    (token <sip-010-trait>)
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)

;; Admin
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)
