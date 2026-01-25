;; lending-manager.clar
;; Manages the core logic of the lending protocol

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-map deposits
  { asset: principal, user: principal }
  uint
)

(define-map borrows
  { asset: principal, user: principal }
  uint
)

;; @desc Deposits an asset into the lending pool
;; @param asset The asset to deposit
;; @param amount The amount to deposit
(define-public (deposit (asset <sip-010-trait>) (amount uint))
  (begin
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    (map-set deposits { asset: (contract-of asset), user: tx-sender } (+ (default-to u0 (map-get? deposits { asset: (contract-of asset), user: tx-sender })) amount))
    (ok true)
  )
)

;; @desc Withdraws an asset from the lending pool
;; @param asset The asset to withdraw
;; @param amount The amount to withdraw
(define-public (withdraw (asset <sip-010-trait>) (amount uint))
  (begin
    (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
    (map-set deposits { asset: (contract-of asset), user: tx-sender } (- (default-to u0 (map-get? deposits { asset: (contract-of asset), user: tx-sender })) amount))
    (ok true)
  )
)

;; @desc Borrows an asset from the lending pool
;; @param asset The asset to borrow
;; @param amount The amount to borrow
(define-public (borrow (asset <sip-010-trait>) (amount uint))
  (begin
    (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) tx-sender none)))
    (map-set borrows { asset: (contract-of asset), user: tx-sender } (+ (default-to u0 (map-get? borrows { asset: (contract-of asset), user: tx-sender })) amount))
    (ok true)
  )
)

;; @desc Repays a borrowed asset
;; @param asset The asset to repay
;; @param amount The amount to repay
(define-public (repay (asset <sip-010-trait>) (amount uint))
  (begin
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    (map-set borrows { asset: (contract-of asset), user: tx-sender } (- (default-to u0 (map-get? borrows { asset: (contract-of asset), user: tx-sender })) amount))
    (ok true)
  )
)