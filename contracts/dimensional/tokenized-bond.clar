;; tokenized-bond.clar
;; Conxian SAB: Tokenized Bond System
;; Tokenizes traditional bonds for dimensional trading

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u30014))
(define-constant ERR_BOND_NOT_FOUND (err u30015))
(define-constant ERR_INVALID_AMOUNT (err u30016))

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var total-supply uint u0)

;; Bond storage
(define-map bonds
  uint
  {
    issuer: principal,
    principal-amount: uint,
    interest-rate: uint,
    maturity-block: uint,
    created-block: uint,
    is-active: bool,
    metadata: (string-ascii 128),
  }
)

(define-map bond-holdings
  {
    bond-id: uint,
    holder: principal,
  }
  uint
)

;; Public functions
(define-public (issue-bond
    (principal-amount uint)
    (interest-rate uint)
    (maturity-blocks uint)
    (metadata (string-ascii 128))
  )
  (begin
    (asserts! (> principal-amount u0) ERR_INVALID_AMOUNT)
    (let ((bond-id (+ (var-get total-supply) u1)))
      (map-set bonds bond-id {
        issuer: tx-sender,
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        maturity-block: (+ block-height maturity-blocks),
        created-block: block-height,
        is-active: true,
        metadata: metadata,
      })
      (map-set bond-holdings {
        bond-id: bond-id,
        holder: tx-sender,
      }
        principal-amount
      )
      (var-set total-supply (+ (var-get total-supply) u1))
      (ok bond-id)
    )
  )
)

(define-public (transfer-bond
    (bond-id uint)
    (amount uint)
    (recipient principal)
  )
  (begin
    (match (map-get? bonds bond-id)
      bond (begin
        (asserts! (get is-active bond) ERR_BOND_NOT_FOUND)
        (let ((current-holdings (default-to u0
            (map-get? bond-holdings {
              bond-id: bond-id,
              holder: tx-sender,
            })
          )))
          (asserts! (>= current-holdings amount) ERR_INVALID_AMOUNT)
          (map-set bond-holdings {
            bond-id: bond-id,
            holder: tx-sender,
          }
            (- current-holdings amount)
          )
          (map-set bond-holdings {
            bond-id: bond-id,
            holder: recipient,
          }
            (+
              (default-to u0
                (map-get? bond-holdings {
                  bond-id: bond-id,
                  holder: recipient,
                })
              )
              amount
            ))
          (ok true)
        )
      )
      (err ERR_BOND_NOT_FOUND)
    )
  )
)

(define-public (redeem-bond (bond-id uint))
  (begin
    (match (map-get? bonds bond-id)
      bond (begin
        (asserts! (is-eq (get issuer bond) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (>= block-height (get maturity-block bond)) ERR_BOND_NOT_FOUND)
        (let ((holdings (default-to u0
            (map-get? bond-holdings {
              bond-id: bond-id,
              holder: tx-sender,
            })
          )))
          (let ((interest-amount (/ (* holdings (get interest-rate bond)) 10000)))
            (map-set bonds bond-id (merge bond { is-active: false }))
            (map-delete bond-holdings {
              bond-id: bond-id,
              holder: tx-sender,
            })
            (ok (+ holdings interest-amount))
          )
        )
      )
      (err ERR_BOND_NOT_FOUND)
    )
  )
)

;; Read-only functions
(define-read-only (get-bond (bond-id uint))
  (match (map-get? bonds bond-id)
    bond (ok bond)
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-bond-holding
    (bond-id uint)
    (holder principal)
  )
  (ok (default-to u0
    (map-get? bond-holdings {
      bond-id: bond-id,
      holder: holder,
    })
  ))
)

;; SIP-010 trait implementation
(define-read-only (get-name)
  (ok "Tokenized Bond")
)

(define-read-only (get-symbol)
  (ok "TBOND")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok u0)
)
;; Bonds are not fungible tokens

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? bonds token-id)
    bond (ok (some (get metadata bond)))
    (ok none)
  )
)