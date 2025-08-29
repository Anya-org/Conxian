;; tokenized-bond.clar
;; A SIP-010 compliant token representing a tokenized bond.

(impl-trait .sip-010-trait.sip-010-trait)

(define-fungible-token tokenized-bond)

(define-constant ERR_UNAUTHORIZED u101)
(define-constant ERR_NOT_OWNER u102)
(define-constant ERR_BOND_NOT_MATURE u103)
(define-constant ERR_INSUFFICIENT_FUNDS u104)
(define-constant ERR_INVALID_BOND_ID u105)
(define-constant ERR_ALREADY_REDEEMED u106)

(define-data-var contract-owner principal tx-sender)
(define-data-var bond-id-counter uint u0)

(define-map bonds uint {
  issuer: principal,
  principal-amount: uint,
  coupon-rate: uint, ;; scaled by 10000
  maturity-height: uint,
  is-redeemed: bool
})

;; --- Owner Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Public Functions ---

(define-public (issue-bond (principal-amount uint) (coupon-rate uint) (maturity-period uint))
  (let ((issuer tx-sender)
        (new-bond-id (+ (var-get bond-id-counter) u1)))
    (var-set bond-id-counter new-bond-id)
    (map-set bonds new-bond-id {
      issuer: issuer,
      principal-amount: principal-amount,
      coupon-rate: coupon-rate,
      maturity-height: (+ block-height maturity-period),
      is-redeemed: false
    })
    (try! (ft-mint? tokenized-bond principal-amount issuer))
    (ok new-bond-id)
  )
)

(define-public (redeem-bond (bond-id uint))
  (let ((redeemer tx-sender)
        (bond (unwrap! (map-get? bonds bond-id) (err ERR_INVALID_BOND_ID))))
    (asserts! (is-eq redeemer (get issuer bond)) (err ERR_NOT_OWNER))
    (asserts! (>= block-height (get maturity-height bond)) (err ERR_BOND_NOT_MATURE))
    (asserts! (not (get is-redeemed bond)) (err ERR_ALREADY_REDEEMED))

    (let ((principal-amount (get principal-amount bond))
          (coupon-rate (get coupon-rate bond))
          (interest (/ (* principal-amount coupon-rate) u10000)))
      (try! (ft-burn? tokenized-bond principal-amount redeemer))
      ;; This assumes the contract holds funds to pay interest.
      ;; A real implementation would need a treasury to pay from.
      (try! (as-contract (stx-transfer? interest tx-sender redeemer)))
      (map-set bonds bond-id (merge bond {is-redeemed: true}))
      (ok interest)
    )
  )
)


;; --- SIP-010 Trait Implementation ---

(define-read-only (get-total-supply)
  (ok (ft-get-supply tokenized-bond))
)

(define-read-only (get-name)
  (ok "TokenizedBond")
)

(define-read-only (get-symbol)
  (ok "TBOND")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance tokenized-bond who))
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq from tx-sender) (err ERR_UNAUTHORIZED))
    (try! (ft-transfer? tokenized-bond amount from to))
    (ok true)
  )
)

(define-read-only (get-token-uri)
    (ok (some u"https://autovault.finance/token/tokenized-bond"))
)
