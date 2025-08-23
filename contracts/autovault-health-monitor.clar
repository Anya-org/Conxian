;; AutoVault Enhanced Health Monitoring System
;; Advanced health monitoring with wallet alerts for testnet and DAO notifications for mainnet

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_VERSION "1.0.0-nakamoto")
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_INVALID_ALERT u402)
(define-constant ERR_ALERT_NOT_FOUND u403)
(define-constant ERR_INVALID_THRESHOLD u404)
(define-constant ERR_SYSTEM_PAUSED u405)

;; Alert severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Network detection constants
(define-constant TESTNET_NETWORK u1)
(define-constant MAINNET_NETWORK u2)

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var deployer-address principal tx-sender)
(define-data-var dao-governance-contract (optional principal) none)
(define-data-var health-monitoring-enabled bool true)
(define-data-var alert-counter uint u0)
(define-data-var last-health-check uint u0)
(define-data-var system-health-score uint u100) ;; 0-100 scale
(define-data-var network-type uint TESTNET_NETWORK) ;; Default to testnet

;; Performance thresholds
(define-data-var tps-threshold-warning uint u1000)
(define-data-var tps-threshold-critical uint u500)
(define-data-var memory-threshold-warning uint u85)
(define-data-var memory-threshold-critical uint u95)
(define-data-var error-rate-threshold-warning uint u5) ;; 5%
(define-data-var error-rate-threshold-critical uint u10) ;; 10%

;; =============================================================================
;; DATA MAPS
;; =============================================================================

;; Health metrics tracking
(define-map health-metrics
  { component: (string-ascii 30), timestamp: uint }
  {
    tps: uint,
    memory-usage: uint,
    error-rate: uint,
    response-time: uint,
    success-rate: uint,
    health-score: uint
  })

;; Alert configuration for different components
(define-map alert-configs
  { component: (string-ascii 30) }
  {
    tps-warning: uint,
    tps-critical: uint,
    memory-warning: uint,
    memory-critical: uint,
    error-warning: uint,
    error-critical: uint,
    enabled: bool
  })

;; Active alerts tracking
(define-map active-alerts
  { alert-id: uint }
  {
    component: (string-ascii 30),
    severity: uint,
    message: (string-ascii 200),
    triggered-at: uint,
    acknowledged: bool,
    acknowledged-by: (optional principal),
    resolved: bool,
    alert-type: (string-ascii 50)
  })

;; Notification targets based on network
(define-map notification-targets
  { network: uint, severity: uint }
  {
    target-type: (string-ascii 20), ;; "WALLET" or "DAO"
    target-address: principal,
    notification-method: (string-ascii 30),
    enabled: bool
  })

;; System health history
(define-map health-history
  { timestamp: uint }
  {
    overall-score: uint,
    oracle-health: uint,
    factory-health: uint,
    vault-health: uint,
    sdk-health: uint,
    active-alerts: uint
  })

;; =============================================================================
;; INITIALIZATION AND CONFIGURATION
;; =============================================================================

(define-public (initialize-health-monitoring (dao-contract (optional principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get deployer-address)) (err ERR_UNAUTHORIZED))
    
    ;; Set DAO contract if provided (for mainnet)
    (var-set dao-governance-contract dao-contract)
    
    ;; Detect network type based on DAO contract presence
    (if (is-some dao-contract)
      (var-set network-type MAINNET_NETWORK)
      (var-set network-type TESTNET_NETWORK))
    
    ;; Initialize default alert configurations
    (unwrap-panic (setup-default-alert-configs))
    
    ;; Setup notification targets
    (unwrap-panic (setup-notification-targets))
    
    (var-set last-health-check block-height)
    
    (print {
      event: "health-monitoring-initialized",
      network: (var-get network-type),
      dao-contract: dao-contract,
      block-height: block-height
    })
    
    (ok true)))

(define-private (setup-default-alert-configs)
  (begin
    ;; Oracle aggregator configuration
    (map-set alert-configs { component: "oracle-aggregator" }
      {
        tps-warning: u1000,
        tps-critical: u500,
        memory-warning: u85,
        memory-critical: u95,
        error-warning: u5,
        error-critical: u10,
        enabled: true
      })
    
    ;; DEX factory configuration
    (map-set alert-configs { component: "dex-factory" }
      {
        tps-warning: u800,
        tps-critical: u400,
        memory-warning: u80,
        memory-critical: u90,
        error-warning: u3,
        error-critical: u8,
        enabled: true
      })
    
    ;; Vault configuration
    (map-set alert-configs { component: "vault" }
      {
        tps-warning: u1200,
        tps-critical: u600,
        memory-warning: u85,
        memory-critical: u95,
        error-warning: u2,
        error-critical: u5,
        enabled: true
      })
    
    ;; Nakamoto SDK configuration
    (map-set alert-configs { component: "nakamoto-sdk" }
      {
        tps-warning: u5000,
        tps-critical: u2500,
        memory-warning: u90,
        memory-critical: u98,
        error-warning: u1,
        error-critical: u3,
        enabled: true
      })
    
    (ok true)))

(define-private (setup-notification-targets)
  (let ((network (var-get network-type)))
    (begin
      ;; Testnet: Send all alerts to deployer wallet
      (if (is-eq network TESTNET_NETWORK)
        (begin
          (map-set notification-targets { network: TESTNET_NETWORK, severity: SEVERITY_LOW }
            { target-type: "WALLET", target-address: (var-get deployer-address), notification-method: "DIRECT_CALL", enabled: true })
          (map-set notification-targets { network: TESTNET_NETWORK, severity: SEVERITY_MEDIUM }
            { target-type: "WALLET", target-address: (var-get deployer-address), notification-method: "DIRECT_CALL", enabled: true })
          (map-set notification-targets { network: TESTNET_NETWORK, severity: SEVERITY_HIGH }
            { target-type: "WALLET", target-address: (var-get deployer-address), notification-method: "DIRECT_CALL", enabled: true })
          (map-set notification-targets { network: TESTNET_NETWORK, severity: SEVERITY_CRITICAL }
            { target-type: "WALLET", target-address: (var-get deployer-address), notification-method: "URGENT_CALL", enabled: true }))
        ;; Mainnet: Send alerts to DAO governance
        (begin
          (map-set notification-targets { network: MAINNET_NETWORK, severity: SEVERITY_LOW }
            { target-type: "DAO", target-address: (unwrap-panic (var-get dao-governance-contract)), notification-method: "DAO_PROPOSAL", enabled: true })
          (map-set notification-targets { network: MAINNET_NETWORK, severity: SEVERITY_MEDIUM }
            { target-type: "DAO", target-address: (unwrap-panic (var-get dao-governance-contract)), notification-method: "DAO_ALERT", enabled: true })
          (map-set notification-targets { network: MAINNET_NETWORK, severity: SEVERITY_HIGH }
            { target-type: "DAO", target-address: (unwrap-panic (var-get dao-governance-contract)), notification-method: "DAO_URGENT", enabled: true })
          (map-set notification-targets { network: MAINNET_NETWORK, severity: SEVERITY_CRITICAL }
            { target-type: "DAO", target-address: (unwrap-panic (var-get dao-governance-contract)), notification-method: "DAO_EMERGENCY", enabled: true })))
      
      (ok true))))

;; =============================================================================
;; HEALTH MONITORING CORE FUNCTIONS
;; =============================================================================

(define-public (update-component-health
  (component (string-ascii 30))
  (tps uint)
  (memory-usage uint)
  (error-rate uint)
  (response-time uint)
  (success-rate uint))
  (begin
    (asserts! (var-get health-monitoring-enabled) (err ERR_SYSTEM_PAUSED))
    
    ;; Calculate component health score
    (let ((health-score (calculate-component-health-score tps memory-usage error-rate success-rate)))
      
      ;; Store health metrics
      (map-set health-metrics { component: component, timestamp: block-height }
        {
          tps: tps,
          memory-usage: memory-usage,
          error-rate: error-rate,
          response-time: response-time,
          success-rate: success-rate,
          health-score: health-score
        })
      
      ;; Check for alert conditions
      (try! (check-alert-conditions component tps memory-usage error-rate success-rate))
      
      ;; Update overall system health
      (try! (update-system-health-score))
      
      (print {
        event: "health-metrics-updated",
        component: component,
        health-score: health-score,
        tps: tps,
        memory-usage: memory-usage,
        error-rate: error-rate,
        timestamp: block-height
      })
      
      (ok health-score))))

(define-private (calculate-component-health-score (tps uint) (memory-usage uint) (error-rate uint) (success-rate uint))
  (let ((tps-score (if (>= tps u1000) u25 (/ (* tps u25) u1000)))
        (memory-score (if (<= memory-usage u80) u25 (- u25 (/ (* (- memory-usage u80) u25) u20))))
        (error-score (if (<= error-rate u2) u25 (- u25 (/ (* error-rate u25) u10))))
        (success-score (/ (* success-rate u25) u100)))
    (+ tps-score memory-score error-score success-score)))

(define-private (check-alert-conditions
  (component (string-ascii 30))
  (tps uint)
  (memory-usage uint)
  (error-rate uint)
  (success-rate uint))
  (let ((config (unwrap! (map-get? alert-configs { component: component }) (err ERR_ALERT_NOT_FOUND))))
    (begin
      ;; Check TPS thresholds
      (if (<= tps (get tps-critical config))
        (try! (trigger-alert component SEVERITY_CRITICAL "TPS below critical threshold"))
        (if (<= tps (get tps-warning config))
          (try! (trigger-alert component SEVERITY_HIGH "TPS below warning threshold"))
          true))
      
      ;; Check memory thresholds
      (if (>= memory-usage (get memory-critical config))
        (try! (trigger-alert component SEVERITY_CRITICAL "Memory usage above critical threshold"))
        (if (>= memory-usage (get memory-warning config))
          (try! (trigger-alert component SEVERITY_MEDIUM "Memory usage above warning threshold"))
          true))
      
      ;; Check error rate thresholds
      (if (>= error-rate (get error-critical config))
        (try! (trigger-alert component SEVERITY_CRITICAL "Error rate above critical threshold"))
        (if (>= error-rate (get error-warning config))
          (try! (trigger-alert component SEVERITY_MEDIUM "Error rate above warning threshold"))
          true))
      
      ;; Check success rate
      (if (< success-rate u90)
        (try! (trigger-alert component SEVERITY_HIGH "Success rate below 90%"))
        true)
      
      (ok true))))

;; =============================================================================
;; ALERT MANAGEMENT SYSTEM
;; =============================================================================

(define-public (trigger-alert
  (component (string-ascii 30))
  (severity uint)
  (message (string-ascii 200)))
  (let ((alert-id (+ (var-get alert-counter) u1))
        (alert-type (get-alert-type-by-severity severity)))
    
    ;; Create alert record
    (map-set active-alerts { alert-id: alert-id }
      {
        component: component,
        severity: severity,
        message: message,
        triggered-at: block-height,
        acknowledged: false,
        acknowledged-by: none,
        resolved: false,
        alert-type: alert-type
      })
    
    (var-set alert-counter alert-id)
    
    ;; Send notification based on network type
    (try! (send-notification alert-id component severity message))
    
    (print {
      event: "alert-triggered",
      alert-id: alert-id,
      component: component,
      severity: severity,
      message: message,
      network: (var-get network-type)
    })
    
    (ok alert-id)))

(define-private (get-alert-type-by-severity (severity uint))
  (if (is-eq severity SEVERITY_CRITICAL)
    "CRITICAL_SYSTEM_FAILURE"
    (if (is-eq severity SEVERITY_HIGH)
      "HIGH_PRIORITY_ISSUE"
      (if (is-eq severity SEVERITY_MEDIUM)
        "PERFORMANCE_WARNING"
        "INFORMATIONAL"))))

(define-private (send-notification
  (alert-id uint)
  (component (string-ascii 30))
  (severity uint)
  (message (string-ascii 200)))
  (let ((network (var-get network-type))
        (target (map-get? notification-targets { network: network, severity: severity })))
    
    (match target
      notification-config
        (if (get enabled notification-config)
          (if (is-eq (get target-type notification-config) "WALLET")
            ;; Send to deployer wallet (testnet)
            (send-wallet-notification alert-id component severity message (get target-address notification-config))
            ;; Send to DAO (mainnet)
            (send-dao-notification alert-id component severity message (get target-address notification-config)))
          (ok true))
      (ok true))))

(define-private (send-wallet-notification
  (alert-id uint)
  (component (string-ascii 30))
  (severity uint)
  (message (string-ascii 200))
  (wallet-address principal))
  (begin
    ;; Direct wallet notification for testnet
    (print {
      event: "wallet-notification",
      recipient: wallet-address,
      alert-id: alert-id,
      component: component,
      severity: severity,
      message: message,
      urgent: (>= severity SEVERITY_HIGH),
      timestamp: block-height
    })
    (ok true)))

(define-private (send-dao-notification
  (alert-id uint)
  (component (string-ascii 30))
  (severity uint)
  (message (string-ascii 200))
  (dao-address principal))
  (begin
    ;; DAO notification for mainnet
    (print {
      event: "dao-notification",
      dao-contract: dao-address,
      alert-id: alert-id,
      component: component,
      severity: severity,
      message: message,
      requires-proposal: (>= severity SEVERITY_HIGH),
      emergency: (is-eq severity SEVERITY_CRITICAL),
      timestamp: block-height
    })
    (ok true)))

;; =============================================================================
;; NAKAMOTO ULTRA-PERFORMANCE MONITORING
;; =============================================================================

(define-public (monitor-nakamoto-performance
  (oracle-tps uint)
  (sdk-tps uint)
  (factory-tps uint)
  (vault-tps uint)
  (microblock-confirmations uint)
  (bitcoin-finality-time uint))
  (begin
    (asserts! (var-get health-monitoring-enabled) (err ERR_SYSTEM_PAUSED))
    
    ;; Update individual component health
    (try! (update-component-health "nakamoto-oracle" oracle-tps u0 u0 u0 u100))
    (try! (update-component-health "nakamoto-sdk" sdk-tps u0 u0 u0 u100))
    (try! (update-component-health "nakamoto-factory" factory-tps u0 u0 u0 u100))
    (try! (update-component-health "nakamoto-vault" vault-tps u0 u0 u0 u100))
    
    ;; Check Nakamoto-specific performance targets
    (if (< oracle-tps u10000)
      (try! (trigger-alert "nakamoto-oracle" SEVERITY_HIGH "Oracle TPS below 10,000"))
      true)
    
    (if (< sdk-tps u50000)
      (try! (trigger-alert "nakamoto-sdk" SEVERITY_MEDIUM "SDK TPS below 50,000"))
      true)
    
    (if (> bitcoin-finality-time u600) ;; 10 minutes
      (try! (trigger-alert "nakamoto-bitcoin" SEVERITY_HIGH "Bitcoin finality time above 10 minutes"))
      true)
    
    (print {
      event: "nakamoto-performance-monitored",
      oracle-tps: oracle-tps,
      sdk-tps: sdk-tps,
      factory-tps: factory-tps,
      vault-tps: vault-tps,
      microblock-confirmations: microblock-confirmations,
      bitcoin-finality-time: bitcoin-finality-time
    })
    
    (ok true)))

;; =============================================================================
;; SYSTEM HEALTH AGGREGATION
;; =============================================================================

(define-private (update-system-health-score)
  (let ((oracle-health (get-component-health "oracle-aggregator"))
        (factory-health (get-component-health "dex-factory"))
        (vault-health (get-component-health "vault"))
        (sdk-health (get-component-health "nakamoto-sdk")))
    
    (let ((overall-score (/ (+ oracle-health factory-health vault-health sdk-health) u4)))
      
      ;; Store health history
      (map-set health-history { timestamp: block-height }
        {
          overall-score: overall-score,
          oracle-health: oracle-health,
          factory-health: factory-health,
          vault-health: vault-health,
          sdk-health: sdk-health,
          active-alerts: (var-get alert-counter)
        })
      
      (var-set system-health-score overall-score)
      (var-set last-health-check block-height)
      
      ;; Trigger system-wide alerts if needed
      (if (< overall-score u50)
        (try! (trigger-alert "system-wide" SEVERITY_CRITICAL "Overall system health below 50%"))
        (if (< overall-score u70)
          (try! (trigger-alert "system-wide" SEVERITY_HIGH "Overall system health below 70%"))
          true))
      
      (ok overall-score))))

(define-private (get-component-health (component (string-ascii 30)))
  (let ((latest-metric (map-get? health-metrics { component: component, timestamp: block-height })))
    (match latest-metric
      metric (get health-score metric)
      u50))) ;; Default moderate health if no data

;; =============================================================================
;; ADMINISTRATIVE FUNCTIONS
;; =============================================================================

(define-public (acknowledge-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? active-alerts { alert-id: alert-id }) (err ERR_ALERT_NOT_FOUND))))
    (begin
      (asserts! (or (is-eq tx-sender (var-get deployer-address))
                    (and (is-some (var-get dao-governance-contract))
                         (is-eq tx-sender (unwrap-panic (var-get dao-governance-contract)))))
                (err ERR_UNAUTHORIZED))
      
      (map-set active-alerts { alert-id: alert-id }
        (merge alert { acknowledged: true, acknowledged-by: (some tx-sender) }))
      
      (print {
        event: "alert-acknowledged",
        alert-id: alert-id,
        acknowledged-by: tx-sender
      })
      
      (ok true))))

(define-public (resolve-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? active-alerts { alert-id: alert-id }) (err ERR_ALERT_NOT_FOUND))))
    (begin
      (asserts! (or (is-eq tx-sender (var-get deployer-address))
                    (and (is-some (var-get dao-governance-contract))
                         (is-eq tx-sender (unwrap-panic (var-get dao-governance-contract)))))
                (err ERR_UNAUTHORIZED))
      
      (map-set active-alerts { alert-id: alert-id }
        (merge alert { resolved: true }))
      
      (print {
        event: "alert-resolved",
        alert-id: alert-id,
        resolved-by: tx-sender
      })
      
      (ok true))))

(define-public (update-dao-contract (new-dao-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get deployer-address)) (err ERR_UNAUTHORIZED))
    
    (var-set dao-governance-contract (some new-dao-contract))
    (var-set network-type MAINNET_NETWORK)
    
    ;; Update notification targets for mainnet
    (try! (setup-notification-targets))
    
    (print {
      event: "dao-contract-updated",
      new-dao-contract: new-dao-contract,
      network-switched-to: MAINNET_NETWORK
    })
    
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-system-health-summary)
  {
    overall-score: (var-get system-health-score),
    last-check: (var-get last-health-check),
    monitoring-enabled: (var-get health-monitoring-enabled),
    network-type: (var-get network-type),
    active-alerts: (var-get alert-counter),
    deployer: (var-get deployer-address),
    dao-contract: (var-get dao-governance-contract)
  })

(define-read-only (get-component-health-status (component (string-ascii 30)))
  (map-get? health-metrics { component: component, timestamp: block-height }))

(define-read-only (get-alert-details (alert-id uint))
  (map-get? active-alerts { alert-id: alert-id }))

(define-read-only (get-active-alerts-count)
  (len (filter is-alert-active (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))))

(define-read-only (get-health-history (timestamp uint))
  (map-get? health-history { timestamp: timestamp }))

(define-read-only (get-notification-target (network uint) (severity uint))
  (map-get? notification-targets { network: network, severity: severity }))

;; Helper function for filtering active alerts
(define-private (is-alert-active (alert-id uint))
  (let ((alert (map-get? active-alerts { alert-id: alert-id })))
    (match alert
      alert-data (and (not (get resolved alert-data)) (not (get acknowledged alert-data)))
      false)))

;; Get current network configuration
(define-read-only (get-network-config)
  {
    network-type: (var-get network-type),
    is-testnet: (is-eq (var-get network-type) TESTNET_NETWORK),
    is-mainnet: (is-eq (var-get network-type) MAINNET_NETWORK),
    deployer-address: (var-get deployer-address),
    dao-contract: (var-get dao-governance-contract)
  })
