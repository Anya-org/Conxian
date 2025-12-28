;; conxian-access.clar
;; Manages the "Velvet Rope" access model for the Conxian Protocol.
;; Handles Genesis claims and the viral invite system.

;; --- Traits ---
(use-trait sip-018-signed-messages .traits.sip-018-signed-messages-trait)

;; --- Constants ---
(define-constant ERR_GENESIS_CAP_REACHED (err u1001))
(define-constant ERR_ALREADY_A_MEMBER (err u1002))
(define-constant ERR_INVALID_SIGNATURE (err u1003))
(define-constant ERR_ISSUER_NOT_GOLD (err u1004))
(define-constant ERR_NONCE_REPLAY (err u1005))

(define-constant GENESIS_CAP u1000)
(define-constant TIER_NONE u0)
(define-constant TIER_SILVER u1)
(define-constant TIER_GOLD u2)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-members uint u0)
(define-map member-badges principal uint)
(define-map used-nonces (buff 32) bool)
(define-map authorized-callers principal bool)

;; --- Public Read-Only ---

;; @desc Get the tier of a given user
(define-read-only (get-user-tier (user principal))
  (default-to TIER_NONE (map-get? member-badges user))
)

;; --- Public Functions ---

;; @desc Claim one of the 1,000 Genesis spots
(define-public (claim-genesis-spot)
  (begin
    (asserts! (< (var-get total-members) GENESIS_CAP) ERR_GENESIS_CAP_REACHED)
    (asserts! (is-none (map-get? member-badges tx-sender)) ERR_ALREADY_A_MEMBER)

    (map-set member-badges tx-sender TIER_SILVER)
    (var-set total-members (+ (var-get total-members) u1))

    (print {
      event: "genesis-claimed",
      user: tx-sender,
    })
    (ok true)
  )
)

;; @desc Claim an invite using an off-chain signature
(define-public (claim-invite (signature (buff 65)) (issuer principal) (nonce uint) (issuer-tier uint))
  (begin
    (asserts! (is-none (map-get? member-badges tx-sender)) ERR_ALREADY_A_MEMBER)
    (asserts! (is-eq issuer-tier TIER_GOLD) ERR_ISSUER_NOT_GOLD)

    ;; Verify Signature
    (let ((hash (sha256 (merge (to-le-uint nonce) (merge (to-le-uint issuer-tier) (principal-to-buff tx-sender))))))
      (asserts! (is-none (map-get? used-nonces hash)) ERR_NONCE_REPLAY)
      (unwrap! (match (contract-call? .sip-018-signed-messages get-signer hash signature)
        (signer-pubkey
          (if (is-eq (principal-of signer-pubkey) issuer)
            (ok (map-set used-nonces hash true))
            (err ERR_INVALID_SIGNATURE)
          )
        )
        (err-val (err err-val))
      ) ERR_INVALID_SIGNATURE)
    )

    (map-set member-badges tx-sender TIER_SILVER)
    (var-set total-members (+ (var-get total-members) u1))
    (print {
      event: "invite-claimed",
      user: tx-sender,
      issuer: issuer,
    })
    (ok true)
  )
)

;; --- Admin Functions ---

(define-public (set-user-tier (user principal) (tier uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-some (map-get? authorized-callers tx-sender))) (err u999))
    (map-set member-badges user tier)
    (ok true)
  )
)

(define-public (add-authorized-caller (caller principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u998))
    (map-set authorized-callers caller true)
    (ok true)
  )
)

;; --- Internal ---
