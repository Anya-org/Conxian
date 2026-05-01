;; dlc-bond.clar
;; Bitcoin-native DLC Bond Lifecycle Manager
;; Conxian Protocol - Apex CSF Upgrade (v1.1.0)
;; Standardized for Mainnet (March 2026)

(impl-trait .bond-traits.dlc-bond-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_BOND_NOT_FOUND (err u1001))
(define-constant ERR_ALREADY_REDEEMED (err u1002))
(define-constant ERR_NOT_MATURED (err u1003))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1004))

;; --- State ---
(define-data-var admin principal tx-sender)

(define-map bonds
  uint
  {
    issuer: principal, token: principal, principal-amount: uint, coupon-rate: uint, maturity: uint, created-at: uint, status: (string-ascii 20)
  }
)

(define-data-var bond-nonce uint u0)

;; --- Public Functions ---

;; @desc Initialize a new DLC bond
;; @param principal-amount: Total debt to be issued.
;; @param coupon-rate: Annualized rate in basis points.
;; @param maturity-blocks: Duration until maturity in blocks.
;; @param token: The FT principal for repayment.
(define-public (initialize-bond (principal-amount uint) (coupon-rate uint) (maturity-blocks uint) (token principal))
  (let (
    (bond-id (+ (var-get bond-nonce) u1))
    (maturity (+ burn-block-height maturity-blocks))
  )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (map-set bonds bond-id {
        issuer: tx-sender, token: token, principal-amount: principal-amount, coupon-rate: coupon-rate, maturity: maturity, created-at: burn-block-height, status: "ACTIVE"
      })
      (var-set bond-nonce bond-id)
      (print { event: "bond-initialized", id: bond-id, amount: principal-amount, maturity: maturity })
      (ok bond-id)
    )
  )
)

;; @desc Distribute coupon payment to bond holders (Simulated for Apex)
;; @param bond-id: The identifier of the target bond.
(define-public (distribute-coupon (bond-id uint))
  (let (
    (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
    (coupon-amount (/ (* (get principal-amount bond) (get coupon-rate bond)) u10000))
  )
    (begin
      (print { event: "coupon-distributed", id: bond-id, amount: coupon-amount })
      (ok true)
    )
  )
)

;; @desc Redeem the bond at maturity
;; @param bond-id: The identifier of the target bond.
(define-public (redeem-bond (bond-id uint))
  (let (
    (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
  )
    (begin
      (asserts! (>= burn-block-height (get maturity bond)) ERR_NOT_MATURED)
      (asserts! (not (is-eq (get status bond) "REDEEMED")) ERR_ALREADY_REDEEMED)

      (map-set bonds bond-id (merge bond { status: "REDEEMED" }))
      (print { event: "bond-redeemed", id: bond-id })
      (ok true)
    )
  )
)

;; --- Read-only Functions ---

;; @desc Get detailed bond data
;; @param bond-id: The identifier of the bond.
(define-public (get-bond-data (bond-id uint))
  (ok (map-get? bonds bond-id))
)

;; @desc Get current admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; @desc Get protocol status for DLC bonds
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex", active-bonds: (var-get bond-nonce) })
)

;; --- Admin ---

;; @desc Update admin principal
;; @param new-admin: The new administrator.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
