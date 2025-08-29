;; tokenized-bond.clar
;;
;; This contract implements a SIP-010 tokenized bond.
;; It represents a single series of bonds with uniform characteristics.
;;
;; Features:
;; - SIP-010 compliant fungible token for secondary market trading.
;; - Periodic coupon payments that can be claimed by bondholders.
;; - Principal payout at maturity.

(impl-trait .sip-010-trait.sip-010-trait)

(define-constant ERR_UNAUTHORIZED u201)
(define-constant ERR_NOT_YET_MATURED u202)
(define-constant ERR_ALREADY_MATURED u203)
(define-constant ERR_NO_COUPONS_DUE u204)
(define-constant ERR_BOND_NOT_ISSUED u205)
(define-constant ERR_ALREADY_ISSUED u210)

;; --- SIP-010 Data ---
(define-fungible-token tokenized-bond)
(define-data-var token-name (string-ascii 32) "Tokenized Bond")
(define-data-var token-symbol (string-ascii 10) "BOND")
(define-data-var token-decimals uint u8)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; --- Bond Characteristics ---
(define-data-var bond-issued bool false)
(define-data-var issue-block uint u0)
(define-data-var maturity-block uint u0)
(define-data-var coupon-rate uint u0) ;; Scaled by 10000 (e.g., 500 = 5%)
(define-data-var coupon-frequency uint u0) ;; In blocks
(define-data-var face-value uint u0) ;; In the smallest unit of the payment token
(define-data-var payment-token principal 'ST000000000000000000002AMW42H.some-token) ;; placeholder
(define-data-var contract-owner principal tx-sender)

;; Map to track the last coupon period claimed by each user
(define-map last-claimed-coupon {user: principal} {period: uint})

(use-trait payment-token .sip-010-trait.sip-010-trait)

;; --- Contract Setup ---

(define-public (issue-bond
      (name (string-ascii 32))
      (symbol (string-ascii 10))
      (decimals uint)
      (initial-supply uint)
      (maturity-in-blocks uint)
      (coupon-rate-scaled uint)
      (frequency-in-blocks uint)
      (bond-face-value uint)
      (payment-token-address principal)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
        (asserts! (not (var-get bond-issued)) (err ERR_ALREADY_ISSUED))

        (var-set token-name name)
        (var-set token-symbol symbol)
        (var-set token-decimals decimals)
        (var-set issue-block block-height)
        (var-set maturity-block (+ block-height maturity-in-blocks))
        (var-set coupon-rate coupon-rate-scaled)
        (var-set coupon-frequency frequency-in-blocks)
        (var-set face-value bond-face-value)
        (var-set payment-token payment-token-address)

        (try! (ft-mint? tokenized-bond initial-supply (var-get contract-owner)))

        (var-set bond-issued true)
        (ok true)
    )
)

;; --- Coupon and Maturity Functions ---

(define-public (claim-coupons)
  (let (
      (user tx-sender)
      (last-period (default-to u0 (get period (map-get? last-claimed-coupon {user: user}))))
      (current-period (/ (- block-height (var-get issue-block)) (var-get coupon-frequency)))
      (balance (ft-get-balance tokenized-bond user))
      (payment-token-contract (var-get payment-token))
    )
    (asserts! (var-get bond-issued) (err ERR_BOND_NOT_ISSUED))
    (asserts! (< block-height (var-get maturity-block)) (err ERR_ALREADY_MATURED))
    (asserts! (> current-period last-period) (err ERR_NO_COUPONS_DUE))

    (let (
        (periods-to-claim (- current-period last-period))
        (coupon-per-token-per-period
            (/ (* (var-get face-value) (* (var-get coupon-rate) (var-get coupon-frequency))) u525600000)
        )
        (total-coupon-payment (* balance (* periods-to-claim coupon-per-token-per-period)))
      )
      (try! (as-contract (contract-call? 'ST000000000000000000002AMW42H.some-token .transfer total-coupon-payment tx-sender user none)))
      (map-set last-claimed-coupon {user: user} {period: current-period})
      (ok total-coupon-payment)
    )
  )
)

(define-public (redeem-at-maturity)
  (let (
      (user tx-sender)
      (balance (ft-get-balance tokenized-bond user))
      (payment-token-contract (var-get payment-token))
      (maturity (var-get maturity-block))
    )
    (asserts! (var-get bond-issued) (err ERR_BOND_NOT_ISSUED))
    (asserts! (>= block-height maturity) (err ERR_NOT_YET_MATURED))

    (let (
        (last-claim-period (default-to u0 (get period (map-get? last-claimed-coupon {user: user}))))
        (maturity-period (/ (- maturity (var-get issue-block)) (var-get coupon-frequency)))
        (periods-to-claim (if (> maturity-period last-claim-period) (- maturity-period last-claim-period) u0))
        (coupon-per-token-per-period
            (/ (* (var-get face-value) (* (var-get coupon-rate) (var-get coupon-frequency))) u525600000)
        )
        (final-coupon-payment (* balance (* periods-to-claim coupon-per-token-per-period)))
        (principal-payment (* balance (var-get face-value)))
        (total-payment (+ final-coupon-payment principal-payment))
      )
      (asserts! (> balance u0) (err u0))
      (try! (as-contract (contract-call? 'ST000000000000000000002AMW42H.some-token .transfer total-payment tx-sender user none)))
      (try! (ft-burn? tokenized-bond balance user))
      (map-set last-claimed-coupon {user: user} {period: maturity-period})
      (ok {principal: principal-payment, coupon: final-coupon-payment})
    )
  )
)

;; --- SIP-010 Trait Implementation ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq sender tx-sender) (err u4))
        (try! (ft-transfer? tokenized-bond amount sender recipient))
        (ok true)
    )
)

(define-read-only (get-name) (ok (var-get token-name)))
(define-read-only (get-symbol) (ok (var-get token-symbol)))
(define-read-only (get-decimals) (ok (var-get token-decimals)))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance tokenized-bond who)))
(define-read-only (get-total-supply) (ok (ft-get-total-supply tokenized-bond)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))
(define-public (set-token-uri (value (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set token-uri value)
    (ok true)
  )
)
