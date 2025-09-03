;; cxvg-token.clar
;; Conxian Governance Token (SIP-010 FT) - no direct revenue share
;; Enhanced with system integration hooks for coordinator interface

(impl-trait .sip-010-trait.sip-010-trait)
(impl-trait .ft-mintable-trait.ft-mintable-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_SYSTEM_PAUSED u102)
(define-constant ERR_EMISSION_DENIED u103)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Governance Token")
(define-data-var symbol (string-ascii 10) "CXVG")
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map balances { who: principal } { bal: uint })
(define-map minters { who: principal } { enabled: bool })

;; --- System Integration ---
(define-data-var system-integration-enabled bool false)
(define-data-var token-coordinator (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (is-minter (who principal))
  (is-some (map-get? minters { who: who }))
)

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

;; --- System Integration Setup ---
(define-public (enable-system-integration 
    (coordinator-contract principal)
    (emission-contract principal) 
    (monitor-contract principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-coordinator (some coordinator-contract))
    (var-set emission-controller (some emission-contract))
    (var-set protocol-monitor (some monitor-contract))
    (var-set system-integration-enabled true)
    (ok true)
  )
)

(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled false)
    (ok true)
  )
)

;; Enhanced Functions with Monitor Integration
(use-trait protocol-monitor .monitor-trait.monitor-trait)

(define-read-only (is-system-paused)
  (if (var-get system-integration-enabled)
    (begin
      (asserts! (is-some (var-get protocol-monitor)) (err ERR_SYSTEM_NOT_CONFIGURED))
      (let ((monitor (unwrap-panic (var-get protocol-monitor))))
        (unwrap! (contract-call? protocol-monitor is-system-operational) (err ERR_SYSTEM_PAUSED))
        false))
    false))

(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (unwrap! (contract-call? protocol-monitor is-system-operational) (err ERR_SYSTEM_PAUSED))
    true
  )
)

(define-private (check-emission-allowed (amount uint))
  (if (var-get system-integration-enabled)
    (match (var-get emission-controller)
      controller-contract
        (unwrap! (contract-call? controller-contract check-mint-allowed (as-contract tx-sender) amount) (err ERR_EMISSION_DENIED))
      true)
    true
  )
)

(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        (match (contract-call? coordinator-contract on-token-transfer (as-contract tx-sender) amount sender recipient)
          result result
          false)
      true)
    true
  )
)

(define-private (notify-mint (amount uint) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        (match (contract-call? coordinator-contract on-token-mint (as-contract tx-sender) amount recipient)
          result result
          false)
      true)
    true
  )
)

(define-private (notify-burn (amount uint) (burner principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        (match (contract-call? coordinator-contract on-token-burn (as-contract tx-sender) amount burner)
          result result
          false)
      true)
    true
  )
)

;; --- SIP-010 interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (let ((sender-bal (default-to u0 (get bal (map-get? balances { who: sender }))))
         )
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances { who: sender } { bal: (- sender-bal amount) })
      (let ((rec-bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
        (map-set balances { who: recipient } { bal: (+ rec-bal amount) })
      )
      ;; Notify system coordinator
      (notify-transfer amount sender recipient)
    )
    (ok true)
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

;; --- Mint/Burn (admin or authorized minters) ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (asserts! (check-emission-allowed amount) (err ERR_EMISSION_DENIED))
    (var-set total-supply (+ (var-get total-supply) amount))
    (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
      (map-set balances { who: recipient } { bal: (+ bal amount) })
    )
    ;; Notify system coordinator
    (notify-mint amount recipient)
    (ok true)
  )
)

(define-public (burn (amount uint))
  (let ((bal (default-to u0 (get bal (map-get? balances { who: tx-sender })))) )
    (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (map-set balances { who: tx-sender } { bal: (- bal amount) })
    (var-set total-supply (- (var-get total-supply) amount))
    ;; Notify system coordinator
    (notify-burn amount tx-sender)
    (ok true)
  )
)

;; --- System Integration Interface ---
(define-read-only (get-system-info)
  {
    integration-enabled: (var-get system-integration-enabled),
    coordinator: (var-get token-coordinator),
    emission-controller: (var-get emission-controller),
    protocol-monitor: (var-get protocol-monitor)
  }
)
