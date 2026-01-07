;; bond-factory.clar
;; Bond Factory for creating and managing bond instruments
;; Implements SIP-010 FT standard for bond tokens

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_BOND_NOT_FOUND (err u1002))

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var bond-nonce uint u0)

;; Bond Token
(define-fungible-token bond-token)

;; Bond Storage
(define-map bonds
  uint
  {
    issuer: principal,
    principal-amount: uint,
    interest-rate: uint,
    maturity-block: uint,
    is-active: bool,
  }
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Public Functions
(define-public (create-bond
    (principal-amount uint)
    (interest-rate uint)
    (maturity-block uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)

    (let (
        (bond-id (+ (var-get bond-nonce) u1))
        (mint-result (ft-mint? bond-token principal-amount tx-sender))
      )
      (asserts! (is-ok mint-result) ERR_INVALID_AMOUNT)
      (map-set bonds bond-id {
        issuer: tx-sender,
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        maturity-block: maturity-block,
        is-active: true,
      })
      (var-set bond-nonce bond-id)
      (print {
        event: "bond-created",
        bond-id: bond-id,
        issuer: tx-sender,
      })
      (ok bond-id)
    )
  )
)

(define-read-only (get-bond-info (bond-id uint))
  (match (map-get? bonds bond-id)
    bond (ok bond)
    (err ERR_BOND_NOT_FOUND)
  )
)
