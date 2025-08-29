;; Conxian Liquidity Provider Token (CXLP)
;; Temporary token that migrates to CXG over 3 epochs
;; Designed for liquidity mining and eventual consolidation

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant TOKEN_NAME "Conxian Liquidity Provider")
(define-constant TOKEN_SYMBOL "CXLP")
(define-constant TOKEN_DECIMALS u6)
(define-constant MAX_SUPPLY u50000000000000) ;; 50M CXLP max supply

;; Time constants (Bitcoin ~10 min blocks)
(define-constant BLOCKS_PER_DAY u144)
(define-constant BLOCKS_PER_WEEK u1008)
(define-constant BLOCKS_PER_MONTH u4032) ;; ~4 weeks
(define-constant BLOCKS_PER_QUARTER u13140) ;; ~91.25 days
(define-constant BLOCKS_PER_YEAR u52560) ;; 365 days  1 year

;; Migration periods (years)
(define-constant EPOCH_1_END u52560) ;; ~1 year
(define-constant EPOCH_2_END u105120) ;; ~2 years
(define-constant EPOCH_3_END u157680) ;; ~3 years
(define-constant EPOCH_4_END u210240) ;; ~4 years (final migration)
;; Quarterly releases and reports target each BLOCKS_PER_QUARTER during migration (memoed off-chain)

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var vault principal .vault)
(define-data-var migration-contract principal .CXG-token)
(define-data-var liquidity-mining-enabled bool true)
(define-data-var emergency-pause bool false)

;; Liquidity mining rewards
(define-data-var total-liquidity-provided uint u0)
(define-data-var total-rewards-earned uint u0)

;; Maps
(define-map balances { owner: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })

;; Liquidity tracking
(define-map liquidity-positions { 
  provider: principal 
} { 
  amount: uint,
  entry-block: uint,
  total-rewards: uint,
  last-claim-block: uint
})

;; Rewards per block based on liquidity depth
(define-map epoch-rewards { epoch: uint } { 
  base-rate: uint,    ;; Base CXLP per block
  bonus-multiplier: uint  ;; Bonus for long-term LPs
})

;; SIP-010 Implementation
(define-read-only (get-name) (ok TOKEN_NAME))
(define-read-only (get-symbol) (ok TOKEN_SYMBOL))
(define-read-only (get-decimals) (ok TOKEN_DECIMALS))
(define-read-only (get-total-supply) (ok (var-get total-supply)))

(define-read-only (get-balance-of (owner principal))
  (ok (default-to u0 (get amount (map-get? balances { owner: owner }))))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (get amount (map-get? allowances { owner: owner, spender: spender }))))
)

;; Liquidity mining functions
(define-public (provide-liquidity (amount uint))
  (begin
    (asserts! (var-get liquidity-mining-enabled) (err u301))
    (asserts! (not (var-get emergency-pause)) (err u302))
    (asserts! (> amount u0) (err u1))
    
    ;; Record liquidity position
    (let (
      (existing-position (default-to 
        { amount: u0, entry-block: block-height, total-rewards: u0, last-claim-block: block-height }
        (map-get? liquidity-positions { provider: tx-sender })
      ))
    )
      (map-set liquidity-positions { provider: tx-sender } {
        amount: (+ (get amount existing-position) amount),
        entry-block: (if (is-eq (get amount existing-position) u0) block-height (get entry-block existing-position)),
        total-rewards: (get total-rewards existing-position),
        last-claim-block: block-height
      })
      
      ;; Mint CXLP tokens for liquidity provision
      (try! (mint-to tx-sender amount))
      (var-set total-liquidity-provided (+ (var-get total-liquidity-provided) amount))
      
      (print {
        event: "liquidity-provided",
        provider: tx-sender,
        amount: amount,
        total-position: (+ (get amount existing-position) amount)
      })
      (ok amount)
    )
  )
)

(define-public (claim-mining-rewards)
  (let (
    (position (unwrap! (map-get? liquidity-positions { provider: tx-sender }) (err u200)))
    (blocks-since-last-claim (- block-height (get last-claim-block position)))
    (liquidity-amount (get amount position))
  )
    (asserts! (> liquidity-amount u0) (err u201))
    (asserts! (> blocks-since-last-claim u0) (err u202))
    
    (let (
      (current-epoch (get-current-epoch))
      (epoch-config (get-epoch-rewards current-epoch))
      (base-rewards (* blocks-since-last-claim (get base-rate epoch-config) liquidity-amount))
      (loyalty-bonus (get-loyalty-bonus position))
      (total-rewards (/ (* base-rewards (+ u1000000 loyalty-bonus)) u1000000)) ;; Apply bonus
    )
      ;; Update position
      (map-set liquidity-positions { provider: tx-sender } 
        (merge position {
          total-rewards: (+ (get total-rewards position) total-rewards),
          last-claim-block: block-height
        })
      )
      
      ;; Mint additional CXLP as rewards
      (try! (mint-to tx-sender total-rewards))
      (var-set total-rewards-earned (+ (var-get total-rewards-earned) total-rewards))
      
      (print {
        event: "mining-rewards-claimed",
        provider: tx-sender,
        rewards: total-rewards,
        blocks-rewarded: blocks-since-last-claim,
        loyalty-bonus: loyalty-bonus
      })
      (ok total-rewards)
    )
  )
)

(define-public (migrate-to-CXG (amount uint))
  (begin
    (asserts! (<= block-height EPOCH_4_END) (err u303))
    (asserts! (> amount u0) (err u1))
    
    (let ((user-balance (unwrap! (get-balance-of tx-sender) (err u2))))
      (asserts! (>= user-balance amount) (err u2))
      
      ;; Burn CXLP tokens
      (try! (burn-from tx-sender amount))
      
      ;; Call migration on CXG token
      (unwrap! (contract-call? .CXG-token migrate-CXLP amount) (err u304))
      
      (print {
        event: "CXLP-migration-initiated",
        user: tx-sender,
        CXLP-burned: amount
      })
      (ok true)
    )
  )
)

;; Emergency functions
(define-public (emergency-migrate-all)
  (begin
    (asserts! (<= block-height EPOCH_4_END) (err u305)) ;; Only during migration period
    
    (let ((user-balance (unwrap! (get-balance-of tx-sender) (err u2))))
      (asserts! (> user-balance u0) (err u306))
      
      ;; Auto-migrate all remaining CXLP at final rate
      (try! (migrate-to-CXG user-balance))
      (ok user-balance)
    )
  )
)

;; Helper functions
(define-read-only (get-current-epoch)
  (if (<= block-height EPOCH_1_END)
    u1
    (if (<= block-height EPOCH_2_END)
      u2
      (if (<= block-height EPOCH_3_END)
        u3
        u4
      )
    )
  )
)

(define-read-only (get-epoch-rewards (epoch uint))
  (default-to 
    { base-rate: u100, bonus-multiplier: u1000000 } ;; Default: 100 micro-CXLP per block
    (map-get? epoch-rewards { epoch: epoch })
  )
)

(define-read-only (get-loyalty-bonus (position { amount: uint, entry-block: uint, total-rewards: uint, last-claim-block: uint }))
  (let (
    (blocks-held (- block-height (get entry-block position)))
  )
    (if (>= blocks-held BLOCKS_PER_MONTH) ;; 1 month = 20% bonus
      u200000
      (if (>= blocks-held BLOCKS_PER_WEEK) ;; 1 week = 10% bonus
        u100000
        (if (>= blocks-held BLOCKS_PER_DAY) ;; 1 day = 5% bonus
          u50000
          u0
        )
      )
    )
  ))

(define-read-only (get-liquidity-position (provider principal))
  (map-get? liquidity-positions { provider: provider }))

(define-read-only (get-claimable-rewards (provider principal))
  (match (map-get? liquidity-positions { provider: provider })
    position (let (
      (blocks-since-last-claim (- block-height (get last-claim-block position)))
      (liquidity-amount (get amount position))
      (current-epoch (get-current-epoch))
      (epoch-config (get-epoch-rewards current-epoch))
      (base-rewards (* blocks-since-last-claim (get base-rate epoch-config) liquidity-amount))
      (loyalty-bonus (get-loyalty-bonus position))
    )
    (/ (* base-rewards (+ u1000000 loyalty-bonus)) u1000000))
    u0
  )
)

(define-read-only (get-migration-info)
  {
    current-epoch: (get-current-epoch),
    migration-deadline: EPOCH_4_END,
    blocks-remaining: (if (<= block-height EPOCH_4_END) (- EPOCH_4_END block-height) u0),
    total-supply: (var-get total-supply),
    total-liquidity: (var-get total-liquidity-provided)
  }
)

;; Standard transfer functions
(define-public (transfer (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (asserts! (not (var-get emergency-pause)) (err u302))
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
    (asserts! (not (var-get emergency-pause)) (err u302))
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
    (asserts! (not (var-get emergency-pause)) (err u302))
    (map-set allowances 
      { owner: tx-sender, spender: spender }
      { amount: amount }
    )
    (ok true)
  )
)

;; Internal functions
(define-private (transfer-helper (sender principal) (recipient principal) (amount uint))
  (let (
    (sender-balance (unwrap! (get-balance-of sender) (err u2)))
    (recipient-balance (unwrap! (get-balance-of recipient) (err u2)))
  )
    (map-set balances { owner: sender } { amount: (- sender-balance amount) })
    (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
    (print { event: "transfer", sender: sender, recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-private (mint-to (recipient principal) (amount uint))
  (let ((recipient-balance (unwrap! (get-balance-of recipient) (err u2))))
    (asserts! (<= (+ (var-get total-supply) amount) MAX_SUPPLY) (err u307))
    (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
    (var-set total-supply (+ (var-get total-supply) amount))
    (print { event: "mint", recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-private (burn-from (owner principal) (amount uint))
  (let ((owner-balance (unwrap! (get-balance-of owner) (err u2))))
    (asserts! (>= owner-balance amount) (err u2))
    (map-set balances { owner: owner } { amount: (- owner-balance amount) })
    (var-set total-supply (- (var-get total-supply) amount))
    (print { event: "burn", owner: owner, amount: amount })
    (ok true)
  )
)

;; Admin functions  
(define-public (set-epoch-rewards (epoch uint) (base-rate uint) (bonus-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vault)) (err u100))
    (map-set epoch-rewards { epoch: epoch } {
      base-rate: base-rate,
      bonus-multiplier: bonus-multiplier
    })
    (ok true)
  )
)

(define-public (toggle-emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get vault)) (err u100))
    (var-set emergency-pause (not (var-get emergency-pause)))
    (ok (var-get emergency-pause))
  )
)

;; Initialize epoch rewards
(map-set epoch-rewards { epoch: u1 } { base-rate: u100, bonus-multiplier: u1000000 })    ;; Epoch 1: Standard rate
(map-set epoch-rewards { epoch: u2 } { base-rate: u150, bonus-multiplier: u1100000 })    ;; Epoch 2: 50% higher, 10% bonus
(map-set epoch-rewards { epoch: u3 } { base-rate: u200, bonus-multiplier: u1250000 })    ;; Epoch 3: 100% higher, 25% bonus
 (map-set epoch-rewards { epoch: u4 } { base-rate: u200, bonus-multiplier: u1250000 })    ;; Epoch 4: align with epoch 3

;; Error codes
;; u1: invalid-amount
;; u2: insufficient-balance  
;; u3: insufficient-allowance
;; u100: unauthorized
;; u200-299: liquidity mining errors
;; u300-399: migration errors
