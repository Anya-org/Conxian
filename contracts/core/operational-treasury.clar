;; operational-treasury.clar
;; Conxian Enterprise Standard: Operational Treasury
;; Manages protocol-wide principal registration and secure asset custody.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant TREASURY_CONTROL_KEY "treasury-control")
(define-constant TREASURY_WRAPPER_KEY "treasury-wrapper")

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)

;; Principal Registry
(define-map protocol-principals (string-ascii 50) principal)

;; Authorization
(define-private (is-authorized-principal (name (string-ascii 50)))
  (match (map-get? protocol-principals name)
    authorized-principal (is-eq tx-sender authorized-principal)
    false
  )
)

(define-private (is-authorized)
  (or
    (is-eq tx-sender (var-get contract-owner))
    ;; Canonical treasury controller path (Phase 1, principal-injected)
    (is-authorized-principal TREASURY_CONTROL_KEY)
    ;; Legacy compatibility wrapper path (principal-injected)
    (is-authorized-principal TREASURY_WRAPPER_KEY)
    (is-eq tx-sender .ops-engine)
  )
)

;; Registry Logic

;; @desc Initializes the operational treasury with a designated owner.
;; @param new-owner: The owner principal.
(define-public (initialize (new-owner principal))
  (begin
    (asserts! (not (var-get initialized)) (err ERR_UNAUTHORIZED))
    ;; `contract-owner` is initialized to the publish-time tx-sender. Require
    ;; that principal to perform the first call so an arbitrary first caller
    ;; cannot front-run initialization and take custody ownership.
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Registers or updates a protocol principal in the registry. Owner only.
;; @param name: Descriptive name of the principal.
;; @param address: The principal address.
(define-public (set-protocol-principal (name (string-ascii 50)) (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set protocol-principals name address)
    (ok true)
  )
)

;; @desc Retrieves a registered protocol principal by name.
;; @param name: The descriptive name to query.
(define-read-only (get-protocol-principal (name (string-ascii 50)))
  (map-get? protocol-principals name)
)

;; Core Logic

;; @desc Deposits STX into the operational treasury.
;; @param amount: Quantity of STX to deposit.
(define-public (deposit-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; @desc Withdraws STX from the operational treasury. Authorized callers only.
;; @param amount: Quantity of STX to withdraw.
;; @param recipient: Principal receiving the STX.
(define-public (withdraw-stx (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; @desc Withdraws SIP-010 tokens from the operational treasury. Authorized callers only.
;; @param token: The token trait implementation.
;; @param amount: Quantity of tokens to withdraw.
;; @param recipient: Principal receiving the tokens.
(define-public (withdraw-token (token <sip-010-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-authorized) (err ERR_UNAUTHORIZED))
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)

;; @desc Updates the contract owner. Owner only.
;; @param new-owner: The new owner principal.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Returns the current contract owner principal.
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Returns whether the publish-time owner has completed initialization. The
;; collector uses this fixed read-only gate before any custody route so assets
;; cannot be forwarded into an uninitialized treasury.
(define-read-only (is-initialized)
  (var-get initialized)
)
