;; conclave-sbt.clar
;; Sovereign Autonomous Token: Conclave Soulbound Identity (SBT)
;; Represents "Conclave Pro" membership and protocol-wide fee reduction eligibility.
;; NON-TRANSFERABLE (Soulbound)

(impl-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u4000)
(define-constant ERR_SOULBOUND u4001)
(define-constant ERR_NOT_FOUND u4002)
(define-constant ERR_ALREADY_MINTED u4003)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.conxian.com/sbt/conclave/")

;; Maps
(define-map token-owners uint principal)
(define-map user-tokens principal uint)

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; SIP-009 Implementation
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (map-get? token-owners token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (err ERR_SOULBOUND)
)

;; Conclave Logic
(define-public (mint (recipient principal))
  (let (
    (token-id (+ (var-get last-token-id) u1))
  )
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? user-tokens recipient)) (err ERR_ALREADY_MINTED))
    
    (map-set token-owners token-id recipient)
    (map-set user-tokens recipient token-id)
    (var-set last-token-id token-id)
    
    (print { event: "sbt-minted", recipient: recipient, token-id: token-id })
    (ok token-id)
  )
)

(define-public (burn (token-id uint))
  (let (
    (owner (unwrap! (map-get? token-owners token-id) (err ERR_NOT_FOUND)))
  )
    (asserts! (or (is-owner) (is-eq tx-sender owner)) (err ERR_UNAUTHORIZED))
    
    (map-delete token-owners token-id)
    (map-delete user-tokens owner)
    
    (print { event: "sbt-burned", owner: owner, token-id: token-id })
    (ok true)
  )
)

(define-read-only (has-sbt (user principal))
  (is-some (map-get? user-tokens user))
)

(define-read-only (get-token-id (user principal))
  (map-get? user-tokens user)
)

;; Admin
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set base-uri new-uri)
    (ok true)
  )
)
