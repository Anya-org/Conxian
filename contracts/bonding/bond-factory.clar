;; bond-factory.clar
;; Bond Factory for creating and managing bond instruments
;; Implements SIP-010 FT standard for bond tokens

(impl-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_BOND_NOT_FOUND (err u1002))

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var bond-nonce uint u0)
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)

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
    (user principal)
    (amount uint)
    (duration uint)
  )
  (begin
    ;; Check compliance first
    (asserts!
      (is-ok (contract-call? .regulatory-adapter
        check-clean-hands-compliance
        user
      ))
      ERR_UNAUTHORIZED
    )

    (let (
        (bond-id (+ (var-get bond-nonce) u1))
        (mint-result (ft-mint? bond-token amount tx-sender
          (some 0x0000000000000000000000000000000000000000)
        ))
      )
      (asserts! (is-ok mint-result) ERR_INVALID_AMOUNT)
      (map-set bonds bond-id {
        issuer: tx-sender,
        principal-amount: amount,
        interest-rate: u0,
        maturity-block: (+ (block-height) duration),
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
