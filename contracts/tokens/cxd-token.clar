;; CXD Token - Conxian Protocol Governance Token
;; SIP-010 Fungible Token implementation

;; Import SIP-010 trait
(impl-trait .sip-standards.sip-010-ft-trait)


;; Token metadata
(define-constant TOKEN_NAME "Conxian Governance Token")
(define-constant TOKEN_SYMBOL "CXD")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI "https://conxian.io/metadata/cxd.json")

;; Token state
(define-data-var total-supply uint u0)
(define-map balances { account: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)

;; Events
(define-event (transfer-mint (sender principal) (recipient principal) (amount uint)))
(define-event (transfer-burn (sender principal) (amount uint)))
(define-event (transfer (sender principal) (recipient principal) (amount uint)))
(define-event (approve (owner principal) (spender principal) (amount uint)))

;; Read-only functions

(define-read-only (get-name)
  TOKEN_NAME)

(define-read-only (get-symbol)
  TOKEN_SYMBOL)

(define-read-only (get-decimals)
  TOKEN_DECIMALS)

(define-read-only (get-token-uri)
  TOKEN_URI)

(define-read-only (get-total-supply)
  (var-get total-supply))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances { account: account })))

(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances { owner: owner, spender: spender })))

(define-read-only (get-token-id)
  (as-contract tx-sender))

;; Public functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 1001))
    (asserts! (>= (get-balance from) amount) (err 1002))
    
    ;; Update balances
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    (map-set balances { account: to } { amount: (+ (get-balance to) amount) })
    
    ;; Emit event
    (emit-event (transfer from to amount))
    
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Only contract owner can mint
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 1003))
    (asserts! (> amount u0) (err 1004))
    
    ;; Update total supply and recipient balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances { account: recipient } { amount: (+ (get-balance recipient) amount) })
    
    ;; Emit event
    (emit-event (transfer-mint tx-sender recipient amount))
    
    (ok true)
  )
)

(define-public (burn (amount uint) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 1005))
    (asserts! (>= (get-balance tx-sender) amount) (err 1006))
    
    ;; Update total supply and sender balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: tx-sender } { amount: (- (get-balance tx-sender) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn tx-sender amount))
    
    (ok true)
  )
)

(define-public (approve (amount uint) (spender principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 1007))
    
    ;; Set allowance
    (map-set allowances { owner: tx-sender, spender: spender } { amount: amount })
    
    ;; Emit event
    (emit-event (approve tx-sender spender amount))
    
    (ok true)
  )
)

(define-public (transfer-from (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 1008))
    (asserts! (>= (get-balance from) amount) (err 1009))
    (asserts! (>= (get-allowance from tx-sender) amount) (err 1010))
    
    ;; Update allowance
    (map-set allowances { owner: from, spender: tx-sender } { 
      amount: (- (get-allowance from tx-sender) amount) 
    })
    
    ;; Update balances
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    (map-set balances { account: to } { amount: (+ (get-balance to) amount) })
    
    ;; Emit event
    (emit-event (transfer from to amount))
    
    (ok true)
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 1011))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (emergency-burn (amount uint) (from principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 1012))
    (asserts! (> amount u0) (err 1013))
    (asserts! (>= (get-balance from) amount) (err 1014))
    
    ;; Update total supply and balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn from amount))
    
    (ok true)
  )
)

;; Governance functions

(define-read-only (is-governance-token)
  true)

(define-read-only (get-voting-power (account principal))
  (get-balance account))

(define-public (delegate (amount uint) (delegatee principal))
  (begin
    (asserts! (> amount u0) (err 1015))
    (asserts! (>= (get-balance tx-sender) amount) (err 1016))
    
    ;; This would integrate with a delegation system
    ;; For now, just emit an event
    (print {event: "delegated", delegator: tx-sender, delegatee: delegatee, amount: amount})
    
    (ok true)
  )
)
