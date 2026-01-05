;; dex-facade.clar
;; Conxian Enterprise Standard: DEX Facade
;; Thin routing layer for decentralized exchange operations
;; Delegates all business logic to backend contracts

;; Trait imports
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait oracle-trait .oracle.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u9200))
(define-constant ERR_BACKEND_NOT_FOUND (err u9201))
(define-constant ERR_INVALID_OPERATION (err u9202))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9203))

;; Data Vars
(define-data-var facade-admin principal tx-sender)
(define-data-var dex-backend principal tx-sender)
(define-data-var is-paused bool false)

;; Access control
(define-map authorized-callers principal bool)

;; Fee configuration
(define-data-var swap-fee-basis-points uint u30) ;; 0.3%
(define-data-var protocol-fee-share uint u5000) ;; 50% to protocol

;; Public functions - thin delegation to backend
(define-public (swap-tokens 
  (token-a principal) 
  (token-b principal) 
  (amount-in uint) 
  (min-amount-out uint)
)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> amount-in u0) ERR_INVALID_OPERATION)
    
    (match (var-get dex-backend)
      backend 
      (contract-call? backend swap-tokens token-a token-b amount-in min-amount-out)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (add-liquidity 
  (token-a principal) 
  (token-b principal) 
  (amount-a uint) 
  (amount-b uint) 
  (min-liquidity uint)
)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    (match (var-get dex-backend)
      backend 
      (contract-call? backend add-liquidity token-a token-b amount-a amount-b min-liquidity)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (remove-liquidity 
  (token-a principal) 
  (token-b principal) 
  (liquidity-amount uint) 
  (min-amount-a uint) 
  (min-amount-b uint)
)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    (match (var-get dex-backend)
      backend 
      (contract-call? backend remove-liquidity token-a token-b liquidity-amount min-amount-a min-amount-b)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (get-pool-info (token-a principal) (token-b principal))
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    
    (match (var-get dex-backend)
      backend 
      (contract-call? backend get-pool-info token-a token-b)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (get-swap-quote 
  (token-a principal) 
  (token-b principal) 
  (amount-in uint)
)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    
    (match (var-get dex-backend)
      backend 
      (contract-call? backend get-swap-quote token-a token-b amount-in)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

;; Admin functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set is-paused true)
    (ok true)
  )
)

(define-public (emergency-unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set is-paused false)
    (ok true)
  )
)

(define-public (set-facade-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set facade-admin new-admin)
    (ok true)
  )
)

(define-public (set-dex-backend (new-backend principal))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set dex-backend new-backend)
    (ok true)
  )
)

(define-public (set-swap-fee (fee-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= fee-basis-points u1000) ERR_INVALID_OPERATION) ;; Max 10%
    (var-set swap-fee-basis-points fee-basis-points)
    (ok true)
  )
)

(define-public (authorize-caller (caller principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (map-set authorized-callers caller authorized)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-authorized (caller principal))
  (ok (or 
    (is-eq caller (var-get facade-admin))
    (default-to false (map-get? authorized-callers caller))
  ))
)

(define-read-only (get-facade-info)
  (ok {
    admin: (var-get facade-admin),
    backend: (var-get dex-backend),
    is-paused: (var-get is-paused),
    swap-fee: (var-get swap-fee-basis-points),
    protocol-share: (var-get protocol-fee-share)
  })
)
