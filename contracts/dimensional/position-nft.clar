;; position-nft.clar
;; Conxian Protocol Standard Contract

;; position-nft.clar
;; Dimensional Risk Token (DRT) - Represents a multi-dimensional position in Conxian
;; Implements SIP-009

(impl-trait .sip-standards.sip-009-nft-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NOT_OWNER u1001)

(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var authorized-minter principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-non-fungible-token dimensional-risk-token uint)

;; --- SIP-009 Functions ---

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none) ;; metadata-base-uri + token-id
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? dimensional-risk-token token-id))
)


;; @desc Transfer
;; @returns (response bool uint)
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err ERR_NOT_OWNER))
        (nft-transfer? dimensional-risk-token token-id sender recipient)
    )
)

;; --- Internal Functions ---


;; @desc Mint
;; @returns (response bool uint)
(define-public (mint (recipient principal) (token-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get authorized-minter)) (err ERR_UNAUTHORIZED))
        (try! (nft-mint? dimensional-risk-token token-id recipient))
        (if (> token-id (var-get last-token-id))
            (var-set last-token-id token-id)
            true
        )
        (ok token-id)
    )
)


;; @desc Burn
;; @returns (response bool uint)
(define-public (burn (token-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get authorized-minter)) (err ERR_UNAUTHORIZED))
        (nft-burn? dimensional-risk-token token-id (unwrap! (nft-get-owner? dimensional-risk-token token-id) (err ERR_NOT_OWNER)))
    )
)

;; --- Admin Functions ---


;; @desc Set minter
;; @returns (response bool uint)
(define-public (set-minter (new-minter principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
        (var-set authorized-minter new-minter)
        (ok true)
    )
)
