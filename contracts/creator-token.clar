;; Creator Token - Rewards for Contributors
;; SIP-010 compliant token for rewarding bounty contributors

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant TOKEN_NAME "CX_Creator")
(define-constant TOKEN_SYMBOL "CXTR")
(define-constant TOKEN_DECIMALS u6)

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var bounty-system principal .bounty-system)
(define-data-var dao-governance principal .dao-governance)

;; Maps
(define-map balances { owner: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })

;; Vesting for creator tokens
(define-map vesting-schedules
  { recipient: principal, schedule-id: uint }
  {
    total-amount: uint,
    vested-amount: uint,
    start-block: uint,
    cliff-blocks: uint,
    vesting-blocks: uint,
    last-claim-block: uint
  }
)

(define-data-var vesting-schedule-count uint u0)

;; SIP-010 Implementation
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-balance-of (owner principal))
  (ok (default-to u0 (get amount (map-get? balances { owner: owner }))))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (get amount (map-get? allowances { owner: owner, spender: spender }))))
)

;; Transfer functions
(define-public (transfer (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((sender-balance (unwrap! (get-balance-of tx-sender) (err u2))))
      (asserts! (>= sender-balance amount) (err u2))
      (try! (transfer-helper tx-sender recipient amount))
      (ok true)
    )
  )
)

(define-public (transfer-from (sender principal) (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let (
      (sender-balance (unwrap! (get-balance-of sender) (err u2)))
      (allowance (unwrap! (get-allowance sender tx-sender) (err u3)))
    )
      (asserts! (>= sender-balance amount) (err u2))
      (asserts! (>= allowance amount) (err u3))
      (try! (transfer-helper sender recipient amount))
      (map-set allowances 
        { owner: sender, spender: tx-sender }
        { amount: (- allowance amount) }
      )
      (ok true)
    )
  )
)

(define-public (approve (spender principal) (amount uint))
  (begin
    (map-set allowances 
      { owner: tx-sender, spender: spender }
      { amount: amount }
    )
    (ok true)
  )
)

;; Helper function for transfers
(define-private (transfer-helper (sender principal) (recipient principal) (amount uint))
  (let (
    (sender-balance (unwrap! (get-balance-of sender) (err u2)))
    (recipient-balance (unwrap! (get-balance-of recipient) (err u2)))
  )
    (map-set balances { owner: sender } { amount: (- sender-balance amount) })
    (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
    (print {
      event: "transfer",
      sender: sender,
      recipient: recipient,
      amount: amount
    })
    (ok true)
  )
)

;; Minting functions (restricted to bounty system and DAO)
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or 
      (is-eq tx-sender (var-get bounty-system))
      (is-eq tx-sender (var-get dao-governance))
    ) (err u100))
    (asserts! (> amount u0) (err u1))
    
    (let ((recipient-balance (unwrap! (get-balance-of recipient) (err u2))))
      (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      
      (print {
        event: "mint",
        recipient: recipient,
        amount: amount,
        total-supply: (var-get total-supply)
      })
      (ok true)
    )
  )
)

(define-public (mint-with-vesting 
  (recipient principal) 
  (amount uint)
  (cliff-blocks uint)
  (vesting-blocks uint)
)
  (begin
    (asserts! (or 
      (is-eq tx-sender (var-get bounty-system))
      (is-eq tx-sender (var-get dao-governance))
    ) (err u100))
    (asserts! (> amount u0) (err u1))
    (asserts! (> vesting-blocks u0) (err u104))
    
    (let ((schedule-id (+ (var-get vesting-schedule-count) u1)))
      ;; Create vesting schedule
      (map-set vesting-schedules
        { recipient: recipient, schedule-id: schedule-id }
        {
          total-amount: amount,
          vested-amount: u0,
          start-block: block-height,
          cliff-blocks: cliff-blocks,
          vesting-blocks: vesting-blocks,
          last-claim-block: block-height
        }
      )
      
      (var-set vesting-schedule-count schedule-id)
      (var-set total-supply (+ (var-get total-supply) amount))
      
      (print {
        event: "mint-with-vesting",
        recipient: recipient,
        amount: amount,
        schedule-id: schedule-id,
        cliff-blocks: cliff-blocks,
        vesting-blocks: vesting-blocks
      })
      (ok schedule-id)
    )
  )
)

;; Vesting functions
(define-read-only (get-vesting-schedule (recipient principal) (schedule-id uint))
  (map-get? vesting-schedules { recipient: recipient, schedule-id: schedule-id })
)

(define-read-only (calculate-vested-amount (recipient principal) (schedule-id uint))
  (match (get-vesting-schedule recipient schedule-id)
    schedule (let (
      (current-block block-height)
      (start-block (get start-block schedule))
      (cliff-blocks (get cliff-blocks schedule))
      (vesting-blocks (get vesting-blocks schedule))
      (total-amount (get total-amount schedule))
      (already-vested (get vested-amount schedule))
    )
    (if (< current-block (+ start-block cliff-blocks))
      u0 ;; Before cliff
      (if (>= current-block (+ start-block vesting-blocks))
        (- total-amount already-vested) ;; Fully vested
        ;; Proportional vesting
        (let (
          (elapsed-blocks (- current-block start-block))
          (total-vested (/ (* total-amount elapsed-blocks) vesting-blocks))
        )
        (- total-vested already-vested)
        )
      )
    ))
    u0
  )
)

(define-public (claim-vested-tokens (schedule-id uint))
  (let (
    (schedule (unwrap! (get-vesting-schedule tx-sender schedule-id) (err u105)))
    (claimable (calculate-vested-amount tx-sender schedule-id))
  )
    (asserts! (> claimable u0) (err u106))
    
    ;; Update vesting schedule
    (map-set vesting-schedules
      { recipient: tx-sender, schedule-id: schedule-id }
      (merge schedule {
        vested-amount: (+ (get vested-amount schedule) claimable),
        last-claim-block: block-height
      })
    )
    
    ;; Transfer tokens to recipient
    (let ((recipient-balance (unwrap! (get-balance-of tx-sender) (err u2))))
      (map-set balances { owner: tx-sender } { amount: (+ recipient-balance claimable) })
    )
    
    (print {
      event: "vested-tokens-claimed",
      recipient: tx-sender,
      schedule-id: schedule-id,
      amount: claimable
    })
    (ok claimable)
  )
)

;; Governance functions
(define-public (set-bounty-system (new-bounty-system principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set bounty-system new-bounty-system)
    (ok true)
  )
)

(define-public (set-dao-governance (new-dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set dao-governance new-dao)
    (ok true)
  )
)

;; Burn function for deflationary mechanics
(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((sender-balance (unwrap! (get-balance-of tx-sender) (err u2))))
      (asserts! (>= sender-balance amount) (err u2))
      (map-set balances { owner: tx-sender } { amount: (- sender-balance amount) })
      (var-set total-supply (- (var-get total-supply) amount))
      
      (print {
        event: "burn",
        burner: tx-sender,
        amount: amount,
        total-supply: (var-get total-supply)
      })
      (ok true)
    )
  )
)

;; Utility functions
(define-read-only (get-contributor-info (contributor principal))
  {
    balance: (unwrap-panic (get-balance-of contributor)),
    vesting-schedules: (get-contributor-vesting-count contributor)
  }
)

(define-private (get-contributor-vesting-count (contributor principal))
  ;; This would need to be implemented with a counter map in production
  u0
)

;; Errors
;; u1: invalid-amount
;; u2: insufficient-balance
;; u3: insufficient-allowance
;; u100: unauthorized
;; u104: invalid-vesting-period
;; u105: vesting-schedule-not-found
;; u106: no-claimable-tokens
