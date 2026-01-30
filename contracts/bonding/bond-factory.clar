;; bond-factory.clar
;; Bond Factory for creating and managing bond instruments
;; Implements SIP-010 FT standard for bond tokens

(impl-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_AMOUNT u1001)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    ;; Transfer logic would go here
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Conxian Bond Token")
)

(define-read-only (get-symbol)
  (ok "CXBD")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (owner principal))
  (ok u0) ;; Placeholder implementation
)

(define-read-only (get-total-supply)
  (ok u0) ;; Placeholder implementation
)

(define-read-only (get-token-uri)
  (ok (some u"https://conxian.io/metadata/bond"))
)
(define-constant ERR_BOND_NOT_FOUND u1002)

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
      (err ERR_UNAUTHORIZED)
    )

    (let (
        (bond-id (+ (var-get bond-nonce) u1))
        (mint-result (ft-mint? bond-token amount tx-sender))
      )
      (asserts! (is-ok mint-result) (err ERR_INVALID_AMOUNT))
      (map-set bonds bond-id {
        issuer: tx-sender,
        principal-amount: amount,
        interest-rate: u0,
        maturity-block: (+ block-height duration),
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
