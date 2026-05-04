;; operational-treasury.clar
;; Conxian Enterprise Standard: Operational Treasury

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)

;; Principal Registry
(define-map protocol-principals (string-ascii 50) principal)

;; Authorization
(define-private (is-authorized)
  (or
    (is-eq tx-sender (var-get contract-owner))
    (is-eq tx-sender .agent-treasury)
    (is-eq tx-sender .ops-engine)
  )
)

;; Registry Logic

(define-public (initialize (new-owner principal))
  (begin
    (asserts! (is-standard? new-owner) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get initialized)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (var-set initialized true)
    (ok true)
  )
)

(define-public (set-protocol-principal (name (string-ascii 50)) (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set protocol-principals name address)
    (ok true)
  )
)

(define-read-only (get-protocol-principal (name (string-ascii 50)))
  (map-get? protocol-principals name)
)

;; Core Logic

(define-public (deposit-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (withdraw-stx (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

(define-public (withdraw-token (token <sip-010-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-standard? new-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)
