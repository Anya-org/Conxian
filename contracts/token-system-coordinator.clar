;; token-system-coordinator.clar
;; Central coordination contract for the enhanced Conxian token system
;; Provides unified interface and orchestrates interactions between all token subsystems

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; System component identifiers
(define-constant COMPONENT_CXD_STAKING u1)
(define-constant COMPONENT_MIGRATION_QUEUE u2)
(define-constant COMPONENT_CXVG_UTILITY u3)
(define-constant COMPONENT_EMISSION_CONTROLLER u4)
(define-constant COMPONENT_REVENUE_DISTRIBUTOR u5)
(define-constant COMPONENT_INVARIANT_MONITOR u6)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_SYSTEM_PAUSED u1001)
(define-constant ERR_COMPONENT_UNAVAILABLE u1002)
(define-constant ERR_INVALID_AMOUNT u1003)
(define-constant ERR_INITIALIZATION_FAILED u1004)
(define-constant ERR_COORDINATION_FAILED u1005)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var system-initialized bool false)
(define-data-var system-paused bool false)

;; Contract references
(define-data-var cxd-staking-contract principal .cxd-staking)
(define-data-var migration-queue-contract principal .cxlp-migration-queue)
(define-data-var cxvg-utility-contract principal .cxvg-utility)
(define-data-var emission-controller-contract principal .token-emission-controller)
(define-data-var revenue-distributor-contract principal .revenue-distributor)
(define-data-var invariant-monitor-contract principal .protocol-invariant-monitor)

;; System status tracking
(define-map component-status
  uint ;; component-id
  {
    active: bool,
    last-health-check: uint,
    error-count: uint
  })

;; Cross-system operation tracking
(define-data-var next-operation-id uint u1)
(define-map cross-system-operations
  uint ;; operation-id
  {
    operation-type: uint,
    initiator: principal,
    components-involved: (list 10 uint),
    status: uint, ;; 0=pending, 1=success, 2=failed
    timestamp: uint
  })

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (initialize-system)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get system-initialized)) (err ERR_INITIALIZATION_FAILED))
    
    ;; Initialize component status tracking
    (map-set component-status COMPONENT_CXD_STAKING { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_MIGRATION_QUEUE { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_CXVG_UTILITY { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_EMISSION_CONTROLLER { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_REVENUE_DISTRIBUTOR { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_INVARIANT_MONITOR { active: true, last-health-check: block-height, error-count: u0 })
    
    (var-set system-initialized true)
    (ok true)))

(define-public (update-contract-references 
  (cxd-staking principal) 
  (migration-queue principal) 
  (cxvg-utility principal) 
  (emission-ctrl principal) 
  (revenue-dist principal) 
  (invariant-monitor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxd-staking-contract cxd-staking)
    (var-set migration-queue-contract migration-queue)
    (var-set cxvg-utility-contract cxvg-utility)
    (var-set emission-controller-contract emission-ctrl)
    (var-set revenue-distributor-contract revenue-dist)
    (var-set invariant-monitor-contract invariant-monitor)
    (ok true)))

;; --- Unified Token Operations ---

;; Coordinated staking with governance considerations
(define-public (stake-cxd-with-governance-check (amount uint))
  (let ((operation-id (var-get next-operation-id)))
    (begin
      (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
      (asserts! (not (contract-call? .protocol-invariant-monitor is-protocol-paused)) (err ERR_SYSTEM_PAUSED))
      
      ;; Record cross-system operation
      (map-set cross-system-operations operation-id
        {
          operation-type: u1, ;; stake operation
          initiator: tx-sender,
          components-involved: (list COMPONENT_CXD_STAKING COMPONENT_INVARIANT_MONITOR),
          status: u0,
          timestamp: block-height
        })
      (var-set next-operation-id (+ operation-id u1))
      
      ;; Check governance participation for enhanced staking
      (let ((governance-boost (unwrap-panic (contract-call? .cxvg-utility get-user-governance-boost tx-sender))))
        (let ((enhanced-amount (if (> governance-boost u0)
                                 (+ amount (/ (* amount governance-boost) u10000))
                                 amount)))
          
          ;; Execute staking
          (match (contract-call? .cxd-staking stake enhanced-amount)
            success (begin
              (map-set cross-system-operations operation-id
                (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u1 }))
              (ok success))
            error (begin
              (map-set cross-system-operations operation-id
                (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u2 }))
              (err error))))))))

;; Coordinated migration with revenue distribution
(define-public (migrate-cxlp-to-cxd (amount uint))
  (let ((operation-id (var-get next-operation-id)))
    (begin
      (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
      (asserts! (not (contract-call? .protocol-invariant-monitor is-protocol-paused)) (err ERR_SYSTEM_PAUSED))
      
      ;; Record operation
      (map-set cross-system-operations operation-id
        {
          operation-type: u2, ;; migration operation
          initiator: tx-sender,
          components-involved: (list COMPONENT_MIGRATION_QUEUE COMPONENT_REVENUE_DISTRIBUTOR),
          status: u0,
          timestamp: block-height
        })
      (var-set next-operation-id (+ operation-id u1))
      
      ;; Execute migration through queue
      (match (contract-call? .cxlp-migration-queue submit-migration-intent amount tx-sender)
        success (begin
          ;; Notify revenue distributor of potential new revenue
          (try! (as-contract (contract-call? .revenue-distributor record-migration-fee (* amount u50)))) ;; 0.5% migration fee
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u1 }))
          (ok success))
        error (begin
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u2 }))
          (err error))))))

;; Coordinated governance participation with utility rewards
(define-public (participate-in-governance (proposal-id uint) (vote bool) (cxvg-amount uint))
  (let ((operation-id (var-get next-operation-id)))
    (begin
      (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
      
      ;; Record operation
      (map-set cross-system-operations operation-id
        {
          operation-type: u3, ;; governance operation
          initiator: tx-sender,
          components-involved: (list COMPONENT_CXVG_UTILITY),
          status: u0,
          timestamp: block-height
        })
      (var-set next-operation-id (+ operation-id u1))
      
      ;; Lock CXVG for governance participation
      (match (contract-call? .cxvg-utility lock-for-governance cxvg-amount u2160) ;; ~15 days
        success (begin
          ;; Record governance participation (simplified - would integrate with actual governance contract)
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u1 }))
          (ok { proposal: proposal-id, vote: vote, locked-amount: cxvg-amount }))
        error (begin
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u2 }))
          (err error))))))

;; --- System Health and Coordination ---

;; Comprehensive system health check
(define-public (run-system-health-check)
  (begin
    (asserts! (var-get system-initialized) (err ERR_INITIALIZATION_FAILED))
    
    ;; Run health checks on all components
    (let ((monitor-health (contract-call? .protocol-invariant-monitor run-health-check))
          (staking-info (contract-call? .cxd-staking get-protocol-info))
          (migration-info (contract-call? .cxlp-migration-queue get-migration-info))
          (revenue-stats (contract-call? .revenue-distributor get-protocol-revenue-stats)))
      
      ;; Update component status based on health checks
      (try! (update-component-status COMPONENT_CXD_STAKING (is-ok staking-info)))
      (try! (update-component-status COMPONENT_MIGRATION_QUEUE (is-ok migration-info)))
      (try! (update-component-status COMPONENT_REVENUE_DISTRIBUTOR (is-ok revenue-stats)))
      (try! (update-component-status COMPONENT_INVARIANT_MONITOR (is-ok monitor-health)))
      
      (ok {
        overall-health: (if (and (is-ok monitor-health) (is-ok staking-info) (is-ok migration-info) (is-ok revenue-stats)) u10000 u7000),
        monitor-status: (is-ok monitor-health),
        staking-status: (is-ok staking-info),
        migration-status: (is-ok migration-info),
        revenue-status: (is-ok revenue-stats)
      }))))

(define-private (update-component-status (component-id uint) (is-healthy bool))
  (let ((current-status (unwrap-panic (map-get? component-status component-id))))
    (map-set component-status component-id
      {
        active: is-healthy,
        last-health-check: block-height,
        error-count: (if is-healthy (get error-count current-status) (+ (get error-count current-status) u1))
      })
    (ok true)))

;; Coordinated revenue distribution
(define-public (trigger-revenue-distribution)
  (let ((operation-id (var-get next-operation-id)))
    (begin
      (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
      
      ;; Record operation
      (map-set cross-system-operations operation-id
        {
          operation-type: u4, ;; revenue distribution
          initiator: tx-sender,
          components-involved: (list COMPONENT_REVENUE_DISTRIBUTOR COMPONENT_CXD_STAKING),
          status: u0,
          timestamp: block-height
        })
      (var-set next-operation-id (+ operation-id u1))
      
      ;; Execute revenue distribution
      (match (contract-call? .revenue-distributor distribute-revenue)
        success (begin
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u1 }))
          (ok success))
        error (begin
          (map-set cross-system-operations operation-id
            (merge (unwrap-panic (map-get? cross-system-operations operation-id)) { status: u2 }))
          (err error))))))

;; --- Emergency Coordination ---

;; System-wide emergency pause
(define-public (emergency-pause-system)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    
    ;; Pause all subsystems
    (try! (as-contract (contract-call? .cxd-staking pause-contract)))
    (try! (as-contract (contract-call? .cxlp-migration-queue pause-queue)))
    (try! (as-contract (contract-call? .protocol-invariant-monitor trigger-emergency-pause u8888)))
    
    (var-set system-paused true)
    (ok true)))

;; System-wide resume
(define-public (resume-system)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (var-get system-paused) (err ERR_SYSTEM_PAUSED))
    
    ;; Check system health before resuming
    (let ((health-check (try! (run-system-health-check))))
      (asserts! (>= (get overall-health health-check) u8000) (err ERR_COORDINATION_FAILED))
      
      ;; Resume subsystems
      (try! (as-contract (contract-call? .cxd-staking unpause-contract)))
      (try! (as-contract (contract-call? .cxlp-migration-queue unpause-queue)))
      (try! (as-contract (contract-call? .protocol-invariant-monitor resume-protocol)))
      
      (var-set system-paused false)
      (ok true))))

;; --- Unified User Interface Functions ---

;; Get comprehensive user token status across all systems
(define-read-only (get-user-token-status (user principal))
  (let ((staking-info (contract-call? .cxd-staking get-user-stake-info user))
        (migration-intents (contract-call? .cxlp-migration-queue get-user-intent-info user))
        (governance-status (contract-call? .cxvg-utility get-user-governance-status user))
        (cxd-balance (unwrap-panic (contract-call? .cxd-token get-balance user)))
        (cxvg-balance (unwrap-panic (contract-call? .cxvg-token get-balance user)))
        (cxlp-balance (unwrap-panic (contract-call? .cxlp-token get-balance user)))
        (cxtr-balance (unwrap-panic (contract-call? .cxtr-token get-balance user))))
    
    {
      balances: {
        cxd: cxd-balance,
        cxvg: cxvg-balance,
        cxlp: cxlp-balance,
        cxtr: cxtr-balance
      },
      staking: staking-info,
      migration: migration-intents,
      governance: governance-status,
      system-health: (contract-call? .protocol-invariant-monitor get-protocol-health)
    }))

;; Get system-wide statistics
(define-read-only (get-system-statistics)
  (let ((staking-stats (unwrap-panic (contract-call? .cxd-staking get-protocol-info)))
        (migration-stats (unwrap-panic (contract-call? .cxlp-migration-queue get-migration-info)))
        (revenue-stats (unwrap-panic (contract-call? .revenue-distributor get-protocol-revenue-stats)))
        (health-status (contract-call? .protocol-invariant-monitor get-circuit-breaker-status)))
    
    {
      staking: staking-stats,
      migration: migration-stats,
      revenue: revenue-stats,
      system-health: health-status,
      initialized: (var-get system-initialized),
      paused: (var-get system-paused),
      total-operations: (var-get next-operation-id)
    }))

;; --- Read-Only Functions ---

(define-read-only (get-operation-info (operation-id uint))
  (map-get? cross-system-operations operation-id))

(define-read-only (get-component-status (component-id uint))
  (map-get? component-status component-id))

(define-read-only (is-system-healthy)
  (and (var-get system-initialized)
       (not (var-get system-paused))
       (not (contract-call? .protocol-invariant-monitor is-protocol-paused))))

(define-read-only (get-system-info)
  {
    initialized: (var-get system-initialized),
    paused: (var-get system-paused),
    owner: (var-get contract-owner),
    total-operations: (var-get next-operation-id),
    healthy: (is-system-healthy)
  })
