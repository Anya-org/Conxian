;; lending-manager.clar
;; Production lending module for the Conxian protocol
;; clarity-version: 4

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_ASSET_NOT_FOUND (err u404))

;; --- State ---
(define-data-var admin principal tx-sender)

(define-map reserves
  principal
  {
    total-deposits: uint,
    total-borrows: uint,
    decimals: uint,
    active: bool
  }
)

;; --- Read-Only Functions ---

;; @desc Get total deposits for a specific asset
(define-read-only (get-total-deposits (asset principal))
  (let ((reserve (unwrap! (map-get? reserves asset) ERR_ASSET_NOT_FOUND)))
    (ok (get total-deposits reserve))
  )
)

;; @desc Get total borrows for a specific asset
(define-read-only (get-total-borrows (asset principal))
  (let ((reserve (unwrap! (map-get? reserves asset) ERR_ASSET_NOT_FOUND)))
    (ok (get total-borrows reserve))
  )
)

;; @desc Get full reserve data
(define-read-only (get-reserve-data (asset principal))
  (map-get? reserves asset)
)

;; --- Admin / Operation Functions ---

;; @desc Initialize a new reserve asset
(define-public (add-reserve (asset principal) (decimals uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set reserves asset {
      total-deposits: u0,
      total-borrows: u0,
      decimals: decimals,
      active: true
    })
    (ok true)
  )
)

;; @desc Update admin principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-standard? new-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
