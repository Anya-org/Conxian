;; Cross-Chain Preparation Infrastructure
;; Implements Layer 2 participation aggregation and cross-chain governance
;; Prepares AutoVault for multi-chain deployment and governance scaling

(define-constant CONTRACT_VERSION u1)

;; --- Cross-Chain Constants ---
(define-constant MAX_SUPPORTED_CHAINS u10)
(define-constant MIN_CHAIN_WEIGHT_BPS u100) ;; 1% minimum weight
(define-constant MAX_CHAIN_WEIGHT_BPS u3000) ;; 30% maximum weight for any single chain
(define-constant GOVERNANCE_SYNC_INTERVAL u144) ;; 24 hours in blocks
(define-constant CROSS_CHAIN_VOTING_PERIOD u1008) ;; 7 days in blocks

;; --- Authorization ---
(define-data-var admin principal tx-sender)
(define-data-var cross-chain-oracle principal tx-sender)
(define-data-var governance-contract principal .dao-governance)

;; --- Cross-Chain State ---
(define-data-var cross-chain-enabled bool false)
(define-data-var total-registered-chains uint u0)
(define-data-var last-global-sync uint u0)
(define-data-var global-voting-power uint u0)

;; Aggregation parameters
(define-data-var l1-weight-bps uint u7000) ;; 70% weight for L1 (Stacks)
(define-data-var total-l2-weight-bps uint u3000) ;; 30% total weight for all L2s
(define-data-var min-participation-threshold uint u1000) ;; 10% minimum for cross-chain proposals

;; --- Chain Registry ---
(define-map chain-registry
  { chain-id: uint }
  {
    chain-name: (string-ascii 32),
    contract-address: (string-ascii 64),
    weight-bps: uint,
    active: bool,
    last-sync: uint,
    total-participants: uint,
    total-voting-power: uint,
    governance-contract: (string-ascii 64),
    bridge-contract: (string-ascii 64)
  }
)

;; Cross-chain participation snapshots
(define-map participation-snapshots
  { chain-id: uint, snapshot-id: uint }
  {
    participants: uint,
    voting-power: uint,
    proposals-voted: uint,
    timestamp: uint,
    block-height: uint,
    participation-rate: uint
  }
)

;; Global governance proposals with cross-chain participation
(define-map cross-chain-proposals
  { proposal-id: uint }
  {
    title: (string-ascii 128),
    created-block: uint,
    voting-deadline: uint,
    l1-votes-for: uint,
    l1-votes-against: uint,
    l2-aggregated-for: uint,
    l2-aggregated-against: uint,
    total-voting-power: uint,
    status: (string-ascii 32),
    cross-chain-enabled: bool
  }
)

;; Chain-specific voting results for cross-chain proposals
(define-map chain-voting-results
  { proposal-id: uint, chain-id: uint }
  {
    votes-for: uint,
    votes-against: uint,
    abstain: uint,
    voting-power: uint,
    participation-rate: uint,
    finalized: bool,
    sync-block: uint
  }
)

;; --- Administrative Functions ---

(define-public (register-chain 
  (p-chain-id uint)
  (chain-name (string-ascii 32))
  (contract-address (string-ascii 64))
  (weight-bps uint)
  (governance-contract-id (string-ascii 64))
  (bridge-contract (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (< (var-get total-registered-chains) MAX_SUPPORTED_CHAINS) (err u101))
    (asserts! (and (>= weight-bps MIN_CHAIN_WEIGHT_BPS) (<= weight-bps MAX_CHAIN_WEIGHT_BPS)) (err u102))
  (asserts! (is-none (map-get? chain-registry { chain-id: p-chain-id })) (err u103))
    
    ;; Verify total L2 weight doesn't exceed limit
    (let ((current-l2-weight (calculate-total-l2-weight)))
      (asserts! (<= (+ current-l2-weight weight-bps) (var-get total-l2-weight-bps)) (err u104)))
    
  (map-set chain-registry { chain-id: p-chain-id } {
      chain-name: chain-name,
      contract-address: contract-address,
      weight-bps: weight-bps,
      active: true,
      last-sync: block-height,
      total-participants: u0,
      total-voting-power: u0,
  governance-contract: governance-contract-id,
      bridge-contract: bridge-contract
    })
    
    (var-set total-registered-chains (+ (var-get total-registered-chains) u1))
    
    (print {
      event: "chain-registered",
  chain-id: p-chain-id,
      chain-name: chain-name,
      weight-bps: weight-bps,
      total-chains: (var-get total-registered-chains)
    })
  (ok p-chain-id)))

;; --- Cross-Chain Participation Tracking ---

(define-public (record-l2-participation-snapshot
  (p-chain-id uint)
  (snapshot-id uint)
  (participants uint)
  (voting-power uint)
  (proposals-voted uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (var-get cross-chain-oracle))) (err u105))
  (let ((chain-info (unwrap! (map-get? chain-registry { chain-id: p-chain-id }) (err u106))))
      (asserts! (get active chain-info) (err u107))
      
      (let ((participation-rate (if (> (get total-participants chain-info) u0)
                                  (/ (* participants u10000) (get total-participants chain-info))
                                  u0)))
        
  (map-set participation-snapshots { chain-id: p-chain-id, snapshot-id: snapshot-id } {
          participants: participants,
          voting-power: voting-power,
          proposals-voted: proposals-voted,
          timestamp: block-height,
          block-height: block-height,
          participation-rate: participation-rate
        })
        
        ;; Update chain registry with latest data
  (map-set chain-registry { chain-id: p-chain-id } 
          (merge chain-info {
            total-participants: participants,
            total-voting-power: voting-power,
            last-sync: block-height
          }))
        
  ;; Forward to enhanced analytics (temporarily disabled pending analytics stabilization)
  ;; (try! (contract-call? .enhanced-analytics record-l2-participation 
  ;;                      chain-id participants voting-power (get weight-bps chain-info)))
        
        (print {
          event: "l2-participation-recorded",
          chain-id: p-chain-id,
          snapshot-id: snapshot-id,
          participants: participants,
          voting-power: voting-power,
          participation-rate: participation-rate
        })
        (ok snapshot-id)))))

;; --- Cross-Chain Governance ---

(define-public (create-cross-chain-proposal
  (proposal-id uint)
  (title (string-ascii 128))
  (voting-period-blocks uint))
  (begin
    (asserts! (var-get cross-chain-enabled) (err u108))
    (asserts! (or (is-eq tx-sender (var-get admin)) 
                  (is-eq tx-sender (var-get governance-contract))) (err u109))
    (asserts! (is-none (map-get? cross-chain-proposals { proposal-id: proposal-id })) (err u110))
    
    (let ((voting-deadline (+ block-height voting-period-blocks))
          (total-power (calculate-total-voting-power)))
      
      (map-set cross-chain-proposals { proposal-id: proposal-id } {
        title: title,
        created-block: block-height,
        voting-deadline: voting-deadline,
        l1-votes-for: u0,
        l1-votes-against: u0,
        l2-aggregated-for: u0,
        l2-aggregated-against: u0,
        total-voting-power: total-power,
        status: "active",
        cross-chain-enabled: true
      })
      
      (print {
        event: "cross-chain-proposal-created",
        proposal-id: proposal-id,
        title: title,
        voting-deadline: voting-deadline,
        total-voting-power: total-power
      })
      (ok proposal-id))))

;; Record voting results from a specific chain
(define-public (record-chain-voting-result
  (proposal-id uint)
  (p-chain-id uint)
  (votes-for uint)
  (votes-against uint)
  (abstain uint)
  (voting-power uint)
  (participation-rate uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (var-get cross-chain-oracle))) (err u111))
    
  (let ((proposal (unwrap! (map-get? cross-chain-proposals { proposal-id: proposal-id }) (err u112)))
      (chain-info (unwrap! (map-get? chain-registry { chain-id: p-chain-id }) (err u113))))
      
      (asserts! (get active chain-info) (err u114))
      (asserts! (< block-height (get voting-deadline proposal)) (err u115)) ;; Still in voting period
      
  (map-set chain-voting-results { proposal-id: proposal-id, chain-id: p-chain-id } {
        votes-for: votes-for,
        votes-against: votes-against,
        abstain: abstain,
        voting-power: voting-power,
        participation-rate: participation-rate,
        finalized: true,
        sync-block: block-height
      })
      
      (print {
        event: "chain-voting-result-recorded",
        proposal-id: proposal-id,
  chain-id: p-chain-id,
        votes-for: votes-for,
        votes-against: votes-against,
        participation-rate: participation-rate
      })
      (ok true))))

;; Aggregate cross-chain voting results
(define-public (aggregate-cross-chain-votes (proposal-id uint))
  (begin
    (asserts! (var-get cross-chain-enabled) (err u116))
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (var-get cross-chain-oracle))) (err u117))
    
    (let ((proposal (unwrap! (map-get? cross-chain-proposals { proposal-id: proposal-id }) (err u118))))
      (asserts! (>= block-height (get voting-deadline proposal)) (err u119)) ;; Voting must be finished
      
      (let ((aggregated-results (aggregate-voting-results proposal-id)))
        (let ((total-for (+ (get l1-votes-for proposal) (get l2-for aggregated-results)))
              (total-against (+ (get l1-votes-against proposal) (get l2-against aggregated-results)))
              (total-power (get total-voting-power proposal)))
          
          ;; Update proposal with final results
          (map-set cross-chain-proposals { proposal-id: proposal-id }
            (merge proposal {
              l2-aggregated-for: (get l2-for aggregated-results),
              l2-aggregated-against: (get l2-against aggregated-results),
              status: (if (> total-for total-against) "passed" "failed")
            }))
          
          ;; Check if minimum participation threshold is met
          (let ((total-votes (+ total-for total-against))
                (participation-rate (/ (* total-votes u10000) total-power)))
            
            (asserts! (>= participation-rate (var-get min-participation-threshold)) (err u120))
            
            (print {
              event: "cross-chain-votes-aggregated",
              proposal-id: proposal-id,
              total-for: total-for,
              total-against: total-against,
              participation-rate: participation-rate,
              status: (get status (unwrap-panic (map-get? cross-chain-proposals { proposal-id: proposal-id })))
            })
            (ok { for: total-for, against: total-against, participation: participation-rate })))))))

;; --- Synchronization Functions ---

(define-public (sync-global-participation)
  (begin
    (asserts! (var-get cross-chain-enabled) (err u121))
    (asserts! (>= (- block-height (var-get last-global-sync)) GOVERNANCE_SYNC_INTERVAL) (err u122))
    ;; Temporarily decoupled from governance-metrics: use placeholder L1 participation (u5000 = 50%)
    (let ((l1-participation u5000)
          (aggregated-l2 (calculate-aggregated-l2-participation)))
      (let ((global-participation (calculate-weighted-participation l1-participation aggregated-l2)))
        (var-set global-voting-power global-participation)
        (var-set last-global-sync block-height)
        ;; (try! (contract-call? .enhanced-analytics calculate-aggregated-participation)) ;; disabled
        (print {
          event: "global-participation-synced",
          l1-participation: l1-participation,
          l2-aggregated: aggregated-l2,
          global-participation: global-participation,
          sync-block: block-height
        })
        (ok global-participation)))))

;; --- Helper Functions ---

(define-private (calculate-total-l2-weight)
  ;; Sum all registered L2 chain weights
  (fold sum-chain-weights (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0))

(define-private (sum-chain-weights (p-chain-id uint) (acc uint))
  (match (map-get? chain-registry { chain-id: p-chain-id })
    chain-info (+ acc (get weight-bps chain-info))
    acc))

(define-private (calculate-total-voting-power)
  ;; Calculate total voting power across all chains (placeholder without governance-metrics call)
  (calculate-total-l2-voting-power))

(define-private (calculate-total-l2-voting-power)
  ;; Sum voting power from all active L2 chains
  (fold sum-l2-voting-power (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0))

(define-private (sum-l2-voting-power (p-chain-id uint) (acc uint))
  (match (map-get? chain-registry { chain-id: p-chain-id })
    chain-info (if (get active chain-info) 
                  (+ acc (get total-voting-power chain-info)) 
                  acc)
    acc))

(define-private (aggregate-voting-results (proposal-id uint))
  ;; Aggregate L2 voting results weighted by chain weight
  (fold aggregate-chain-votes (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
        { l2-for: u0, l2-against: u0 }))

(define-private (aggregate-chain-votes 
  (p-chain-id uint) 
  (acc { l2-for: uint, l2-against: uint }))
  (match (map-get? chain-voting-results { proposal-id: u0, chain-id: p-chain-id }) ;; Using u0 as placeholder
    voting-result 
  (match (map-get? chain-registry { chain-id: p-chain-id })
        chain-info
          (let ((weight (get weight-bps chain-info))
                (weighted-for (/ (* (get votes-for voting-result) weight) u10000))
                (weighted-against (/ (* (get votes-against voting-result) weight) u10000)))
            { l2-for: (+ (get l2-for acc) weighted-for),
              l2-against: (+ (get l2-against acc) weighted-against) })
        acc)
    acc))

(define-private (calculate-aggregated-l2-participation)
  ;; Calculate weighted average of L2 participation
  (fold sum-weighted-l2-participation (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0))

(define-private (sum-weighted-l2-participation (p-chain-id uint) (acc uint))
  (match (map-get? chain-registry { chain-id: p-chain-id })
    chain-info 
      (if (get active chain-info)
  (let ((latest-snapshot (get-latest-participation-snapshot p-chain-id))
              (weight (get weight-bps chain-info)))
          (+ acc (/ (* latest-snapshot weight) u10000)))
        acc)
    acc))

(define-private (get-latest-participation-snapshot (p-chain-id uint))
  ;; Get the most recent participation rate for a chain
  u5000) ;; Placeholder - would query latest snapshot

(define-private (calculate-weighted-participation (l1-participation uint) (l2-aggregated uint))
  ;; Calculate global participation weighted by L1 and L2 weights
  (+ (/ (* l1-participation (var-get l1-weight-bps)) u10000)
     (/ (* l2-aggregated (var-get total-l2-weight-bps)) u10000)))

;; --- Administrative Functions ---

(define-public (set-cross-chain-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u124))
    (var-set cross-chain-enabled enabled)
    (ok true)))

(define-public (set-chain-weights (l1-weight uint) (l2-total-weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u125))
    (asserts! (is-eq (+ l1-weight l2-total-weight) u10000) (err u126)) ;; Must sum to 100%
    (var-set l1-weight-bps l1-weight)
    (var-set total-l2-weight-bps l2-total-weight)
    (ok true)))

(define-public (update-chain-status (p-chain-id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u127))
  (let ((chain-info (unwrap! (map-get? chain-registry { chain-id: p-chain-id }) (err u128))))
  (map-set chain-registry { chain-id: p-chain-id }
        (merge chain-info { active: active }))
      (ok true))))

;; --- Read-Only Functions ---

(define-read-only (get-cross-chain-status)
  {
    enabled: (var-get cross-chain-enabled),
    total-chains: (var-get total-registered-chains),
    l1-weight: (var-get l1-weight-bps),
    l2-total-weight: (var-get total-l2-weight-bps),
    global-voting-power: (var-get global-voting-power),
    last-sync: (var-get last-global-sync)
  })

(define-read-only (get-chain-info (p-chain-id uint))
  (map-get? chain-registry { chain-id: p-chain-id }))

(define-read-only (get-participation-snapshot (p-chain-id uint) (snapshot-id uint))
  (map-get? participation-snapshots { chain-id: p-chain-id, snapshot-id: snapshot-id }))

(define-read-only (get-cross-chain-proposal (proposal-id uint))
  (map-get? cross-chain-proposals { proposal-id: proposal-id }))

(define-read-only (get-chain-voting-result (proposal-id uint) (p-chain-id uint))
  (map-get? chain-voting-results { proposal-id: proposal-id, chain-id: p-chain-id }))

(define-read-only (calculate-global-participation)
  ;; Decoupled version returns weighted participation using placeholder L1 participation (u5000)
  (ok (calculate-weighted-participation u5000 (calculate-aggregated-l2-participation))))

;; Error codes
;; u100: unauthorized
;; u101: max-chains-exceeded  
;; u102: invalid-chain-weight
;; u103: chain-already-registered
;; u104: total-l2-weight-exceeded
;; u105: unauthorized-oracle
;; u106: chain-not-found
;; u107: chain-inactive
;; u108: cross-chain-disabled
;; u109: unauthorized-governance
;; u110: proposal-already-exists
;; u111: unauthorized-voting-record
;; u112: proposal-not-found
;; u113: chain-not-registered
;; u114: chain-not-active
;; u115: voting-period-not-ended
;; u116: cross-chain-voting-disabled
;; u117: unauthorized-aggregation
;; u118: proposal-not-found-for-aggregation
;; u119: voting-still-active
;; u120: insufficient-participation
;; u121: sync-disabled
;; u122: sync-too-frequent
;; u123: l1-participation-fetch-failed
;; u124: unauthorized-enable-toggle
;; u125: unauthorized-weight-setting
;; u126: weights-must-sum-to-100-percent
;; u127: unauthorized-status-update
;; u128: chain-not-found-for-status-update
