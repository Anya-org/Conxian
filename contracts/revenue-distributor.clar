;; revenue-distributor.clar
;; Comprehensive revenue distribution system connecting vaults to token holders
;; Routes protocol fees: 80% to xCXD stakers, 20% to treasury/reserves

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Revenue split configuration (basis points)
(define-constant XCXD_SPLIT_BPS u8000) ;; 80% to xCXD stakers
(define-constant TREASURY_SPLIT_BPS u1500) ;; 15% to treasury
(define-constant RESERVE_SPLIT_BPS u500) ;; 5% to insurance reserve

;; Fee types for tracking
(define-constant FEE_TYPE_VAULT_PERFORMANCE u1)
(define-constant FEE_TYPE_VAULT_MANAGEMENT u2)
(define-constant FEE_TYPE_DEX_TRADING u3)
(define-constant FEE_TYPE_MIGRATION_FEE u4)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u800)
(define-constant ERR_INVALID_AMOUNT u801)
(define-constant ERR_INVALID_FEE_TYPE u802)
(define-constant ERR_DISTRIBUTION_FAILED u803)
(define-constant ERR_INSUFFICIENT_BALANCE u804)
(define-constant ERR_INVALID_TOKEN u805)
(define-constant ERR_BUYBACK_FAILED u806)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var treasury-address principal tx-sender)
(define-data-var reserve-address principal tx-sender)

;; Contract references
(define-data-var xcxd-staking-contract principal .cxd-staking)
(define-data-var cxd-token-contract principal .cxd-token)

;; Authorized fee collectors (vaults, DEX, etc.)
(define-map authorized-collectors principal bool)

;; --- Revenue Accounting ---
(define-data-var total-revenue-collected uint u0)
(define-data-var total-revenue-distributed uint u0)
(define-data-var current-distribution-epoch uint u1)

;; Revenue tracking by source and type
(define-map revenue-by-source
  { collector: principal, epoch: uint }
  { total-amount: uint, fee-type: uint })

;; Revenue tracking by fee type
(define-map revenue-by-type
  { fee-type: uint, epoch: uint }
  { total-amount: uint, distributions: uint })

;; Pending distributions (accumulated before batch distribution)
(define-map pending-distributions
  principal ;; revenue-token
  { total-pending: uint, last-distribution: uint })

;; Distribution history for auditing
(define-map distribution-history
  uint ;; epoch
  {
    total-distributed: uint,
    xcxd-amount: uint,
    treasury-amount: uint,
    reserve-amount: uint,
    timestamp: uint,
    revenue-token: principal
  })

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-addresses (treasury principal) (reserve principal) (xcxd-staking principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set treasury-address treasury)
    (var-set reserve-address reserve)
    (var-set xcxd-staking-contract xcxd-staking)
    (ok true)))

(define-public (authorize-collector (collector principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (if authorized
      (map-set authorized-collectors collector true)
      (map-delete authorized-collectors collector))
    (ok true)))

;; --- Revenue Collection ---

;; Collect revenue from authorized sources (vaults, DEX, etc.)
(define-public (collect-revenue (amount uint) (revenue-token <ft-trait>) (fee-type uint))
  (let ((collector tx-sender)
        (current-epoch (var-get current-distribution-epoch))
        (revenue-token-principal (contract-of revenue-token)))
    (begin
      (asserts! (default-to false (map-get? authorized-collectors collector)) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= fee-type u4) (err ERR_INVALID_FEE_TYPE))
      
      ;; Transfer revenue to this contract
      (try! (contract-call? revenue-token transfer amount collector (as-contract tx-sender) none))
      
      ;; Update tracking
      (var-set total-revenue-collected (+ (var-get total-revenue-collected) amount))
      
      ;; Track by source
      (let ((source-data (default-to { total-amount: u0, fee-type: fee-type }
                                    (map-get? revenue-by-source { collector: collector, epoch: current-epoch }))))
        (map-set revenue-by-source 
          { collector: collector, epoch: current-epoch }
          (merge source-data { total-amount: (+ (get total-amount source-data) amount) })))
      
      ;; Track by fee type
      (let ((type-data (default-to { total-amount: u0, distributions: u0 }
                                  (map-get? revenue-by-type { fee-type: fee-type, epoch: current-epoch }))))
        (map-set revenue-by-type
          { fee-type: fee-type, epoch: current-epoch }
          (merge type-data { total-amount: (+ (get total-amount type-data) amount) })))
      
      ;; Add to pending distributions
      (let ((pending-data (default-to { total-pending: u0, last-distribution: u0 }
                                     (map-get? pending-distributions revenue-token-principal))))
        (map-set pending-distributions revenue-token-principal
          (merge pending-data { total-pending: (+ (get total-pending pending-data) amount) })))
      
      (ok { epoch: current-epoch, amount: amount, fee-type: fee-type }))))

;; --- Revenue Distribution ---

;; Distribute accumulated revenue using buyback-and-make for CXD
(define-public (distribute-revenue (revenue-token <ft-trait>))
  (let ((revenue-token-principal (contract-of revenue-token))
        (current-epoch (var-get current-distribution-epoch))
        (pending-data (unwrap! (map-get? pending-distributions revenue-token-principal) (err ERR_INSUFFICIENT_BALANCE)))
        (total-amount (get total-pending pending-data)))
    (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
      (asserts! (> total-amount u0) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Calculate splits
      (let ((xcxd-amount (/ (* total-amount XCXD_SPLIT_BPS) u10000))
            (treasury-amount (/ (* total-amount TREASURY_SPLIT_BPS) u10000))
            (reserve-amount (/ (* total-amount RESERVE_SPLIT_BPS) u10000)))
        
        ;; If revenue token is not CXD, perform buyback-and-make
        (if (is-eq revenue-token-principal (var-get cxd-token-contract))
          ;; Direct CXD distribution
          (begin
            (try! (as-contract (contract-call? .cxd-staking distribute-revenue xcxd-amount .cxd-token)))
            (try! (as-contract (contract-call? revenue-token transfer treasury-amount (as-contract tx-sender) (var-get treasury-address) none)))
            (try! (as-contract (contract-call? revenue-token transfer reserve-amount (as-contract tx-sender) (var-get reserve-address) none))))
          ;; Buyback CXD with revenue token, then distribute
          (begin
            ;; TODO: Integrate with DEX for buyback mechanism
            ;; For now, send all to treasury to manually handle buyback
            (try! (as-contract (contract-call? revenue-token transfer total-amount (as-contract tx-sender) (var-get treasury-address) none)))))
        
        ;; Update distribution tracking
        (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) total-amount))
        (var-set current-distribution-epoch (+ current-epoch u1))
        
        ;; Record distribution history
        (map-set distribution-history current-epoch
          {
            total-distributed: total-amount,
            xcxd-amount: xcxd-amount,
            treasury-amount: treasury-amount,
            reserve-amount: reserve-amount,
            timestamp: block-height,
            revenue-token: revenue-token-principal
          })
        
        ;; Clear pending distributions
        (map-set pending-distributions revenue-token-principal
          { total-pending: u0, last-distribution: block-height })
        
        (ok { 
          epoch: current-epoch,
          total-distributed: total-amount,
          xcxd-share: xcxd-amount,
          treasury-share: treasury-amount,
          reserve-share: reserve-amount
        })))))

;; Emergency distribution bypass for specific scenarios
(define-public (emergency-distribute (revenue-token <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (try! (as-contract (contract-call? revenue-token transfer amount (as-contract tx-sender) recipient none)))
    (ok amount)))

;; --- Revenue Path Integration ---

;; Called by vault contracts to report fee collection
(define-public (report-vault-fees (performance-fee uint) (management-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    
    (let ((total-fees (+ performance-fee management-fee)))
      (if (> performance-fee u0)
        (try! (collect-revenue performance-fee fee-token FEE_TYPE_VAULT_PERFORMANCE))
        (ok true))
      
      (if (> management-fee u0)
        (try! (collect-revenue management-fee fee-token FEE_TYPE_VAULT_MANAGEMENT))
        (ok true))
      
      (ok total-fees))))

;; Called by DEX contracts to report trading fees
(define-public (report-dex-fees (trading-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    (if (> trading-fee u0)
      (try! (collect-revenue trading-fee fee-token FEE_TYPE_DEX_TRADING))
      (ok u0))))

;; Called by migration system to report migration fees
(define-public (report-migration-fees (migration-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    (if (> migration-fee u0)
      (try! (collect-revenue migration-fee fee-token FEE_TYPE_MIGRATION_FEE))
      (ok u0))))

;; --- Buyback Mechanism (Future Integration) ---

;; Interface for DEX integration to perform buyback-and-make
(define-public (execute-buyback (revenue-amount uint) (revenue-token <ft-trait>) (min-cxd-out uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; TODO: Integrate with DEX router for optimal buyback path
    ;; This is a placeholder for future DEX integration
    (ok min-cxd-out)))

;; --- Read-Only Functions ---

(define-read-only (get-pending-distributions (revenue-token principal))
  (map-get? pending-distributions revenue-token))

(define-read-only (get-revenue-by-source (collector principal) (epoch uint))
  (map-get? revenue-by-source { collector: collector, epoch: epoch }))

(define-read-only (get-revenue-by-type (fee-type uint) (epoch uint))
  (map-get? revenue-by-type { fee-type: fee-type, epoch: epoch }))

(define-read-only (get-distribution-history (epoch uint))
  (map-get? distribution-history epoch))

(define-read-only (is-authorized-collector (collector principal))
  (default-to false (map-get? authorized-collectors collector)))

(define-read-only (get-revenue-splits)
  {
    xcxd-split-bps: XCXD_SPLIT_BPS,
    treasury-split-bps: TREASURY_SPLIT_BPS,
    reserve-split-bps: RESERVE_SPLIT_BPS
  })

(define-read-only (get-protocol-revenue-stats)
  {
    total-collected: (var-get total-revenue-collected),
    total-distributed: (var-get total-revenue-distributed),
    current-epoch: (var-get current-distribution-epoch),
    pending-distribution: (get total-pending (default-to { total-pending: u0, last-distribution: u0 } 
                                                         (map-get? pending-distributions (var-get cxd-token-contract)))),
    treasury-address: (var-get treasury-address),
    reserve-address: (var-get reserve-address),
    xcxd-staking-contract: (var-get xcxd-staking-contract)
  })

;; Get comprehensive revenue report for specific epoch
(define-read-only (get-epoch-revenue-report (epoch uint))
  {
    distribution-info: (get-distribution-history epoch),
    vault-performance: (get-revenue-by-type FEE_TYPE_VAULT_PERFORMANCE epoch),
    vault-management: (get-revenue-by-type FEE_TYPE_VAULT_MANAGEMENT epoch),
    dex-trading: (get-revenue-by-type FEE_TYPE_DEX_TRADING epoch),
    migration-fees: (get-revenue-by-type FEE_TYPE_MIGRATION_FEE epoch)
  })

;; Calculate theoretical APY for xCXD staking based on recent revenue
(define-read-only (estimate-xcxd-apy (lookback-epochs uint))
  (let ((current-epoch (var-get current-distribution-epoch))
        (total-recent-revenue u0)) ;; TODO: Calculate from recent epochs
    ;; Placeholder calculation - requires historical analysis
    (ok u500))) ;; 5% placeholder APY
