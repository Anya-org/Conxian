;; vault.clar
;; Conxian Protocol: Vault system for secure asset storage and management

;; Dependencies
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)
(use-trait flash-loan-user-trait .defi-traits.flash-loan-user-trait)
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_VAULT_NOT_FOUND (err 40001))
(define-constant ERR_VAULT_ALREADY_EXISTS (err 40002))
(define-constant ERR_INSUFFICIENT_BALANCE (err 40003))
(define-constant ERR_VAULT_NOT_ACTIVE (err 40004))
(define-constant ERR_INVALID_AMOUNT (err 40005))
(define-constant ERR_UNAUTHORIZED_ACCESS (err 40006))

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

;; Storage maps
(define-map vaults { vault-id: (buff 32) } { 
  owner: principal,
  vault-type: (string-ascii 32),
  tokens: (list 10 principal),
  balances: (list 10 { token: principal, amount: uint }),
  created-at: uint,
  last-updated: uint,
  active: bool,
  metadata: (string-ascii 256),
  cooldown-end: uint
})

(define-map user-vaults { user: principal } { 
  vault-ids: (list 10 (buff 32)),
  total-vaults: uint,
  active-vaults: uint,
  last-activity: uint
})

(define-map vault-permissions { vault-id: (buff 32) } { 
  authorized-users: (list 5 principal),
  permissions: (list 5 { user: principal, level: (string-ascii 16) }),
  last-updated: uint
})

(define-map vault-statistics { vault-type: (string-ascii 32) } { 
  total-vaults: uint,
  total-deposits: uint,
  total-withdrawals: uint,
  average-balance: uint,
  last-activity: uint
})

(define-map vault-history { vault-id: (buff 32), timestamp: uint } { 
  action: (string-ascii 16),
  token: principal,
  amount: uint,
  user: principal,
  details: (string-ascii 256)
})

;; Events
;; (define-event (vault-created (vault-id (buff 32)) (owner principal) (vault-type (string-ascii 32))))
;; (define-event (vault-deposited (vault-id (buff 32)) (token principal) (amount uint)))
;; (define-event (vault-withdrawn (vault-id (buff 32)) (token principal) (amount uint)))
;; (define-event (vault-activated (vault-id (buff 32))))
;; (define-event (vault-deactivated (vault-id (buff 32))))
;; (define-event (permission-granted (vault-id (buff 32)) (user principal) (level (string-ascii 16))))
;; (define-event (permission-revoked (vault-id (buff 32)) (user principal)))
;; (define-event (cooldown-started (vault-id (buff 32)) (duration uint)))

;; Read-only functions

(define-read-only (get-vault (vault-id (buff 32)))
  (map-get? vaults { vault-id: vault_id }))

(define-read-only (get-vault-owner (vault-id (buff 32)))
  (match (get-vault vault_id)
    vault (ok (get vault owner))
    none (ok tx-sender)
  )
)

(define-read-only (get-vault-type (vault-id (buff 32)))
  (match (get-vault vault_id)
    vault (ok (get vault vault-type))
    none (ok "standard")
  )
)

(define-read-only (get-vault-balance (vault-id (buff 32)) (token principal))
  (match (get-vault vault-id)
    vault 
      (let ((balances (get vault balances)))
        (ok (default-to u0 (map-get? balances { token: token })))
      )
    none (ok u0)
  )
)

(define-read-only (get-vault-balances (vault-id (buff 32)))
  (match (get-vault vault_id)
    vault (ok (get vault balances))
    none (ok (list 0 { token: principal, amount: uint }))
  )
)

(define-read-only (is-vault-active (vault-id (buff 32)))
  (match (get-vault vault_id)
    vault (ok (get vault active))
    none (ok false)
  )
)

(define-read-only (get-user-vaults (user principal))
  (map-get? user-vaults { user: user }))

(define-read-only (get-vault-permissions (vault-id (buff 32)))
  (map-get? vault-permissions { vault-id: vault_id }))

(define-read-only (has-vault-permission (vault-id (buff 32)) (user principal) (required-level (string-ascii 16)))
  (begin
    (let ((permissions (get-vault-permissions vault_id)))
      (if (is-some permissions)
          (begin
            (let ((perm (unwrap! permissions)))
              (let ((user-permission (get-user-permission (get perm permissions) user)))
                (if (is-some user-permission)
                    (has-permission-level (unwrap! user-permission) required-level)
                    false
                )
              )
            )
          )
          false
      )
    )
  )
)

(define-read-only (has-permission-level (perm-level (string-ascii 16)) (required-level (string-ascii 16)))
  (is-eq perm-level required-level)
)

(define-read-only (get-user-permission (perms (list 5 { user: principal, level: (string-ascii 16) })) (user principal))
  none
)

(define-read-only (get-vault-statistics (vault-type (string-ascii 32)))
  (map-get? vault-statistics { vault-type: vault_type }))

(define-read-only (is-vault-system-active)
  (var-get vault-system-active))

(define-read-only (get-total-vaults)
  (var-get total-vaults))

(define-read-only (get-total-deposits)
  (var-get total-deposits))

(define-read-only (get-total-withdrawals)
  (var-get total-withdrawals))

;; Public functions

(define-public (create-vault (vault-type (string-ascii 32)) (tokens (list 10 principal)) (metadata (string-ascii 256)))
  (begin
    ;; Validate inputs
    (asserts! (> (len vault_type) u0) ERR_INVALID_AMOUNT)
    (asserts! (> (len tokens) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check user vault limit
    (let ((user_info (get-user-vaults tx-sender)))
      (if (is-some user_info)
          (asserts!
            (< (get total-vaults (unwrap-panic user_info)) MAX_VAULTS_PER_USER)
            ERR_VAULT_ALREADY_EXISTS
          )
          true
      )
    )
    
    ;; Generate vault ID
    (let ((vault-id (hash160 (concat (principal-to-buff? tx-sender) (string-ascii vault_type)))))
      
      ;; Create vault
      (map-set vaults { vault-id: vault-id } {
        owner: tx-sender,
        vault-type: vault_type,
        tokens: tokens,
        balances: (map tokens (lambda ((token principal)) { token: token, amount: u0 })),
        created-at: block-height,
        last-updated: block-height,
        active: true,
        metadata: metadata,
        cooldown-end: u0
      })
      
      ;; Initialize permissions
      (map-set vault-permissions { vault-id: vault-id } {
        authorized-users: (list tx-sender),
        permissions: (list { user: tx-sender, level: "owner" }),
        last-updated: block-height
      })
      
      ;; Update user vaults
      (let ((user_info (map-get? user-vaults { user: tx-sender })))
        (if (is-some user_info)
            (begin
              (let ((user-vaults (unwrap-optional user_info)))
                (map-set user-vaults { user: tx-sender } {
                  vault-ids: (append (get user-vaults vault-ids) vault-id),
                  total-vaults: (+ (get user-vaults total-vaults) u1),
                  active-vaults: (+ (get user-vaults active-vaults) u1),
                  last-activity: block-height
                })
              )
            )
            ;; Create new user vaults record
            (map-set user-vaults { user: tx-sender } {
              vault-ids: (list vault-id),
              total-vaults: u1,
              active-vaults: u1,
              last-activity: block-height
            })
        )
      )
      
      ;; Update vault type statistics
      (let ((type_stats (get-vault-statistics vault_type)))
        (if (is-some type_stats)
            (begin
              (let ((stats (unwrap-optional type_stats)))
                (map-set vault-statistics { vault-type: vault_type } {
                  total-vaults: (+ (get stats total-vaults) u1),
                  total-deposits: (get stats total-deposits),
                  total-withdrawals: (get stats total-withdrawals),
                  average-balance: (get stats average-balance),
                  last-activity: block-height
                })
              )
            )
            ;; Create new statistics record
            (map-set vault-statistics { vault-type: vault_type } {
              total-vaults: u1,
              total-deposits: u0,
              total-withdrawals: u0,
              average-balance: u0,
              last-activity: block-height
            })
        )
      )
      
      ;; Update global counters
      (var-set total-vaults (+ (var-get total-vaults) u1))
      
      ;; Emit event
      (print { event: "vault-created", vault-id: vault-id, owner: tx-sender, vault-type: vault_type })
      
      (ok {
        vault-id: vault-id,
        vault-type: vault_type,
        owner: tx-sender,
        created-at: block-height
      })
    )
  )
)

(define-public (deposit-to-vault (vault-id (buff 32)) (token principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists and is active
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        (asserts! (get vault active) ERR_VAULT_NOT_ACTIVE)
        
        ;; Check permissions
        (asserts! (or (is-eq tx-sender (get vault owner)) (has-vault-permission vault_id tx-sender "deposit")) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Check if token is supported
        (asserts! (is-token-supported (get vault tokens) token) ERR_INVALID_AMOUNT)
        
        ;; Check minimum deposit
        (asserts! (>= amount MIN_DEPOSIT) ERR_INVALID_AMOUNT)
        
        ;; Transfer tokens to vault
        (let ((transfer-result (contract-call? token transfer tx-sender (as-contract tx-sender) amount)))
          (match transfer_result
            success
              (begin
                ;; Update vault balance
                (let ((current-balances (get vault balances))
                      (new-balances (update-token-balance current-balances token amount)))
                  
                  (map-set vaults { vault-id: vault_id } {
                    owner: (get vault owner),
                    vault-type: (get vault vault-type),
                    tokens: (get vault tokens),
                    balances: new-balances,
                    created-at: (get vault created-at),
                    last-updated: block-height,
                    active: (get vault active),
                    metadata: (get vault metadata),
                    cooldown-end: (get vault cooldown-end)
                  })
                  
                  ;; Create history record
                  (map-set vault-history { vault-id: vault_id, timestamp: block-height } {
                    action: "deposit",
                    token: token,
                    amount: amount,
                    user: tx-sender,
                    details: (concat "Deposited " (uint-to-string amount) " tokens")
                  })
                  
                  ;; Update user activity
                  (update-user-activity tx-sender)
                  
                  ;; Update statistics
                  (update-vault-statistics (get vault vault-type) amount u0)
                  
                  ;; Update global counters
                  (var-set total-deposits (+ (var-get total-deposits) u1))
                  
                  ;; Emit event
                  (print { event: "vault-deposited", vault-id: vault_id, token: token, amount: amount })
                  
                  (ok {
                    vault-id: vault_id,
                    token: token,
                    amount: amount,
                    new-balance: (get-token-balance new-balances token)
                  })
                )
              error error
          )
        )
      )
    )
  )
)

(define-public (withdraw-from-vault (vault-id (buff 32)) (token principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists and is active
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        (asserts! (get vault active) ERR_VAULT_NOT_ACTIVE)
        
        ;; Check cooldown
        (let ((cooldown-end (get vault cooldown-end)))
          (if (> cooldown-end u0)
              (asserts! (>= block-height cooldown-end) ERR_VAULT_NOT_ACTIVE)
              true
          )
        )
        
        ;; Check permissions
        (asserts! (or (is-eq tx-sender (get vault owner)) (has-vault-permission vault_id tx-sender "withdraw")) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Check if token is supported
        (asserts! (is-token-supported (get vault tokens) token) ERR_INVALID_AMOUNT)
        
        ;; Check sufficient balance
        (let ((current-balance (get-token-balance (get vault balances) token)))
          (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
          
          ;; Transfer tokens from vault
          (let ((transfer-result (contract-call? token transfer (as-contract tx-sender) tx-sender amount)))
            (match transfer_result
              success
                (begin
                  ;; Update vault balance
                  (let ((current-balances (get vault balances))
                        (new-balances (update-token-balance current-balances token (- amount))))
                    
                    (map-set vaults { vault-id: vault_id } {
                      owner: (get vault owner),
                      vault-type: (get vault vault-type),
                      tokens: (get vault tokens),
                      balances: new-balances,
                      created-at: (get vault created-at),
                      last-updated: block-height,
                      active: (get vault active),
                      metadata: (get vault metadata),
                      cooldown-end: (get vault cooldown-end)
                    })
                    
                    ;; Create history record
                    (map-set vault-history { vault-id: vault_id, timestamp: block-height } {
                      action: "withdraw",
                      token: token,
                      amount: amount,
                      user: tx-sender,
                      details: (concat "Withdrew " (uint-to-string amount) " tokens")
                    })
                    
                    ;; Update user activity
                    (update-user-activity tx-sender)
                    
                    ;; Update statistics
                    (update-vault-statistics (get vault vault-type) u0 amount)
                    
                    ;; Update global counters
                    (var-set total-withdrawals (+ (var-get total-withdrawals) u1))
                    
                    ;; Emit event
                    (print { event: "vault-withdrawn", vault-id: vault_id, token: token, amount: amount })
                    
                    (ok {
                      vault-id: vault_id,
                      token: token,
                      amount: amount,
                      new-balance: (get-token-balance new-balances token)
                    })
                  )
                )
              error error
            )
          )
        )
      )
    )
  )
)

(define-public (grant-vault-permission (vault-id (buff 32)) (user principal) (level (string-ascii 16)))
  (begin
    ;; Validate inputs
    (asserts! (principal? user) ERR_INVALID_AMOUNT)
    (asserts! (> (len level) u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        ;; Only owner can grant permissions
        (asserts! (is-eq tx-sender (get vault owner)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Update permissions
        (let ((current-permissions (get-vault-permissions vault_id)))
          (if (is-some current-permissions)
              (begin
                (let ((perms (unwrap-optional current-permissions)))
                  (map-set vault-permissions { vault-id: vault_id } {
                    authorized-users: (append (get perms authorized-users) user),
                    permissions: (append (get perms permissions) { user: user, level: level }),
                    last-updated: block-height
                  })
                )
              )
              ;; Create new permissions record
              (map-set vault-permissions { vault-id: vault_id } {
                authorized-users: (list user),
                permissions: (list { user: user, level: level }),
                last-updated: block-height
              })
          )
        )
        
        ;; Emit event
        (print { event: "permission-granted", vault-id: vault_id, user: user, level: level })
        
        (ok true)
      )
    )
  )
)

(define-public (revoke-vault-permission (vault-id (buff 32)) (user principal))
  (begin
    ;; Validate inputs
    (asserts! (principal? user) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        ;; Only owner can revoke permissions
        (asserts! (is-eq tx-sender (get vault owner)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Update permissions
        (let ((current-permissions (get-vault-permissions vault_id)))
          (if (is-some current-permissions)
              (begin
                (let ((perms (unwrap-optional current-permissions)))
                  (map-set vault-permissions { vault-id: vault_id } {
                    authorized-users: (remove-from-list (get perms authorized-users) user),
                    permissions: (remove-user-permission (get perms permissions) user),
                    last-updated: block-height
                  })
                )
              )
              true
          )
        )
        
        ;; Emit event
        (print { event: "permission-revoked", vault-id: vault_id, user: user })
        
        (ok true)
      )
    )
  )
)

(define-public (start-cooldown (vault_id (buff 32)) (duration uint))
  (begin
    ;; Validate inputs
    (asserts! (> duration u0) ERR_INVALID_AMOUNT)
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        ;; Only owner can start cooldown
        (asserts! (is-eq tx-sender (get vault owner)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Update cooldown
        (map-set vaults { vault-id: vault_id } {
          owner: (get vault owner),
          vault-type: (get vault vault-type),
          tokens: (get vault tokens),
          balances: (get vault balances),
          created-at: (get vault created-at),
          last-updated: block-height,
          active: (get vault active),
          metadata: (get vault metadata),
          cooldown-end: (+ block-height duration)
        })
        
        ;; Emit event
        (print { event: "cooldown-started", vault-id: vault_id, duration: duration })
        
        (ok {
          vault-id: vault_id,
          cooldown-end: (+ block-height duration),
          duration: duration
        })
      )
    )
  )
)

(define-public (activate-vault (vault_id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        ;; Only owner can activate vault
        (asserts! (is-eq tx-sender (get vault owner)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Activate vault
        (map-set vaults { vault-id: vault_id } {
          owner: (get vault owner),
          vault-type: (get vault vault-type),
          tokens: (get vault tokens),
          balances: (get vault balances),
          created-at: (get vault created-at),
          last-updated: block-height,
          active: true,
          metadata: (get vault metadata),
          cooldown-end: (get vault cooldown-end)
        })
        
        ;; Update user vaults
        (let ((user_info (get-user-vaults (get vault owner))))
          (if (is-some user_info)
              (begin
                (let ((user-vaults (unwrap-optional user_info)))
                  (map-set user-vaults { user: (get vault owner) } {
                    vault-ids: (get user-vaults vault-ids),
                    total-vaults: (get user-vaults total-vaults),
                    active-vaults: (+ (get user-vaults active-vaults) u1),
                    last-activity: block-height
                  })
                )
              )
              true
          )
        )
        
        ;; Emit event
        (print { event: "vault-activated", vault-id: vault_id })
        
        (ok true)
      )
    )
  )
)

(define-public (deactivate-vault (vault_id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get vault-system-active) ERR_VAULT_NOT_ACTIVE)
    
    ;; Check if vault exists
    (let ((vault_info (get-vault vault_id)))
      (asserts! (is-some vault_info) ERR_VAULT_NOT_FOUND)
      
      (let ((vault (unwrap-optional vault_info)))
        ;; Only owner can deactivate vault
        (asserts! (is-eq tx-sender (get vault owner)) ERR_UNAUTHORIZED_ACCESS)
        
        ;; Deactivate vault
        (map-set vaults { vault-id: vault_id } {
          owner: (get vault owner),
          vault-type: (get vault vault-type),
          tokens: (get vault tokens),
          balances: (get vault balances),
          created-at: (get vault created-at),
          last-updated: block-height,
          active: false,
          metadata: (get vault metadata),
          cooldown-end: (get vault cooldown-end)
        })
        
        ;; Update user vaults
        (let ((user_info (get-user-vaults (get vault owner))))
          (if (is-some user_info)
              (begin
                (let ((user-vaults (unwrap-optional user_info)))
                  (map-set user-vaults { user: (get vault owner) } {
                    vault-ids: (get user-vaults vault-ids),
                    total-vaults: (get user-vaults total-vaults),
                    active-vaults: (- (get user-vaults active-vaults) u1),
                    last-activity: block-height
                  })
                )
              )
              true
          )
        )
        
        ;; Emit event
        (print { event: "vault-deactivated", vault-id: vault_id })
        
        (ok true)
      )
    )
  )
)

(define-public (set-vault-system-active (active bool))
  (begin
    ;; Only admin can set system status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_ACCESS)
    
    (var-set vault-system-active active)
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { vault-ids: (list 0 (buff 32)), total-vaults: uint, active-vaults: uint, last-activity: uint } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (get-user-permission (permissions (list 5 { user: principal, level: (string-ascii 16) })) (user principal))
  (begin
    (match (find-if (lambda ((p { user: principal, level: (string-ascii 16) })) (is-eq (get p user) user)) permissions)
      found (some (get found level))
      none none
    )
  )
)

(define-private (has-permission-level (level (string-ascii 16)) (required-level (string-ascii 16)))
  (if (is-eq level "owner")
    true
    (is-eq level required-level)
  )
)

(define-private (is-token-supported (tokens (list 10 principal)) (token principal))
  (is-some (find-if (lambda ((t principal)) (is-eq t token)) tokens))
)

(define-private (update-token-balance (balances (list 10 { token: principal, amount: uint })) (token principal) (amount int))
  (let ((current-balance (get-token-balance balances token)))
    (let ((new-balance (+ current-balance amount)))
      (asserts! (>= new-balance u0) ERR_INSUFFICIENT_BALANCE)
      (let ((other-balances (filter (lambda ((b { token: principal, amount: uint })) (not (is-eq (get b token) token))) balances)))
        (append other-balances { token: token, amount: new-balance })
      )
    )
  )
)

(define-private (get-token-balance (balances (list 10 { token: principal, amount: uint })) (token principal))
  (match (find-if (lambda ((b { token: principal, amount: uint })) (is-eq (get b token) token)) balances)
    found (get found amount)
    none u0
  )
)

(define-private (update-user-activity (user principal))
  (let ((user-info (get-user-vaults user)))
    (if (is-some user-info)
      (let ((user-vaults (unwrap-panic user-info)))
        (map-set user-vaults { user: user } {
          vault-ids: (get user-vaults vault-ids),
          total-vaults: (get user-vaults total-vaults),
          active-vaults: (get user-vaults active-vaults),
          last-activity: block-height
        })
      )
      true
    )
  )
)

(define-private (update-vault-statistics (vault-type (string-ascii 32)) (deposit-amount uint) (withdrawal-amount uint))
  (let ((type-stats (get-vault-statistics vault-type)))
    (if (is-some type-stats)
      (let ((stats (unwrap-panic type-stats)))
        (map-set vault-statistics { vault-type: vault-type } {
          total-vaults: (get stats total-vaults),
          total-deposits: (+ (get stats total-deposits) deposit-amount),
          total-withdrawals: (+ (get stats total-withdrawals) withdrawal-amount),
          average-balance: (get stats average-balance),
          last-activity: block-height
        })
      )
      true
    )
  )
)

(define-private (remove-from-list (items (list 10 principal)) (item principal))
  (filter (lambda ((i principal)) (not (is-eq i item))) items)
)

(define-private (remove-user-permission (permissions (list 5 { user: principal, level: (string-ascii 16) })) (user principal))
  (filter (lambda ((p { user: principal, level: (string-ascii 16) })) (not (is-eq (get p user) user))) permissions)
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

(define-read-only (get-vault-summary (vault_id (buff 32)))
  (match (get-vault vault_id)
    vault
      (ok {
        vault-id: vault_id,
        owner: (get vault owner),
        vault-type: (get vault vault-type),
        active: (get vault active),
        created-at: (get vault created-at),
        last-updated: (get vault last-updated),
        token-count: (len (get vault tokens)),
        total-balance: (fold (get vault balances) u0 +)
      })
    none (err ERR_VAULT_NOT_FOUND)
  )
)

(define-read-only (get-user-vault-summary (user principal))
  (match (get-user-vaults user)
    user-vaults
      (ok {
        user: user,
        total-vaults: (get user-vaults total-vaults),
        active-vaults: (get user-vaults active-vaults),
        last-activity: (get user-vaults last-activity),
        vault-ids: (get user-vaults vault-ids)
      })
    none (ok { user: user, total-vaults: u0, active-vaults: u0, last-activity: u0, vault-ids: (list 0 (buff 32)) })
  )
)
)
