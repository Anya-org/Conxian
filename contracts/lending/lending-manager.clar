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

;; --- Public Functions ---

;; @desc Register a new asset reserve. Admin only.
(define-public (register-reserve (asset principal) (decimals uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set reserves asset { total-deposits: u0, total-borrows: u0, decimals: decimals, active: true })
    (ok true)
  )
)

;; @desc Set reserve status (active/inactive). Admin only.
(define-public (set-reserve-active (asset principal) (active bool))
  (let ((reserve (unwrap! (map-get? reserves asset) ERR_ASSET_NOT_FOUND)))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (map-set reserves asset (merge reserve { active: active }))
      (ok true)
    )
  )
)
