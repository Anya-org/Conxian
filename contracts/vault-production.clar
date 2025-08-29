;; vault-production.clar
;; Production-ready vault implementation for Conxian platform
;; Based on vault.clar but with real production dependencies

(use-trait sip010 .sip-010-trait.sip-010-trait)
(use-trait vault-admin .vault-admin-trait.vault-admin-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_TOKEN_NOT_INITIALIZED u101)
(define-constant ERR_INVALID_AMOUNT u102)
(define-constant ERR_INSUFFICIENT_BALANCE u103)
(define-constant ERR_TRANSFER_FAILED u104)
(define-constant ERR_PAUSED u105)
(define-constant ERR_MAX_CAPACITY_REACHED u106)
(define-constant ERR_ALREADY_INITIALIZED u107)
(define-constant ERR_ZERO_ADDRESS u108)

;; Global variables
(define-data-var admin principal tx-sender)
(define-data-var token (optional principal) none)
(define-data-var paused bool false)
(define-data-var fee-bps uint u50) ;; 0.5% fee
(define-data-var max-capacity uint u100000000000)
(define-data-var total-deposits uint u0)
(define-data-var min-deposit uint u100000) ;; Minimum deposit amount
(define-data-var fee-recipient principal tx-sender)

;; Data maps
(define-map deposits principal uint)
(define-map earnings principal uint)

;; Read-only functions
(define-read-only (get-deposit (user principal))
    (default-to u0 (map-get? deposits user))
)

(define-read-only (get-total-deposits)
    (var-get total-deposits)
)

(define-read-only (get-fee-bps)
    (var-get fee-bps)
)

(define-read-only (get-admin)
    (var-get admin)
)

(define-read-only (get-fee-recipient)
    (var-get fee-recipient)
)

(define-read-only (is-paused)
    (var-get paused)
)

(define-read-only (get-token-contract)
    (var-get token)
)

(define-read-only (get-available-capacity)
    (let (
        (total (var-get total-deposits))
        (max (var-get max-capacity))
    )
    (if (> max total)
        (- max total)
        u0
    ))
)

;; Initialize the vault with a token contract
(define-public (initialize-token (token-principal principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (var-get token)) (err ERR_ALREADY_INITIALIZED))
    (asserts! (not (is-eq token-principal .mock-ft)) (err ERR_ZERO_ADDRESS))
        
    ;; Set token contract
    (var-set token (some token-principal))
        (ok true)
    )
)

;; Public functions
(define-public (deposit (amount uint) (token-contract <sip010>))
    (let (
    (stored-token (unwrap! (var-get token) (err ERR_TOKEN_NOT_INITIALIZED)))
    (sender tx-sender)
        (current-deposit (get-deposit sender))
    )
        ;; Check requirements
        (asserts! (not (var-get paused)) (err ERR_PAUSED))
        (asserts! (>= amount (var-get min-deposit)) (err ERR_INVALID_AMOUNT))
        (asserts! (<= (+ amount (var-get total-deposits)) (var-get max-capacity)) (err ERR_MAX_CAPACITY_REACHED))
    (asserts! (is-eq (contract-of token-contract) stored-token) (err ERR_ZERO_ADDRESS))
        
    ;; Transfer tokens from user to vault via SIP-010 transfer-from(sender, recipient, amount)
    (try! (as-contract (contract-call? token-contract transfer-from sender tx-sender amount)))
        
        ;; Update storage
        (map-set deposits sender (+ current-deposit amount))
        (var-set total-deposits (+ (var-get total-deposits) amount))
        
        (ok amount)
    )
)

(define-public (withdraw (amount uint) (token-contract <sip010>))
    (let (
    (stored-token (unwrap! (var-get token) (err ERR_TOKEN_NOT_INITIALIZED)))
        (sender tx-sender)
        (current-deposit (get-deposit sender))
        (fee-amount (calculate-fee amount))
        (withdraw-amount (- amount fee-amount))
    )
        ;; Check requirements
        (asserts! (not (var-get paused)) (err ERR_PAUSED))
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        (asserts! (>= current-deposit amount) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (is-eq (contract-of token-contract) stored-token) (err ERR_ZERO_ADDRESS))
        
        ;; Update storage first (reentrancy protection)
        (map-set deposits sender (- current-deposit amount))
        (var-set total-deposits (- (var-get total-deposits) amount))
        
        ;; Handle fees if applicable
        (if (> fee-amount u0)
            (begin
                ;; Transfer fee to recipient (as contract)
                (try! (as-contract (contract-call? token-contract transfer (var-get fee-recipient) fee-amount)))
                ;; Transfer main amount to user (as contract)
                (try! (as-contract (contract-call? token-contract transfer sender withdraw-amount)))
            )
            ;; No fee, transfer full amount
            (try! (as-contract (contract-call? token-contract transfer sender amount)))
        )
        
        (ok withdraw-amount)
    )
)

;; Admin functions
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (var-set admin new-admin)
        (ok true)
    )
)

(define-public (set-fee (new-fee-bps uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (asserts! (<= new-fee-bps u1000) (err ERR_INVALID_AMOUNT)) ;; Max 10%
        (var-set fee-bps new-fee-bps)
        (ok true)
    )
)

(define-public (set-fee-recipient (new-recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (var-set fee-recipient new-recipient)
        (ok true)
    )
)

(define-public (set-max-capacity (new-capacity uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (asserts! (>= new-capacity (var-get total-deposits)) (err ERR_INVALID_AMOUNT))
        (var-set max-capacity new-capacity)
        (ok true)
    )
)

(define-public (set-min-deposit (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (var-set min-deposit new-min)
        (ok true)
    )
)

(define-public (set-auto-economics-enabled (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (print { event: "set-auto-economics-enabled", enabled: enabled })
        (ok true)
    )
)

(define-public (pause (new-state bool))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (var-set paused new-state)
        (ok true)
    )
)

(define-public (recover-tokens (token-contract <sip010>) (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        
        ;; Can't recover vault tokens if they're part of user deposits
        (if (is-eq (contract-of token-contract) (unwrap! (var-get token) (err ERR_TOKEN_NOT_INITIALIZED)))
            (let ((vault-balance (unwrap! (as-contract (contract-call? token-contract get-balance-of tx-sender)) (err ERR_TRANSFER_FAILED))))
              (asserts! (<= amount (- vault-balance (var-get total-deposits))) (err ERR_INSUFFICIENT_BALANCE)))
            true
        )
        
        ;; Transfer tokens
        (try! (as-contract (contract-call? token-contract transfer
            recipient
            amount
        )))
        
        (ok true)
    )
)

;; Administrative delegation
;; Delegate-admin-function removed: not part of vault-admin-trait interface

;; Private functions
(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get fee-bps)) u10000)
)
