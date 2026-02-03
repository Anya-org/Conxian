;; cxd-token.clar
;; CXD Governance Token - SIP-010 FT Implementation
;;
;; REPAIRED: Added max supply cap and events

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)
(define-constant ERR_MAX_SUPPLY_REACHED u1002)


(define-map authorized-minters principal bool)
(define-public (add-minter (minter principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (default-to false (map-get? authorized-minters contract-caller))) (err ERR_UNAUTHORIZED))
    (map-set authorized-minters minter true)
    (ok true)
  )
)

;; Data Vars
(define-data-var total-supply uint u0) ;; Start at 0, track actual minted
(define-data-var contract-owner principal tx-sender)
(define-data-var max-supply uint u100000000000000000) ;; 1 billion with 8 decimals (1B * 10^8)

;; Events
(define-private (emit-mint (recipient principal) (amount uint))
  (print {
    event: "cxd-mint",
    recipient: recipient,
    amount: amount,
    new-total: (var-get total-supply),
    timestamp: burn-block-height
  })
)

(define-private (emit-burn (owner principal) (amount uint))
  (print {
    event: "cxd-burn",
    owner: owner,
    amount: amount,
    new-total: (var-get total-supply),
    timestamp: burn-block-height
  })
)

;;
(define-fungible-token cxd-token)

;; SIP-010 FT Implementation
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (>= (ft-get-balance cxd-token sender) amount) (err ERR_INSUFFICIENT_BALANCE))
    (try! (ft-transfer? cxd-token amount sender recipient))
    (ok true)
  )
)

;; Burn function
(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (try! (ft-burn? cxd-token amount owner))
    (var-set total-supply (- (var-get total-supply) amount))
    (emit-burn owner amount)
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "Conxian Governance Token")
)

(define-read-only (get-symbol)
  (ok "CXD")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance cxd-token owner))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (some u"https://conxian.io/metadata/cxd"))
)

(define-read-only (get-max-supply)
  (ok (var-get max-supply))
)

(define-read-only (get-remaining-mintable)
  (ok (- (var-get max-supply) (var-get total-supply)))
)

;; Mint function for initial distribution
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (default-to false (map-get? authorized-minters contract-caller))) (err ERR_UNAUTHORIZED))
    ;; Check max supply
    (asserts! (<= (+ (var-get total-supply) amount) (var-get max-supply)) (err ERR_MAX_SUPPLY_REACHED))
    (try! (ft-mint? cxd-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (emit-mint recipient amount)
    (ok true)
  )
)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (default-to false (map-get? authorized-minters contract-caller))) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
