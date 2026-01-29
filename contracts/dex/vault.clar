;; vault.clar
;; Conxian Protocol: Vault system for secure asset storage and management

;; Dependencies
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_VAULT_NOT_FOUND u40001)
(define-constant ERR_VAULT_ALREADY_EXISTS u40002)
(define-constant ERR_INSUFFICIENT_BALANCE u40003)
(define-constant ERR_VAULT_NOT_ACTIVE u40004)
(define-constant ERR_INVALID_AMOUNT u40005)
(define-constant ERR_UNAUTHORIZED_ACCESS u40006)

;; Vault parameters
(define-constant MIN_DEPOSIT u1000000) ;; 1 STX equivalent
(define-constant MAX_VAULTS_PER_USER u10)
(define-constant VAULT_CREATION_FEE u100000) ;; 0.1 STX equivalent
(define-constant MAX_WITHDRAWAL_PERCENT u10000) ;; 100% max withdrawal
(define-constant COOLDOWN_PERIOD u100) ;; 100 blocks cooldown

;; Data variables
(define-data-var vault-system-active bool true)
(define-data-var total-vaults uint u0)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)
(define-data-var circuit-breaker (optional principal) none)

;; Storage maps
(define-map vaults { vault-id: (buff 32) } { 
  owner: principal,
  vault-type: (string-ascii 32),
  tokens: (list 10 principal),
  created-at: uint,
  last-updated: uint,
  active: bool,
  metadata: (string-ascii 256),
  cooldown-end: uint
})

(define-map vault-balances { vault-id: (buff 32), token: principal } uint)

(define-map user-vaults { user: principal } { 
  vault-ids: (list 10 (buff 32)),
  total-vaults: uint,
  active-vaults: uint,
  last-activity: uint
})

;; Helpers

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb (if (contract-call? .circuit-breaker is-contract-paused (as-contract tx-sender))
         (err ERR_VAULT_NOT_ACTIVE)
         (ok true))
    (ok true)
  )
)

;; Read-only functions

;; @desc Get details of a vault
(define-read-only (get-vault (vault-id (buff 32)))
  (map-get? vaults { vault-id: vault-id }))

;; @desc Get the owner of a vault
(define-read-only (get-vault-owner (vault-id (buff 32)))
  (match (map-get? vaults { vault-id: vault-id })
    vault (ok (get owner vault))
    (err ERR_VAULT_NOT_FOUND)
  )
)

;; @desc Get the balance of a specific token in a vault
(define-read-only (get-vault-balance (vault-id (buff 32)) (token principal))
  (ok (default-to u0 (map-get? vault-balances { vault-id: vault-id, token: token })))
)

;; @desc Check if a vault is active
(define-read-only (is-vault-active (vault-id (buff 32)))
  (match (map-get? vaults { vault-id: vault-id })
    vault (ok (get active vault))
    (ok false)
  )
)

;; @desc Get vaults for a specific user
(define-read-only (get-user-vaults (user principal))
  (map-get? user-vaults { user: user }))

;; @desc Check if the vault system is active
(define-read-only (is-vault-system-active)
  (var-get vault-system-active))

;; Public functions

;; @desc Create a new vault
(define-public (create-vault (vault-type (string-ascii 32)) (tokens (list 10 principal)) (metadata (string-ascii 256)))
  (begin
    (asserts! (var-get vault-system-active) (err ERR_VAULT_NOT_ACTIVE))
    
    (let ((vault-id (hash160 (sha256 0x00))))
      (asserts! (is-none (map-get? vaults { vault-id: vault-id })) (err ERR_VAULT_ALREADY_EXISTS))
      
      (map-set vaults { vault-id: vault-id } {
        owner: tx-sender,
        vault-type: vault-type,
        tokens: tokens,
        created-at: burn-block-height,
        last-updated: burn-block-height,
        active: true,
        metadata: metadata,
        cooldown-end: u0
      })
      
      (var-set total-vaults (+ (var-get total-vaults) u1))
      (print { event: "vault-created", vault-id: vault-id, owner: tx-sender, vault-type: vault-type })
      (ok vault-id)
    )
  )
)

;; @desc Deposit tokens to a vault
(define-public (deposit-to-vault (vault-id (buff 32)) (token-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (token (contract-of token-trait))
    (vault-info (unwrap! (get-vault vault-id) (err ERR_VAULT_NOT_FOUND)))
  )
    (try! (check-circuit-breaker))
    (asserts! (var-get vault-system-active) (err ERR_VAULT_NOT_ACTIVE))
    (asserts! (get active vault-info) (err ERR_VAULT_NOT_ACTIVE))
    (asserts! (is-eq tx-sender (get owner vault-info)) (err ERR_UNAUTHORIZED_ACCESS))
    (asserts! (>= amount MIN_DEPOSIT) (err ERR_INVALID_AMOUNT))

    (try! (contract-call? token-trait transfer amount tx-sender (as-contract tx-sender) none))
    
    (let ((current-balance (default-to u0 (map-get? vault-balances { vault-id: vault-id, token: token }))))
      (map-set vault-balances { vault-id: vault-id, token: token } (+ current-balance amount))
      (var-set total-deposits (+ (var-get total-deposits) u1))
      (print { event: "vault-deposited", vault-id: vault-id, token: token, amount: amount })
      (ok true)
    )
  )
)

;; @desc Withdraw tokens from a vault
(define-public (withdraw-from-vault (vault-id (buff 32)) (token-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (token (contract-of token-trait))
    (vault-info (unwrap! (get-vault vault-id) (err ERR_VAULT_NOT_FOUND)))
    (current-balance (default-to u0 (map-get? vault-balances { vault-id: vault-id, token: token })))
  )
    (try! (check-circuit-breaker))
    (asserts! (var-get vault-system-active) (err ERR_VAULT_NOT_ACTIVE))
    (asserts! (get active vault-info) (err ERR_VAULT_NOT_ACTIVE))
    (asserts! (is-eq tx-sender (get owner vault-info)) (err ERR_UNAUTHORIZED_ACCESS))
    (asserts! (>= current-balance amount) (err ERR_INSUFFICIENT_BALANCE))

    (try! (as-contract (contract-call? token-trait transfer amount (as-contract tx-sender) (get owner vault-info) none)))
    
    (map-set vault-balances { vault-id: vault-id, token: token } (- current-balance amount))
    (var-set total-withdrawals (+ (var-get total-withdrawals) u1))
    (print { event: "vault-withdrawn", vault-id: vault-id, token: token, amount: amount })
    (ok true)
  )
)

(define-public (set-circuit-breaker (new-cb principal))
  (begin
    (asserts! (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED_ACCESS))
    (var-set circuit-breaker (some new-cb))
    (ok true)
  )
)

;; @desc Admin function to set system status
(define-public (set-vault-system-active (active bool))
  (begin
    (asserts! (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED_ACCESS))
    (var-set vault-system-active active)
    (ok true)
  )
)

;; Utility functions

(define-read-only (get-vault-system-status)
  {
    active: (var-get vault-system-active),
    total-vaults: (var-get total-vaults),
    total-deposits: (var-get total-deposits),
    total-withdrawals: (var-get total-withdrawals)
  }
)
