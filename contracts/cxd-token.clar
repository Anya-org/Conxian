;; cxd-token.clar
;; Conxian Revenue Token (SIP-010 FT) - accrues protocol revenue to holders off-contract
;; Enhanced with integration hooks for staking, revenue distribution, and system monitoring

(impl-trait .sip-010-trait.sip-010-trait)
(impl-trait .ft-mintable-trait.ft-mintable-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_SYSTEM_PAUSED u102)
(define-constant ERR_EMISSION_LIMIT_EXCEEDED u103)
(define-constant ERR_TRANSFER_HOOK_FAILED u104)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Revenue Token")
(define-data-var symbol (string-ascii 10) "CXD")
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Integration contracts
(define-data-var staking-contract principal .cxd-staking)
(define-data-var revenue-distributor-contract principal .revenue-distributor)
(define-data-var emission-controller-contract principal .token-emission-controller)
(define-data-var invariant-monitor-contract principal .protocol-invariant-monitor)
(define-data-var system-coordinator-contract principal .token-system-coordinator)

;; Enhanced storage
(define-map balances { who: principal } { bal: uint })
(define-map minters { who: principal } { enabled: bool })
(define-data-var transfer-hooks-enabled bool true)
(define-data-var system-integration-enabled bool false)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (is-minter (who principal))
  (is-some (map-get? minters { who: who }))
)

;; --- System Integration ---
(define-read-only (is-system-paused)
  (if (var-get system-integration-enabled)
    (contract-call? .protocol-invariant-monitor is-protocol-paused)
    false))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)))

(define-public (update-integration-contracts 
  (staking principal) 
  (revenue-dist principal) 
  (emission-ctrl principal) 
  (invariant-monitor principal) 
  (coordinator principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set staking-contract staking)
    (var-set revenue-distributor-contract revenue-dist)
    (var-set emission-controller-contract emission-ctrl)
    (var-set invariant-monitor-contract invariant-monitor)
    (var-set system-coordinator-contract coordinator)
    (ok true)))

(define-public (set-transfer-hooks (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfer-hooks-enabled enabled)
    (ok true)))

;; --- Owner/Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (if enabled
      (map-set minters { who: who } { enabled: true })
      (map-delete minters { who: who })
    )
    (ok true)
  )
)

;; --- SIP-010 interface with enhanced integration ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-system-paused)) (err ERR_SYSTEM_PAUSED))
    
    (let ((sender-bal (default-to u0 (get bal (map-get? balances { who: sender })))) )
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      ;; Execute transfer hooks if enabled
      (if (and (var-get transfer-hooks-enabled) (var-get system-integration-enabled))
        (try! (execute-transfer-hooks sender recipient amount))
        (ok true))
      
      ;; Perform the actual transfer
      (map-set balances { who: sender } { bal: (- sender-bal amount) })
      (let ((rec-bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
        (map-set balances { who: recipient } { bal: (+ rec-bal amount) })
      )
      (ok true)
    )
  )
)

;; Transfer hooks for system integration
(define-private (execute-transfer-hooks (sender principal) (recipient principal) (amount uint))
  (begin
    ;; Notify staking contract if sender or recipient is staking contract
    (if (or (is-eq sender (var-get staking-contract)) (is-eq recipient (var-get staking-contract)))
      (match (as-contract (contract-call? .cxd-staking notify-transfer sender recipient amount))
        success (ok true)
        error (ok true)) ;; Don't fail transfer on hook failure, just log
      (ok true))
  )
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get bal (map-get? balances { who: who }))))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get decimals))
)

(define-read-only (get-name)
  (ok (var-get name))
)

(define-read-only (get-symbol)
  (ok (var-get symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (set-token-uri (value (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-uri value)
    (ok true)
  )
)

;; --- Enhanced Mint/Burn with emission controls ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-system-paused)) (err ERR_SYSTEM_PAUSED))
    
    ;; Check emission limits if system integration is enabled
    (if (var-get system-integration-enabled)
      (match (contract-call? .token-emission-controller check-emission-allowed (as-contract tx-sender) amount)
        allowed (begin
          (var-set total-supply (+ (var-get total-supply) amount))
          (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
            (map-set balances { who: recipient } { bal: (+ bal amount) })
          )
          (ok true))
        error (err ERR_EMISSION_LIMIT_EXCEEDED))
      (begin
        ;; Legacy mint without emission checks
        (var-set total-supply (+ (var-get total-supply) amount))
        (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
          (map-set balances { who: recipient } { bal: (+ bal amount) })
        )
        (ok true)))
  )
)

(define-public (burn (amount uint))
  (let ((bal (default-to u0 (get bal (map-get? balances { who: tx-sender })))) )
    (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
    (asserts! (not (is-system-paused)) (err ERR_SYSTEM_PAUSED))
    
    (map-set balances { who: tx-sender } { bal: (- bal amount) })
    (var-set total-supply (- (var-get total-supply) amount))
    
    ;; Notify revenue distributor if system integration enabled
    (if (var-get system-integration-enabled)
      (match (as-contract (contract-call? .revenue-distributor record-token-burn tx-sender amount))
        success (ok true)
        error (ok true)) ;; Don't fail burn on notification failure
      (ok true))
  )
)

;; --- Additional Integration Functions ---
(define-read-only (get-integration-info)
  {
    system-integration-enabled: (var-get system-integration-enabled),
    transfer-hooks-enabled: (var-get transfer-hooks-enabled),
    system-paused: (is-system-paused),
    staking-contract: (var-get staking-contract),
    revenue-distributor: (var-get revenue-distributor-contract),
    emission-controller: (var-get emission-controller-contract)
  })
