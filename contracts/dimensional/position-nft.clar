;; position-nft.clar
;; Conxian SAB: Dimensional Position NFT
;; NFT representation of dimensional trading positions

(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u30012))
(define-constant ERR_POSITION_NOT_FOUND (err u30013))

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var nft-counter uint u0)

;; Position NFT storage
(define-map position-nfts
  uint
  {
    owner: principal,
    position-id: uint,
    asset: (string-ascii 32),
    size: uint,
    leverage: uint,
    created-at: uint,
    metadata: (string-ascii 128)
  }
)

(define-map position-ownership
  principal
  (list 100 uint)
)

;; Public functions
(define-public (mint-position-nft 
  (position-id uint) 
  (asset (string-ascii 32)) 
  (size uint) 
  (leverage uint) 
  (metadata (string-ascii 128))
)
  (begin
    (let ((nft-id (+ (var-get nft-counter) u1)))
      (map-set position-nfts nft-id {
        owner: tx-sender,
        position-id: position-id,
        asset: asset,
        size: size,
        leverage: leverage,
        created-at: block-height,
        metadata: metadata
      })
      (map-set position-ownership tx-sender (default-to (list) (map-get? position-ownership tx-sender))))
      (map-set position-ownership tx-sender (append (unwrap! (map-get? position-ownership tx-sender) (list)) nft-id))
      (var-set nft-counter nft-id)
      (ok nft-id)
    )
  )

(define-public (burn-position-nft (nft-id uint))
  (begin
    (match (map-get? position-nfts nft-id)
      nft
      (begin
        (asserts! (is-eq (get owner nft) tx-sender) ERR_UNAUTHORIZED)
        (map-delete position-nfts nft-id)
        ;; Update ownership list
        (let ((current-list (unwrap! (map-get? position-ownership tx-sender) (list))))
          (map-set position-ownership tx-sender (filter (lambda (x) (not (is-eq x nft-id))) current-list))
        )
        (ok true)
      )
      (err ERR_POSITION_NOT_FOUND)
    )
  )
)

;; Read-only functions
(define-read-only (get-position-nft (nft-id uint))
  (match (map-get? position-nfts nft-id)
    nft (ok nft)
    (err ERR_POSITION_NOT_FOUND)
  )
)

(define-read-only (get-user-nfts (user principal))
  (match (map-get? position-ownership user)
    nfts (ok nfts)
    (ok (list))
  )
)

(define-read-only (get-nft-owner (nft-id uint))
  (match (map-get? position-nfts nft-id)
    nft (ok (get owner nft))
    (err ERR_POSITION_NOT_FOUND)
  )
)

;; SIP-009 trait implementation
(define-read-only (get-token-uri (nft-id uint))
  (match (map-get? position-nfts nft-id)
    nft (ok (some (get metadata nft)))
    (ok none)
  )
)