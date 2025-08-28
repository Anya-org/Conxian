;; Vault Core v2 - Consolidated Vault Implementation
;; Combines features from vault-production, vault-enhanced, and vault.clar

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INVALID_AMOUNT u1002)
(define-constant ERR_INSUFFICIENT_BALANCE u1003)
(define-constant ERR_INVALID_TOKEN u1004)
(define-constant ERR_FLASH_LOAN_NOT_REPAID u1005)
(define-constant ERR_CAPACITY_EXCEEDED u1006)

;; Constants
(define-constant MAX_FEE u10000) ;; 100% in basis points
(define-constant FLASH_LOAN_FEE u30) ;; 0.3% flash loan fee
(define-constant MAX_CAPACITY u1000000000000) ;; Max vault capacity

;; Data variables
(define-data-var contract-admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var total-assets uint u0)
(define-data-var total-shares uint u0)
(define-data-var management-fee uint u200) ;; 2% annual fee in basis points
(define-data-var performance-fee uint u1000) ;; 10% performance fee in basis points

;; Multi-token support
(define-map vault-tokens principal bool)
(define-map token-balances principal uint)
(define-map user-shares principal uint)
(define-map token-strategies principal principal)

;; Flash loan tracking
(define-map flash-loans uint {borrower: principal, amount: uint, token: principal, repaid: bool})
(define-data-var next-loan-id uint u1)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set contract-admin new-admin)
    (ok true)))

(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (var-set paused false)
    (ok true)))

(define-public (add-token (token-contract <sip-010-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (map-set vault-tokens (contract-of token-contract) true)
    (ok true)))

(define-public (remove-token (token-contract <sip-010-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (map-delete vault-tokens (contract-of token-contract))
    (ok true)))

;; Core vault functions
(define-public (deposit (token-contract <sip-010-trait>) (amount uint))
  (let ((token-principal (contract-of token-contract))
        (current-balance (default-to u0 (map-get? token-balances token-principal)))
        (user-current-shares (default-to u0 (map-get? user-shares tx-sender)))
        (total-current-shares (var-get total-shares))
        (shares-to-mint (if (is-eq total-current-shares u0) 
                         amount 
                         (/ (* amount total-current-shares) (var-get total-assets)))))
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (default-to false (map-get? vault-tokens token-principal)) (err ERR_INVALID_TOKEN))
    (asserts! (<= (+ (var-get total-assets) amount) MAX_CAPACITY) (err ERR_CAPACITY_EXCEEDED))
    
    ;; Transfer tokens from user
    (try! (contract-call? token-contract transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update balances
    (map-set token-balances token-principal (+ current-balance amount))
    (map-set user-shares tx-sender (+ user-current-shares shares-to-mint))
    (var-set total-assets (+ (var-get total-assets) amount))
    (var-set total-shares (+ total-current-shares shares-to-mint))
    
    (ok shares-to-mint)))

(define-public (withdraw (token-contract <sip-010-trait>) (shares uint))
  (let ((token-principal (contract-of token-contract))
        (user-current-shares (default-to u0 (map-get? user-shares tx-sender)))
        (total-current-shares (var-get total-shares))
        (current-balance (default-to u0 (map-get? token-balances token-principal)))
        (amount-to-withdraw (/ (* shares current-balance) total-current-shares)))
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (> shares u0) (err ERR_INVALID_AMOUNT))
    (asserts! (>= user-current-shares shares) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (default-to false (map-get? vault-tokens token-principal)) (err ERR_INVALID_TOKEN))
    
    ;; Update balances before transfer
    (map-set user-shares tx-sender (- user-current-shares shares))
    (map-set token-balances token-principal (- current-balance amount-to-withdraw))
    (var-set total-shares (- total-current-shares shares))
    (var-set total-assets (- (var-get total-assets) amount-to-withdraw))
    
    ;; Transfer tokens to user
    (as-contract (contract-call? token-contract transfer amount-to-withdraw tx-sender tx-sender none))
    (ok amount-to-withdraw)))

;; Flash loan functionality
(define-public (flash-loan (token-contract <sip-010-trait>) (amount uint))
  (let ((token-principal (contract-of token-contract))
        (current-balance (default-to u0 (map-get? token-balances token-principal)))
        (loan-id (var-get next-loan-id))
        (fee (/ (* amount FLASH_LOAN_FEE) u10000)))
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    (asserts! (>= current-balance amount) (err ERR_INSUFFICIENT_BALANCE))
    (asserts! (default-to false (map-get? vault-tokens token-principal)) (err ERR_INVALID_TOKEN))
    
    ;; Record flash loan
    (map-set flash-loans loan-id {borrower: tx-sender, amount: amount, token: token-principal, repaid: false})
    (var-set next-loan-id (+ loan-id u1))
    
    ;; Transfer tokens to borrower
    (as-contract (contract-call? token-contract transfer amount tx-sender tx-sender none))
    
    ;; Update balance
    (map-set token-balances token-principal (- current-balance amount))
    
    (ok loan-id)))

(define-public (repay-flash-loan (token-contract <sip-010-trait>) (loan-id uint))
  (let ((loan-info (unwrap! (map-get? flash-loans loan-id) (err ERR_INVALID_AMOUNT)))
        (token-principal (contract-of token-contract))
        (loan-amount (get amount loan-info))
        (fee (/ (* loan-amount FLASH_LOAN_FEE) u10000))
        (total-repayment (+ loan-amount fee))
        (current-balance (default-to u0 (map-get? token-balances token-principal))))
    (asserts! (is-eq tx-sender (get borrower loan-info)) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (get repaid loan-info)) (err ERR_FLASH_LOAN_NOT_REPAID))
    (asserts! (is-eq token-principal (get token loan-info)) (err ERR_INVALID_TOKEN))
    
    ;; Transfer repayment from borrower
    (try! (contract-call? token-contract transfer total-repayment tx-sender (as-contract tx-sender) none))
    
    ;; Update loan status and balance
    (map-set flash-loans loan-id (merge loan-info {repaid: true}))
    (map-set token-balances token-principal (+ current-balance total-repayment))
    
    (ok true)))

;; Fee management
(define-public (set-management-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= new-fee MAX_FEE) (err ERR_INVALID_AMOUNT))
    (var-set management-fee new-fee)
    (ok true)))

(define-public (set-performance-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (asserts! (<= new-fee MAX_FEE) (err ERR_INVALID_AMOUNT))
    (var-set performance-fee new-fee)
    (ok true)))

;; Emergency functions
(define-public (emergency-withdraw (token-contract <sip-010-trait>) (amount uint) (recipient principal))
  (let ((token-principal (contract-of token-contract)))
    (asserts! (is-eq tx-sender (var-get contract-admin)) (err ERR_NOT_AUTHORIZED))
    (as-contract (contract-call? token-contract transfer amount tx-sender recipient none))))

;; Read-only functions
(define-read-only (get-vault-info)
  {
    admin: (var-get contract-admin),
    paused: (var-get paused),
    total-assets: (var-get total-assets),
    total-shares: (var-get total-shares),
    management-fee: (var-get management-fee),
    performance-fee: (var-get performance-fee)
  })

(define-read-only (get-user-shares (user principal))
  (default-to u0 (map-get? user-shares user)))

(define-read-only (get-token-balance (token principal))
  (default-to u0 (map-get? token-balances token)))

(define-read-only (is-token-supported (token principal))
  (default-to false (map-get? vault-tokens token)))

(define-read-only (calculate-shares-for-amount (amount uint))
  (let ((total-current-shares (var-get total-shares))
        (total-current-assets (var-get total-assets)))
    (if (is-eq total-current-shares u0)
      amount
      (/ (* amount total-current-shares) total-current-assets))))

(define-read-only (calculate-amount-for-shares (shares uint))
  (let ((total-current-shares (var-get total-shares)))
    (if (is-eq total-current-shares u0)
      u0
      (/ (* shares (var-get total-assets)) total-current-shares))))

(define-read-only (get-flash-loan-info (loan-id uint))
  (map-get? flash-loans loan-id))
