;; conxian-gatekeeper.clar
;; Handles the KYC-based upgrade from Silver to Gold tier.

;; --- Traits ---
(use-trait access-control .access-control-trait.access-control-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_INVALID_SIGNATURE (err u2002))
(define-constant ERR_USER_NOT_SILVER (err u2003))
(define-constant ERR_NONCE_REPLAY (err u2004))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var oracle-principal principal tx-sender)
(define-data-var conxian-access-contract principal .conxian-access)
(define-map used-oracle-nonces uint bool)

;; --- Public Functions ---

;; @desc Upgrade a user to Gold Tier via Oracle signature
(define-public (upgrade-to-gold (signature (buff 65)) (nonce uint))
  (begin
    (let ((access-contract (var-get conxian-access-contract)))
      ;; Check that the user is currently Silver Tier
      (asserts! (is-eq (try! (contract-call? access-contract get-user-tier tx-sender)) u1) ERR_USER_NOT_SILVER)

      ;; Verify the signature is from the oracle
      (let ((hash (sha256 (merge (to-le-uint nonce) (principal-to-buff tx-sender))))
            (recovered-pubkey (unwrap! (secp256k1-recover? hash signature) ERR_INVALID_SIGNATURE)))
        (asserts! (is-none (map-get? used-oracle-nonces nonce)) ERR_NONCE_REPLAY)
        (asserts! (is-eq (principal-of recovered-pubkey) (var-get oracle-principal)) ERR_INVALID_SIGNATURE)
        (map-set used-oracle-nonces nonce true)
      )

      ;; Upgrade the user's tier in the access contract
      (try! (contract-call? access-contract set-user-tier tx-sender u2))
      (print {
        event: "gold-upgrade",
        user: tx-sender,
      })
      (ok true)
    )
  )
)

;; --- Admin Functions ---

(define-public (set-access-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set conxian-access-contract contract)
    (ok true)
  )
)

(define-public (set-oracle-principal (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set oracle-principal new-oracle)
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-private (principal-to-buff (p principal))
  ;; Placeholder for to-consensus-buff?
  (ok 0x00)
)

(define-private (to-le-uint (val uint))
  0x00000000000000000000000000000000
)
