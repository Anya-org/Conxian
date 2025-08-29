;; Enhanced Governance Token with Migration and Revenue Sharing
;; Implements CXG tokenomics with LP token migration and DAO revenue distribution

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant TOKEN_NAME "Conxian Governance")
(define-constant TOKEN_SYMBOL "CXG")
(define-constant TOKEN_DECIMALS u6)
(define-constant MAX_SUPPLY u100000000000000) ;; 100M CXG total supply

;; Migration epochs - 4-year schedule
(define-constant EPOCH_1_END u52560) ;; ~1 year
(define-constant EPOCH_2_END u105120) ;; ~2 years
(define-constant EPOCH_3_END u157680) ;; ~3 years
(define-constant EPOCH_4_END u210240) ;; ~4 years (final migration)

(define-constant TOTAL_MIGRATABLE_CXLP u50000000000000) ;; 50M CXLP

;; Revenue sharing
(define-constant REVENUE_SHARE_BPS u8000) ;; 80% to governance holders
(define-constant TREASURY_RESERVE_BPS u2000) ;; 20% to treasury

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var dao-governance principal .dao-governance)
(define-data-var vault principal .vault)
(define-data-var migration-enabled bool true)
(define-data-var current-epoch uint u1)
(define-data-var founder-reallocation-enabled bool false)

;; Migration tracking
(define-data-var migrated-CXTR uint u0)
(define-data-var migrated-CXLP uint u0)
(define-data-var total-revenue-distributed uint u0)

;; Maps
(define-map balances { owner: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })

;; CXLP token migration tracking
(define-map CXLP-migration-rate { epoch: uint } { CXG-per-CXLP: uint })
(define-map revenue-snapshots { epoch: uint } { 
  total-revenue: uint, 
  CXG-supply: uint,
  revenue-per-token: uint 
})

;; Revenue claims
(define-map revenue-claims { holder: principal, epoch: uint } { claimed: bool })

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

;; Migration functions
(define-public (migrate-CXTR (amount uint))
  (begin
    (asserts! (var-get migration-enabled) (err u301))
    (asserts! (<= block-height EPOCH_4_END) (err u302))
    
    ;; Burn CXTR and mint CXG at 1:1 ratio
    (unwrap! (contract-call? .creator-token burn amount) (err u303))
    (try! (mint-to tx-sender amount))
    (var-set migrated-CXTR (+ (var-get migrated-CXTR) amount))
    
    (print { event: "CXTR-migration", user: tx-sender, amount: amount })
    (ok amount)
  )
)

(define-public (migrate-CXLP (amount uint))
  (begin
    (asserts! (var-get migration-enabled) (err u301))
    (asserts! (<= block-height EPOCH_4_END) (err u302))
    
    (let (
      (current-epoch-num (var-get current-epoch))
      (migration-rate (get-CXLP-migration-rate current-epoch-num))
      (CXG-amount (/ (* amount migration-rate) u1000000)) ;; Rate in micro-units
    )
      ;; Burn CXLP and mint CXG at calculated rate
      ;; (unwrap! (contract-call? .CXLP-token burn amount) (err u304))
      (try! (mint-to tx-sender CXG-amount))
      (var-set migrated-CXLP (+ (var-get migrated-CXLP) amount))
      
      (print { 
        event: "CXLP-migration", 
        user: tx-sender, 
        CXLP-amount: amount,
        CXG-amount: CXG-amount,
        epoch: current-epoch-num
      })
      (ok CXG-amount)
    )
  )
)

;; Revenue distribution
(define-public (distribute-epoch-revenue (total-revenue uint))
  (begin
    (asserts! (is-eq tx-sender (var-get vault)) (err u100))
    
    (let (
      (current-epoch-num (var-get current-epoch))
      (current-supply (var-get total-supply))
      (revenue-per-token (/ (* total-revenue u1000000) current-supply)) ;; Micro-units
    )
      (map-set revenue-snapshots { epoch: current-epoch-num } {
        total-revenue: total-revenue,
        CXG-supply: current-supply,
        revenue-per-token: revenue-per-token
      })
      
      (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) total-revenue))
      
      (print {
        event: "revenue-distribution",
        epoch: current-epoch-num,
        total-revenue: total-revenue,
        revenue-per-token: revenue-per-token
      })
      (ok true)
    )
  )
)

(define-public (claim-revenue (epoch uint))
  (let (
    (user-balance (unwrap! (get-balance-of tx-sender) (err u200)))
    (revenue-snapshot (unwrap! (map-get? revenue-snapshots { epoch: epoch }) (err u201)))
    (already-claimed (default-to false (get claimed (map-get? revenue-claims { holder: tx-sender, epoch: epoch }))))
  )
    (asserts! (not already-claimed) (err u202))
    (asserts! (> user-balance u0) (err u203))
    
    (let (
      (revenue-per-token (get revenue-per-token revenue-snapshot))
      (user-revenue (/ (* user-balance revenue-per-token) u1000000))
    )
      (map-set revenue-claims { holder: tx-sender, epoch: epoch } { claimed: true })
      
      ;; Transfer revenue from treasury/vault
      (unwrap! (as-contract (contract-call? .vault transfer-revenue tx-sender user-revenue)) (err u204))
      
      (print {
        event: "revenue-claimed",
        user: tx-sender,
        epoch: epoch,
        amount: user-revenue
      })
      (ok user-revenue)
    )
  )
)

;; Epoch management
(define-private (calculate-migration-rate (epoch uint) (migrated-CXLP-total uint))
  (let
    ((remaining-ratio (/ (* (- TOTAL_MIGRATABLE_CXLP migrated-CXLP-total) u10000) TOTAL_MIGRATABLE_CXLP)))
    (if (is-eq epoch u2)
      (+ u1100000 (/ (* u200000 remaining-ratio) u10000)) ;; 1.1 to 1.3
      (if (is-eq epoch u3)
        (+ u1300000 (/ (* u300000 remaining-ratio) u10000)) ;; 1.3 to 1.6
        (if (is-eq epoch u4)
          (+ u1600000 (/ (* u400000 remaining-ratio) u10000)) ;; 1.6 to 2.0
          u1000000 ;; Default for epoch 1
        )
      )
    )
  )
)

(define-public (advance-epoch)
  (begin
    (let ((current-epoch-num (var-get current-epoch))
          (new-epoch (+ (var-get current-epoch) u1)))

      (asserts! (<= new-epoch u4) (err u305)) ;; Max 4 epochs

      ;; Ensure epoch can only be advanced after it has ended
      (if (is-eq current-epoch-num u1)
        (asserts! (>= block-height EPOCH_1_END) (err u307))
        (if (is-eq current-epoch-num u2)
          (asserts! (>= block-height EPOCH_2_END) (err u307))
          (if (is-eq current-epoch-num u3)
            (asserts! (>= block-height EPOCH_3_END) (err u307))
            true ;; epoch 4 cannot be advanced
          )
        )
      )

      ;; Update CXLP migration rate based on dynamic formula
      (let ((new-rate (calculate-migration-rate new-epoch (var-get migrated-CXLP))))
        (map-set CXLP-migration-rate { epoch: new-epoch } { CXG-per-CXLP: new-rate }))
      
      (var-set current-epoch new-epoch)
      
      ;; Disable migration after epoch 4
      (if (is-eq new-epoch u4)
        (var-set migration-enabled false)
        true
      )
      
      (print { event: "epoch-advanced", new-epoch: new-epoch })
      (ok new-epoch)
    )
  )
)

;; Helper functions
(define-read-only (get-CXLP-migration-rate (epoch uint))
  (default-to u1000000 (get CXG-per-CXLP (map-get? CXLP-migration-rate { epoch: epoch }))) ;; Default 1:1
)

(define-read-only (get-migration-status)
  {
    enabled: (var-get migration-enabled),
    current-epoch: (var-get current-epoch),
    migrated-CXTR: (var-get migrated-CXTR),
    migrated-CXLP: (var-get migrated-CXLP),
    blocks-remaining: (if (<= block-height EPOCH_4_END) (- EPOCH_4_END block-height) u0)
  }
)

(define-read-only (get-epoch-end-block (epoch uint))
  (ok (if (is-eq epoch u1) EPOCH_1_END
    (if (is-eq epoch u2) EPOCH_2_END
      (if (is-eq epoch u3) EPOCH_3_END
        (if (is-eq epoch u4) EPOCH_4_END
          u0
        )
      )
    )
  ))
)

(define-read-only (get-claimable-revenue (user principal) (epoch uint))
  (let (
    (user-balance (unwrap-panic (get-balance-of user)))
    (revenue-snapshot (map-get? revenue-snapshots { epoch: epoch }))
    (already-claimed (default-to false (get claimed (map-get? revenue-claims { holder: user, epoch: epoch }))))
  )
  (match revenue-snapshot
    snapshot (if already-claimed
      u0
      (/ (* user-balance (get revenue-per-token snapshot)) u1000000)
    )
    u0
  ))
)

;; Standard transfer functions
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
    (asserts! (<= (+ (var-get total-supply) amount) MAX_SUPPLY) (err u306))
    (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
    (var-set total-supply (+ (var-get total-supply) amount))
    (print { event: "mint", recipient: recipient, amount: amount })
    (ok true)
  )
)

;; Admin functions
(define-public (set-dao-governance (new-dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set dao-governance new-dao)
    (ok true)
  )
)

(define-public (enable-founder-reallocation)
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set founder-reallocation-enabled true)
    (print { event: "founder-reallocation-enabled" })
    (ok true)
  )
)

;; Errors
;; u1: invalid-amount
;; u2: insufficient-balance  
;; u3: insufficient-allowance
;; u100: unauthorized
;; u200-299: revenue claim errors
;; u300-399: migration errors
;; u307: epoch-not-ended
