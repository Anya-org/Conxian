;; enhanced-caller.clar
;; Enhanced caller contract for multi-contract operations with security validations

;; Traits
(use-trait sip010-token .sip-010-trait.sip-010-trait)
(use-trait vault-trait .vault-trait.vault-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_OPERATION u101)
(define-constant ERR_TRANSFER_FAILED u102)
(define-constant ERR_OPERATION_FAILED u103)
(define-constant ERR_COOLDOWN_ACTIVE u104)
(define-constant ERR_INVALID_PARAMETER u105)

;; State variables
(define-data-var admin principal tx-sender)
(define-data-var dao principal .dao-governance)
(define-data-var paused bool false)

;; Whitelisted contracts for enhanced operations
(define-map authorized-contracts principal bool)

;; Operation tracking
(define-map operations 
  { operation-id: (string-ascii 32) } 
  { 
    last-executed: uint,
    cooldown-blocks: uint,
    enabled: bool
  }
)

;; Initialize common operations
(map-set operations { operation-id: "deposit-and-stake" } { last-executed: u0, cooldown-blocks: u0, enabled: true })
(map-set operations { operation-id: "withdraw-and-claim" } { last-executed: u0, cooldown-blocks: u0, enabled: true })
(map-set operations { operation-id: "cross-vault-transfer" } { last-executed: u0, cooldown-blocks: u0, enabled: true })

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-dao (new-dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set dao new-dao)
    (ok true)
  )
)

(define-public (pause (new-state bool))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (var-get dao))) (err ERR_UNAUTHORIZED))
    (var-set paused new-state)
    (ok true)
  )
)

(define-public (authorize-contract (target principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set authorized-contracts target authorized)
    (ok true)
  )
)

(define-public (configure-operation (operation-id (string-ascii 32)) (cooldown-blocks uint) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set operations 
      { operation-id: operation-id } 
      { 
        last-executed: (default-to u0 (get last-executed (map-get? operations { operation-id: operation-id }))),
        cooldown-blocks: cooldown-blocks,
        enabled: enabled
      }
    )
    (ok true)
  )
)

;; Core enhanced operations
(define-public (deposit-and-stake (token-contract <sip010-token>) (vault-contract <vault-trait>) (amount uint))
  (begin
    ;; Check authorization
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "deposit-and-stake"))
    
  ;; Execute deposit (vault-trait: (deposit (principal uint)))
  (try! (contract-call? vault-contract deposit tx-sender amount))
    
    ;; Update operation state
    (map-set operations 
      { operation-id: "deposit-and-stake" }
      (merge (unwrap-panic (map-get? operations { operation-id: "deposit-and-stake" }))
        { last-executed: block-height }
      )
    )
    
    (ok amount)
  )
)

(define-public (withdraw-and-claim (vault-contract <vault-trait>) (amount uint))
  (begin
    ;; Check authorization
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "withdraw-and-claim"))
    
  ;; Execute withdrawal (vault-trait: (withdraw (principal uint)))
  (try! (contract-call? vault-contract withdraw tx-sender amount))
    
    ;; Update operation state
    (map-set operations 
      { operation-id: "withdraw-and-claim" }
      (merge (unwrap-panic (map-get? operations { operation-id: "withdraw-and-claim" }))
        { last-executed: block-height }
      )
    )
    
    (ok amount)
  )
)

(define-public (cross-vault-transfer (source-vault <vault-trait>) (destination-vault <vault-trait>) (amount uint))
  (begin
    ;; Check authorization
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "cross-vault-transfer"))
  (asserts! (is-contract-authorized (contract-of source-vault)) (err ERR_UNAUTHORIZED))
  (asserts! (is-contract-authorized (contract-of destination-vault)) (err ERR_UNAUTHORIZED))
    
  ;; Execute withdrawal from source vault
  (try! (contract-call? source-vault withdraw tx-sender amount))
    
  ;; Execute deposit into destination vault
  (try! (contract-call? destination-vault deposit tx-sender amount))
    
    ;; Update operation state
    (map-set operations 
      { operation-id: "cross-vault-transfer" }
      (merge (unwrap-panic (map-get? operations { operation-id: "cross-vault-transfer" }))
        { last-executed: block-height }
      )
    )
    
    (ok amount)
  )
)

;; Overloads for concrete vault implementations via dedicated trait
(use-trait vault-prod .vault-production-trait.vault-production-trait)

(define-public (deposit-and-stake-prod (token-principal principal) (vault <vault-prod>) (amount uint))
  (begin
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "deposit-and-stake"))
  ;; Vault is responsible for pulling funds via transfer-from
  (try! (contract-call? vault deposit amount token-principal))
    (map-set operations { operation-id: "deposit-and-stake" }
      (merge (unwrap-panic (map-get? operations { operation-id: "deposit-and-stake" })) { last-executed: block-height }))
    (ok amount)))

(define-public (withdraw-and-claim-prod (vault <vault-prod>) (amount uint) (token-principal principal))
  (begin
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "withdraw-and-claim"))
  (try! (contract-call? vault withdraw amount token-principal))
    (map-set operations { operation-id: "withdraw-and-claim" }
      (merge (unwrap-panic (map-get? operations { operation-id: "withdraw-and-claim" })) { last-executed: block-height }))
    (ok amount)))

(define-public (cross-vault-transfer-prod (source-vault <vault-prod>) (destination-vault <vault-prod>) (amount uint) (token-principal principal))
  (begin
    (asserts! (not (var-get paused)) (err ERR_UNAUTHORIZED))
  (try! (validate-operation "cross-vault-transfer"))
  (asserts! (is-contract-authorized (contract-of source-vault)) (err ERR_UNAUTHORIZED))
  (asserts! (is-contract-authorized (contract-of destination-vault)) (err ERR_UNAUTHORIZED))
  (try! (contract-call? source-vault withdraw amount token-principal))
  (try! (contract-call? destination-vault deposit amount token-principal))
    (map-set operations { operation-id: "cross-vault-transfer" }
      (merge (unwrap-panic (map-get? operations { operation-id: "cross-vault-transfer" })) { last-executed: block-height }))
    (ok amount)))


;; Helper functions
(define-private (validate-operation (operation-id (string-ascii 32)))
  (let ((op (default-to 
              { last-executed: u0, cooldown-blocks: u0, enabled: false } 
              (map-get? operations { operation-id: operation-id }))))
    ;; Check if operation is enabled
    (asserts! (get enabled op) (err ERR_INVALID_OPERATION))
    
    ;; Check cooldown
    (if (> (get cooldown-blocks op) u0)
      (asserts! (>= block-height (+ (get last-executed op) (get cooldown-blocks op))) (err ERR_COOLDOWN_ACTIVE))
      true
    )
    (ok true)
  )
)

(define-read-only (is-contract-authorized (target principal))
  (default-to false (map-get? authorized-contracts target))
)

(define-read-only (get-operation-status (operation-id (string-ascii 32)))
  (let ((op (map-get? operations { operation-id: operation-id })))
    (match op
      operation {
        operation-id: operation-id,
        status: (get enabled operation),
        last-executed: (get last-executed operation),
        cooldown-blocks: (get cooldown-blocks operation),
        can-execute: (or 
                       (is-eq (get cooldown-blocks operation) u0) 
                       (>= block-height (+ (get last-executed operation) (get cooldown-blocks operation)))
                     )
      }
      { 
        operation-id: operation-id,
        status: false,
        last-executed: u0,
        cooldown-blocks: u0,
        can-execute: false
      }
    )
  )
)
