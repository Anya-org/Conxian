;; AutoVault Enhanced Health Monitoring Contract
;; Ultra-performance health monitoring with Nakamoto optimization
;; Testnet: Alerts to deployer wallet | Mainnet: Alerts to DAO

;; =============================================================================
;; CONSTANTS & CONFIGURATION
;; =============================================================================

(define-constant CONTRACT_VERSION "2.0.0-nakamoto")
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_INVALID_THRESHOLD u402)
(define-constant ERR_ALERT_NOT_FOUND u403)
(define-constant ERR_SYSTEM_PAUSED u404)
(define-constant ERR_INVALID_ENVIRONMENT u405)

;; Alert severity levels
(define-constant SEVERITY_INFO u1)
(define-constant SEVERITY_WARNING u2)
(define-constant SEVERITY_CRITICAL u3)
(define-constant SEVERITY_EMERGENCY u4)

;; Environment detection
(define-constant TESTNET_CHAIN_ID u2147483648) ;; Testnet chain ID
(define-constant MAINNET_CHAIN_ID u1) ;; Mainnet chain ID

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var contract-deployer principal tx-sender)
(define-data-var dao-contract principal 'SP000000000000000000002Q6VF78) ;; Placeholder, update with real DAO
(define-data-var monitoring-enabled bool true)
(define-data-var alert-count uint u0)
(define-data-var emergency-mode bool false)
(define-data-var chain-id uint u2147483648) ;; Default to testnet

;; Performance tracking
(define-data-var total-alerts uint u0)
(define-data-var critical-alerts uint u0)
(define-data-var last-health-check uint u0)

;; =============================================================================
;; DATA MAPS
;; =============================================================================

;; System health metrics
(define-map health-metrics
  { component: (string-ascii 30), metric-type: (string-ascii 30) }
  {
    current-value: uint,
    threshold-warning: uint,
    threshold-critical: uint,
    last-updated: uint,
    trend: int, ;; -1 declining, 0 stable, 1 improving
    consecutive-violations: uint
  }
)

;; Alert configuration per component
(define-map alert-config
  { alert-id: uint }
  {
    component: (string-ascii 30),
    metric-type: (string-ascii 30),
    severity: uint,
    enabled: bool,
    notification-target: (string-ascii 20), ;; "DEPLOYER", "DAO", "BOTH"
    cooldown-period: uint,
    last-triggered: uint
  }
)

;; Active alerts
(define-map active-alerts
  { alert-id: uint }
  {
    component: (string-ascii 30),
    metric-type: (string-ascii 30),
    severity: uint,
    triggered-at: uint,
    value: uint,
    threshold: uint,
    acknowledged: bool,
    resolved: bool,
    notification-sent: bool
  }
)

;; Component status tracking
(define-map component-status
  { component: (string-ascii 30) }
  {
    status: (string-ascii 20), ;; "HEALTHY", "WARNING", "CRITICAL", "OFFLINE"
    last-heartbeat: uint,
    uptime-percentage: uint,
    error-count: uint,
    performance-score: uint
  }
)

;; Nakamoto performance metrics
(define-map nakamoto-metrics
  { component: (string-ascii 30) }
  {
    microblock-tps: uint,
    bitcoin-finality-time: uint,
    vectorized-operations: uint,
    memory-efficiency: uint,
    zero-copy-operations: uint,
    last-performance-check: uint
  }
)

;; Alert history for analytics
(define-map alert-history
  { alert-id: uint }
  {
    component: (string-ascii 30),
    severity: uint,
    triggered-at: uint,
    resolved-at: uint,
    response-time: uint,
    auto-resolved: bool
  }
)

;; =============================================================================
;; ENVIRONMENT DETECTION
;; =============================================================================

(define-private (is-testnet)
  (is-eq (var-get chain-id) TESTNET_CHAIN_ID))

(define-private (is-mainnet)
  (is-eq (var-get chain-id) MAINNET_CHAIN_ID))

(define-public (set-chain-id (new-chain-id uint))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    (var-set chain-id new-chain-id)
    (print {
      event: "chain-id-updated",
      new-chain-id: new-chain-id,
      environment: (if (is-eq new-chain-id TESTNET_CHAIN_ID) "testnet" "mainnet")
    })
    (ok true)))

;; =============================================================================
;; AUTHORIZATION
;; =============================================================================

(define-private (is-deployer)
  (is-eq tx-sender (var-get contract-deployer)))

(define-private (is-dao)
  (is-eq tx-sender (var-get dao-contract)))

(define-private (is-deployer-or-dao)
  (or (is-deployer) (is-dao)))

(define-private (can-send-alerts)
  (and (var-get monitoring-enabled)
       (not (var-get emergency-mode))))

;; =============================================================================
;; CORE HEALTH MONITORING
;; =============================================================================

(define-public (update-health-metric
  (component (string-ascii 30))
  (metric-type (string-ascii 30))
  (value uint)
  (threshold-warning uint)
  (threshold-critical uint))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    (asserts! (var-get monitoring-enabled) (err ERR_SYSTEM_PAUSED))
    
    ;; Get previous metric for trend calculation
    (let ((previous-metric (map-get? health-metrics { component: component, metric-type: metric-type }))
          (trend (match previous-metric
                   prev (if (> value (get current-value prev)) 1 
                        (if (< value (get current-value prev)) -1 0))
                   0))
          (consecutive-violations (match previous-metric
                                   prev (if (or (> value threshold-critical) (> value threshold-warning))
                                          (+ (get consecutive-violations prev) u1)
                                          u0)
                                   (if (or (> value threshold-critical) (> value threshold-warning)) u1 u0))))
      
      ;; Update health metrics
      (map-set health-metrics
        { component: component, metric-type: metric-type }
        {
          current-value: value,
          threshold-warning: threshold-warning,
          threshold-critical: threshold-critical,
          last-updated: block-height,
          trend: trend,
          consecutive-violations: consecutive-violations
        })
      
      ;; Check for alert conditions
      (let ((result (try! (check-alert-conditions component metric-type value threshold-warning threshold-critical consecutive-violations))))
      ;; Update component status
      (unwrap-panic (update-component-health-status component)))
      
      (print {
        event: "health-metric-updated",
        component: component,
        metric-type: metric-type,
        value: value,
        trend: trend,
        consecutive-violations: consecutive-violations
      })
      
      (ok true))))

;; =============================================================================
;; NAKAMOTO PERFORMANCE MONITORING
;; =============================================================================

(define-public (update-nakamoto-metrics
  (component (string-ascii 30))
  (microblock-tps uint)
  (bitcoin-finality-time uint)
  (vectorized-operations uint)
  (memory-efficiency uint)
  (zero-copy-operations uint))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    
    (map-set nakamoto-metrics
      { component: component }
      {
        microblock-tps: microblock-tps,
        bitcoin-finality-time: bitcoin-finality-time,
        vectorized-operations: vectorized-operations,
        memory-efficiency: memory-efficiency,
        zero-copy-operations: zero-copy-operations,
        last-performance-check: block-height
      })
    
    ;; Check Nakamoto performance thresholds
    (let ((performance-issues (check-nakamoto-performance component microblock-tps bitcoin-finality-time memory-efficiency)))
      (if (> performance-issues u0)
          (match (trigger-nakamoto-alert component performance-issues)
            success (ok true)
            error (err error))
          (ok true)))
    
    (print {
      event: "nakamoto-metrics-updated",
      component: component,
      microblock-tps: microblock-tps,
      bitcoin-finality-time: bitcoin-finality-time,
      memory-efficiency: memory-efficiency
    })
    
    (ok true)))

(define-private (check-nakamoto-performance (component (string-ascii 30)) (tps uint) (finality-time uint) (memory-efficiency uint))
  (let ((tps-issues (if (< tps u1000) u1 u0))
        (finality-issues (if (> finality-time u600) u1 u0))
        (memory-issues (if (< memory-efficiency u90) u1 u0)))
    (+ tps-issues (+ finality-issues memory-issues))))

(define-private (trigger-nakamoto-alert (component (string-ascii 30)) (issue-count uint) (response uint uint))
  (let ((alert-id (+ (var-get alert-count) u1))
        (severity (if (> issue-count u2) SEVERITY_CRITICAL SEVERITY_WARNING)))
    
    (map-set active-alerts
      { alert-id: alert-id }
      {
        component: component,
        metric-type: "NAKAMOTO_PERFORMANCE",
        severity: severity,
        triggered-at: block-height,
        value: issue-count,
        threshold: u1,
        acknowledged: false,
        resolved: false,
        notification-sent: false
      })
    
    (var-set alert-count alert-id)
    (var-set total-alerts (+ (var-get total-alerts) u1))
    
    ;; Send alert notification
    (try! (send-alert-notification alert-id component "NAKAMOTO_PERFORMANCE" severity))
    
    (ok alert-id)))

;; =============================================================================
;; ALERT MANAGEMENT
;; =============================================================================

(define-private (check-alert-conditions
  (component (string-ascii 30))
  (metric-type (string-ascii 30))
  (value uint)
  (threshold-warning uint)
  (threshold-critical uint)
  (consecutive-violations uint))
  (begin
    ;; Critical alert
    (if (> value threshold-critical)
      (begin
        (try! (trigger-health-alert component metric-type SEVERITY_CRITICAL value threshold-critical))
        (ok u0))
      ;; Warning alert
      (if (and (> value threshold-warning) (> consecutive-violations u2))
        (begin 
          (try! (trigger-health-alert component metric-type SEVERITY_WARNING value threshold-warning))
          (ok u0))
        (ok u0)))))

(define-private (trigger-health-alert
  (component (string-ascii 30))
  (metric-type (string-ascii 30))
  (severity uint)
  (value uint)
  (threshold uint))
  (let ((alert-id (+ (var-get alert-count) u1)))
    
    ;; Check cooldown period to avoid spam
    (let ((last-alert (get-last-alert-for-metric component metric-type)))
      (if (and (> last-alert u0) (< (- block-height last-alert) u10)) ;; 10 block cooldown
        (ok u0) ;; Skip if in cooldown
        (begin
          (map-set active-alerts
            { alert-id: alert-id }
            {
              component: component,
              metric-type: metric-type,
              severity: severity,
              triggered-at: block-height,
              value: value,
              threshold: threshold,
              acknowledged: false,
              resolved: false,
              notification-sent: false
            })
          
          (var-set alert-count alert-id)
          (var-set total-alerts (+ (var-get total-alerts) u1))
          
          (if (is-eq severity SEVERITY_CRITICAL)
            (var-set critical-alerts (+ (var-get critical-alerts) u1))
            true)
          
          ;; Send alert notification
          (try! (send-alert-notification alert-id component metric-type severity))
          
          (ok alert-id))))))

;; =============================================================================
;; NOTIFICATION SYSTEM
;; =============================================================================

(define-private (send-alert-notification
  (alert-id uint)
  (component (string-ascii 30))
  (metric-type (string-ascii 30))
  (severity uint)
  (response bool uint)) ;; Add explicit return type
  (let ((notification-target (get-notification-target severity)))
    
    ;; Determine notification recipient based on environment
    (let ((recipient (if (is-testnet)
                       (var-get contract-deployer) ;; Testnet: send to deployer
                       (var-get dao-contract))))    ;; Mainnet: send to DAO
      
      ;; Update alert to mark notification as sent
      (let ((alert-data (unwrap! (map-get? active-alerts { alert-id: alert-id }) (err ERR_ALERT_NOT_FOUND))))
        (map-set active-alerts
          { alert-id: alert-id }
          (merge alert-data { notification-sent: true }))
        
        ;; Emit notification event
        (print {
          event: "health-alert-notification",
          alert-id: alert-id,
          component: component,
          metric-type: metric-type,
          severity: severity,
          recipient: recipient,
          environment: (if (is-testnet) "testnet" "mainnet"),
          notification-target: notification-target,
          triggered-at: block-height
        })
        
        ;; For emergency alerts, also print special emergency event
        (if (is-eq severity SEVERITY_EMERGENCY)
          (begin
            (let ((emergency-event {
              event: "EMERGENCY_ALERT",
              alert-id: alert-id,
              component: component,
              IMMEDIATE_ACTION_REQUIRED: true,
              recipient: recipient
            }))
              (print emergency-event)
              true))
          true)
        
        (ok true)))))

(define-private (get-notification-target (severity uint))
  (if (is-testnet)
    "DEPLOYER"
    (if (>= severity SEVERITY_CRITICAL)
      "DAO"
      "DAO")))

(define-private (get-last-alert-for-metric (component (string-ascii 30)) (metric-type (string-ascii 30)))
  ;; Simplified: return 0 for now, in production would check recent alerts
  u0)

;; =============================================================================
;; COMPONENT STATUS MANAGEMENT
;; =============================================================================

(define-private (update-component-health-status (component (string-ascii 30)))
  (let ((current-status (default-to 
    { status: "UNKNOWN", last-heartbeat: u0, uptime-percentage: u0, error-count: u0, performance-score: u0 }
    (map-get? component-status { component: component }))))
    
    ;; Calculate new status based on recent metrics
    (let ((new-status (calculate-component-status component))
          (performance-score (calculate-performance-score component)))
      
      (map-set component-status
        { component: component }
        {
          status: new-status,
          last-heartbeat: block-height,
          uptime-percentage: (get uptime-percentage current-status), ;; Would calculate in production
          error-count: (get error-count current-status),
          performance-score: performance-score
        })
      
      (print {
        event: "component-status-updated",
        component: component,
        status: new-status,
        performance-score: performance-score
      })
      
      (ok true))))

(define-private (calculate-component-status (component (string-ascii 30)))
  ;; Simplified status calculation
  ;; In production, would analyze multiple metrics
  "HEALTHY")

(define-private (calculate-performance-score (component (string-ascii 30)))
  ;; Simplified performance score (0-100)
  ;; In production, would calculate based on multiple factors
  u85)

;; =============================================================================
;; EMERGENCY CONTROLS
;; =============================================================================

(define-public (trigger-emergency-mode (reason (string-ascii 100)))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    
    (var-set emergency-mode true)
    (var-set monitoring-enabled false)
    
    ;; Send emergency notification
    (let ((alert-id (+ (var-get alert-count) u1)))
      (map-set active-alerts
        { alert-id: alert-id }
        {
          component: "SYSTEM",
          metric-type: "EMERGENCY_MODE",
          severity: SEVERITY_EMERGENCY,
          triggered-at: block-height,
          value: u1,
          threshold: u0,
          acknowledged: false,
          resolved: false,
          notification-sent: false
        })
      
      (var-set alert-count alert-id)
      
      (try! (send-alert-notification alert-id "SYSTEM" "EMERGENCY_MODE" SEVERITY_EMERGENCY))
      
      (print {
        event: "EMERGENCY_MODE_ACTIVATED",
        reason: reason,
        activated-by: tx-sender,
        alert-id: alert-id
      })
      
      (ok alert-id))))

(define-public (deactivate-emergency-mode)
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    
    (var-set emergency-mode false)
    (var-set monitoring-enabled true)
    
    (print {
      event: "emergency-mode-deactivated",
      deactivated-by: tx-sender,
      block-height: block-height
    })
    
    (ok true)))

;; =============================================================================
;; ALERT MANAGEMENT FUNCTIONS
;; =============================================================================

(define-public (acknowledge-alert (alert-id uint))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    
    (let ((alert-data (unwrap! (map-get? active-alerts { alert-id: alert-id }) (err ERR_ALERT_NOT_FOUND))))
      (map-set active-alerts
        { alert-id: alert-id }
        (merge alert-data { acknowledged: true }))
      
      (print {
        event: "alert-acknowledged",
        alert-id: alert-id,
        acknowledged-by: tx-sender
      })
      
      (ok true))))

(define-public (resolve-alert (alert-id uint))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    
    (let ((alert-data (unwrap! (map-get? active-alerts { alert-id: alert-id }) (err ERR_ALERT_NOT_FOUND))))
      (map-set active-alerts
        { alert-id: alert-id }
        (merge alert-data { resolved: true }))
      
      ;; Add to history
      (map-set alert-history
        { alert-id: alert-id }
        {
          component: (get component alert-data),
          severity: (get severity alert-data),
          triggered-at: (get triggered-at alert-data),
          resolved-at: block-height,
          response-time: (- block-height (get triggered-at alert-data)),
          auto-resolved: false
        })
      
      (print {
        event: "alert-resolved",
        alert-id: alert-id,
        resolved-by: tx-sender,
        response-time: (- block-height (get triggered-at alert-data))
      })
      
      (ok true))))

;; =============================================================================
;; CONFIGURATION FUNCTIONS
;; =============================================================================

(define-public (set-dao-contract (new-dao principal))
  (begin
    (asserts! (is-deployer) (err ERR_UNAUTHORIZED))
    (var-set dao-contract new-dao)
    (print {
      event: "dao-contract-updated",
      new-dao: new-dao
    })
    (ok true)))

(define-public (toggle-monitoring (enabled bool))
  (begin
    (asserts! (is-deployer-or-dao) (err ERR_UNAUTHORIZED))
    (var-set monitoring-enabled enabled)
    (print {
      event: "monitoring-toggled",
      enabled: enabled,
      toggled-by: tx-sender
    })
    (ok true)))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-system-health-summary)
  {
    version: CONTRACT_VERSION,
    monitoring-enabled: (var-get monitoring-enabled),
    emergency-mode: (var-get emergency-mode),
    environment: (if (is-testnet) "testnet" "mainnet"),
    total-alerts: (var-get total-alerts),
    critical-alerts: (var-get critical-alerts),
    alert-count: (var-get alert-count),
    last-health-check: (var-get last-health-check),
    notification-target: (if (is-testnet) "deployer" "dao")
  })

(define-read-only (get-health-metric (component (string-ascii 30)) (metric-type (string-ascii 30)))
  (map-get? health-metrics { component: component, metric-type: metric-type }))

(define-read-only (get-component-status (component (string-ascii 30)))
  (map-get? component-status { component: component }))

(define-read-only (get-active-alert (alert-id uint))
  (map-get? active-alerts { alert-id: alert-id }))

(define-read-only (get-nakamoto-metrics (component (string-ascii 30)))
  (map-get? nakamoto-metrics { component: component }))

(define-read-only (get-alert-history (alert-id uint))
  (map-get? alert-history { alert-id: alert-id }))

(define-read-only (is-system-healthy)
  (and 
    (var-get monitoring-enabled)
    (not (var-get emergency-mode))
    (< (var-get critical-alerts) u5))) ;; Less than 5 critical alerts

(define-read-only (get-notification-config)
  {
    environment: (if (is-testnet) "testnet" "mainnet"),
    chain-id: (var-get chain-id),
    deployer: (var-get contract-deployer),
    dao-contract: (var-get dao-contract),
    notification-target: (if (is-testnet) "deployer" "dao")
  })
