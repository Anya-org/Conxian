;; real-time-monitoring-dashboard.clar
;; Conxian Protocol: Real-time monitoring dashboard for system metrics

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVALID_METRIC (err 30001))
(define-constant ERR_DASHBOARD_NOT_ACTIVE (err 30002))
(define-constant ERR_INSUFFICIENT_PERMISSIONS (err 30003))
(define-constant ERR_METRIC_NOT_FOUND (err 30004))
(define-constant ERR_DATA_STALE (err 30005))

;; Dashboard parameters
(define-constant MAX_METRICS u100) ;; Maximum metrics to track
(define-constant UPDATE_INTERVAL u10) ;; Update every 10 blocks
(define-constant DATA_RETENTION_BLOCKS u10000 ;; Keep data for 10000 blocks
(define-constant ALERT_THRESHOLD u80) ;; 80% threshold for alerts
(define-constant MAX_SUBSCRIBERS u50) ;; Maximum dashboard subscribers

;; Data variables
(define-data-var dashboard-active bool true)
(define-data-var total-metrics uint u0)
(define-data-var last-update uint u0)
(define-data-var total-alerts uint u0)

;; Storage maps
(define-map dashboard-metrics { metric-id: (string-ascii 32) } { 
  name: (string-ascii 64),
  description: (string-ascii 256),
  value: uint,
  previous-value: uint,
  unit: (string-ascii 16),
  category: (string-ascii 32),
  threshold: uint,
  alert-enabled: bool,
  last-updated: uint,
  trend: (string-ascii 8),
  data-points: (list 100 { timestamp: uint, value: uint })
})

(define-map metric-alerts { alert-id: (buff 32) } { 
  metric-id: (string-ascii 32),
  timestamp: uint,
  value: uint,
  threshold: uint,
  severity: (string-ascii 16),
  acknowledged: bool,
  acknowledged-by: (optional principal),
  acknowledged-at: (optional uint)
})

(define-map dashboard-subscribers { subscriber: principal } { 
  subscription-level: (string-ascii 16),
  metrics-subscribed: (list 20 (string-ascii 32)),
  last-access: uint,
  alert-preferences: (list 5 { severity: (string-ascii 16), enabled: bool })
})

(define-map dashboard-snapshots { snapshot-id: (buff 32) } { 
  timestamp: uint,
  metrics: (list 50 { metric-id: (string-ascii 32), value: uint, trend: (string-ascii 8) }),
  system-health: uint,
  alert-count: uint,
  created-by: principal
})

(define-map system-health { timestamp: uint } { 
  overall-health: uint,
  component-health: (list 10 { component: (string-ascii 32), health: uint }),
  active-alerts: uint,
  last-check: uint
})

;; Events
(define-event (metric-updated (metric-id (string-ascii 32)) (value uint) (trend (string-ascii 8))))
(define-event (alert-triggered (alert-id (buff 32)) (metric-id (string-ascii 32)) (severity (string-ascii 16))))
(define-event (alert-acknowledged (alert-id (buff 32)) (acknowledged-by principal)))
(define-event (snapshot-created (snapshot-id (buff 32)) (system-health uint)))
(define-event (subscriber-added (subscriber principal) (level (string-ascii 16))))
(define-event (dashboard-activated))
(define-event (dashboard-deactivated))

;; Read-only functions

(define-read-only (get-metric (metric-id (string-ascii 32)))
  (map-get? dashboard-metrics { metric-id: metric-id }))

(define-read-only (get-metric-value (metric-id (string-ascii 32)))
  (match (get-metric metric_id)
    metric (ok (get metric value))
    none (ok u0)
  )
)

(define-read-only (get-metric-trend (metric-id (string-ascii 32)))
  (match (get-metric metric_id)
    metric (ok (get metric trend))
    none (ok "stable")
  )
)

(define-read-only (get-metric-data-points (metric-id (string-ascii 32)))
  (match (get-metric metric_id)
    metric (ok (get metric data-points))
    none (ok (list 0 { timestamp: uint, value: uint }))
  )
)

(define-read-only (get-alert (alert-id (buff 32)))
  (map-get? metric-alerts { alert-id: alert-id }))

(define-read-only (get-subscriber (subscriber principal))
  (map-get? dashboard-subscribers { subscriber: subscriber }))

(define-read-only (get-snapshot (snapshot-id (buff 32)))
  (map-get? dashboard-snapshots { snapshot-id: snapshot-id }))

(define-read-only (get-system-health (timestamp uint))
  (map-get? system-health { timestamp: timestamp }))

(define-read-only (is-dashboard-active)
  (var-get dashboard-active))

(define-read-only (get-total-metrics)
  (var-get total-metrics))

(define-read-only (get-total-alerts)
  (var-get total-alerts))

(define-read-only (get-last-update)
  (var-get last-update))

;; Public functions

(define-public (register-metric 
  (metric-id (string-ascii 32)) 
  (name (string-ascii 64)) 
  (description (string-ascii 256))
  (unit (string-ascii 16))
  (category (string-ascii 32))
  (threshold uint)
  (alert-enabled bool)
)
  (begin
    ;; Validate inputs
    (asserts! (> (len metric-id) u0) ERR_INVALID_METRIC)
    (asserts! (> (len name) u0) ERR_INVALID_METRIC)
    (asserts! (> (len description) u0) ERR_INVALID_METRIC)
    (asserts! (> (len unit) u0) ERR_INVALID_METRIC)
    (asserts! (> (len category) u0) ERR_INVALID_METRIC)
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Register metric
    (map-set dashboard-metrics { metric-id: metric-id } {
      name: name,
      description: description,
      value: u0,
      previous-value: u0,
      unit: unit,
      category: category,
      threshold: threshold,
      alert-enabled: alert-enabled,
      last-updated: block-height,
      trend: "stable",
      data-points: (list 0 { timestamp: uint, value: uint })
    })
    
    ;; Update totals
    (var-set total-metrics (+ (var-get total-metrics) u1))
    
    (ok true)
  )
)

(define-public (update-metric (metric-id (string-ascii 32)) (value uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len metric_id) u0) ERR_INVALID_METRIC)
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Check if metric exists
    (let ((metric_info (get-metric metric_id)))
      (asserts! (is-some metric_info) ERR_METRIC_NOT_FOUND)
      
      (let ((metric (unwrap-optional metric_info)))
        ;; Calculate trend
        (let ((trend (calculate-trend (get metric value) value)))
          
          ;; Update metric
          (map-set dashboard-metrics { metric-id: metric_id } {
            name: (get metric name),
            description: (get metric description),
            value: value,
            previous-value: (get metric value),
            unit: (get metric unit),
            category: (get metric category),
            threshold: (get metric threshold),
            alert-enabled: (get metric alert-enabled),
            last-updated: block-height,
            trend: trend,
            data-points: (add-data-point (get metric data-points) value)
          })
          
          ;; Check for alerts
          (if (and (get metric alert-enabled) (> value (get metric threshold)))
              (trigger-alert metric_id value (get metric threshold))
              true
          )
          
          ;; Update last update time
          (var-set last-update block-height)
          
          ;; Emit event
          (emit-event (metric-updated metric_id value trend))
          
          (ok {
            metric-id: metric_id,
            value: value,
            trend: trend,
            previous-value: (get metric value)
          })
        )
      )
    )
  )
)

(define-public (trigger-alert (metric_id (string-ascii 32)) (value uint) (threshold uint))
  (begin
    ;; Generate alert ID
    (let ((alert-id (hash160 (concat (string-ascii metric_id) (int-to-buff block-height))))
          (severity (determine-alert-severity value threshold)))
      
      ;; Create alert
      (map-set metric-alerts { alert-id: alert-id } {
        metric-id: metric_id,
        timestamp: block-height,
        value: value,
        threshold: threshold,
        severity: severity,
        acknowledged: false,
        acknowledged-by: none,
        acknowledged-at: none
      })
      
      ;; Update alert counter
      (var-set total-alerts (+ (var-get total-alerts) u1))
      
      ;; Emit event
      (emit-event (alert-triggered alert_id metric_id severity))
      
      (ok alert-id)
    )
  )
)

(define-public (acknowledge-alert (alert_id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Check if alert exists
    (let ((alert_info (get-alert alert_id)))
      (asserts! (is-some alert_info) ERR_METRIC_NOT_FOUND)
      
      (let ((alert (unwrap-optional alert_info)))
        ;; Update alert
        (map-set metric-alerts { alert-id: alert_id } {
          metric-id: (get alert metric-id),
          timestamp: (get alert timestamp),
          value: (get alert value),
          threshold: (get alert threshold),
          severity: (get alert severity),
          acknowledged: true,
          acknowledged-by: (some tx-sender),
          acknowledged-at: (some block-height)
        })
        
        ;; Emit event
        (emit-event (alert-acknowledged alert_id tx-sender))
        
        (ok true)
      )
    )
  )
)

(define-public (subscribe-dashboard (subscription-level (string-ascii 16)) (metrics-subscribed (list 20 (string-ascii 32))))
  (begin
    ;; Validate inputs
    (asserts! (> (len subscription-level) u0) ERR_INVALID_METRIC)
    (asserts! (is-valid-subscription-level subscription-level) ERR_INVALID_METRIC)
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Check subscriber limit
    (asserts! (< (len metrics-subscribed) MAX_SUBSCRIBERS) ERR_INVALID_METRIC)
    
    ;; Add subscriber
    (map-set dashboard-subscribers { subscriber: tx-sender } {
      subscription-level: subscription-level,
      metrics-subscribed: metrics-subscribed,
      last-access: block-height,
      alert-preferences: (list { severity: "high", enabled: true }, { severity: "critical", enabled: true })
    })
    
    ;; Emit event
    (emit-event (subscriber-added tx-sender subscription-level))
    
    (ok true)
  )
)

(define-public (create-snapshot (include-metrics (list 20 (string-ascii 32))))
  (begin
    ;; Validate inputs
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Generate snapshot ID
    (let ((snapshot-id (hash160 (concat (principal-to-buff? tx-sender) (int-to-buff block-height))))
          (system-health (calculate-system-health)))
      
      ;; Collect metrics data
      (let ((metrics-data (collect-metrics-data include-metrics)))
        
        ;; Create snapshot
        (map-set dashboard-snapshots { snapshot-id: snapshot-id } {
          timestamp: block-height,
          metrics: metrics-data,
          system-health: system-health,
          alert-count: (var-get total-alerts),
          created-by: tx-sender
        })
        
        ;; Store system health
        (map-set system-health { timestamp: block-height } {
          overall-health: system-health,
          component-health: (get-component-health),
          active-alerts: (var-get total-alerts),
          last-check: block-height
        })
        
        ;; Emit event
        (emit-event (snapshot-created snapshot_id system_health))
        
        (ok {
          snapshot-id: snapshot-id,
          timestamp: block-height,
          system-health: system-health,
          metrics-count: (len metrics-data)
        })
      )
    )
  )
)

(define-public (update-system-health)
  (begin
    ;; Validate inputs
    (asserts! (var-get dashboard-active) ERR_DASHBOARD_NOT_ACTIVE)
    
    ;; Calculate system health
    (let ((health (calculate-system-health)))
      
      ;; Store system health
      (map-set system-health { timestamp: block-height } {
        overall-health: health,
        component-health: (get-component-health),
        active-alerts: (var-get total-alerts),
        last-check: block-height
      })
      
      (ok health)
    )
  )
)

(define-public (set-dashboard-active (active bool))
  (begin
    ;; Only admin can set dashboard status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INSUFFICIENT_PERMISSIONS)
    
    (var-set dashboard-active active)
    
    ;; Emit event
    (if active
        (emit-event (dashboard-activated))
        (emit-event (dashboard-deactivated))
    )
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { subscription-level: (string-ascii 16), metrics-subscribed: (list 0 (string-ascii 32)), last-access: uint, alert-preferences: (list 0 { severity: (string-ascii 16), enabled: bool }) } option))

(define-private (is-valid-subscription-level (level (string-ascii 16)))
  (or 
    (is-eq level "basic")
    (is-eq level "standard")
    (is-eq level "premium")
    (is-eq level "admin")
  )
)

(define-private (calculate-trend (previous-value uint) (current-value uint))
  (begin
    (if (> current-value previous-value)
        "increasing"
        (if (< current-value previous-value)
            "decreasing"
            "stable"
        )
    )
  )
)

(define-private (add-data-point (data-points (list 100 { timestamp: uint, value: uint })) (new-value uint))
  (begin
    ;; Add new data point and maintain max size
    (let ((new-point { timestamp: block-height, value: new-value }))
      (if (>= (len data-points) u100)
          (append (slice data-points u1 (- (len data-points) u1)) new-point)
          (append data-points new-point)
      )
    )
  )
)

(define-private (determine-alert-severity (value uint) (threshold uint))
  (begin
    (let ((percentage (/ (* value u10000) threshold)))
      (if (>= percentage u150) ;; 150% of threshold
          "critical"
          (if (>= percentage u125) ;; 125% of threshold
              "high"
              (if (>= percentage u110) ;; 110% of threshold
                  "medium"
                  "low"
              )
          )
      )
    )
  )
)

(define-private (calculate-system-health)
  (begin
    ;; Calculate overall system health based on metrics and alerts
    (let ((total-metrics (var-get total-metrics))
          (total-alerts (var-get total-alerts)))
      
      (if (> total-metrics u0)
          (let ((alert-ratio (/ (* total-alerts u10000) total-metrics)))
            (if (>= alert-ratio u2000) ;; 20% alert ratio
                u2000 ;; Poor health
                (if (>= alert-ratio u1000) ;; 10% alert ratio
                    u5000 ;; Fair health
                    (if (>= alert-ratio u500) ;; 5% alert ratio
                        u7500 ;; Good health
                        u9500 ;; Excellent health
                    )
                )
            )
          )
          u10000 ;; Default to excellent if no metrics
      )
    )
  )
)

(define-private (get-component-health)
  (begin
    ;; Get health of individual components
    ;; Simplified implementation
    (list 
      { component: "pools", health: u9000 }
      { component: "oracles", health: u9500 }
      { component: "tokens", health: u10000 }
      { component: "trading", health: u8500 }
      { component: "monitoring", health: u10000 }
    )
  )
)

(define-private (collect-metrics-data (metrics (list 20 (string-ascii 32))))
  (begin
    ;; Collect data for specified metrics
    (fold metrics (list 0 { metric-id: (string-ascii 32), value: uint, trend: (string-ascii 8) })
      (lambda ((result (list 20 { metric-id: (string-ascii 32), value: uint, trend: (string-ascii 8) })) (metric-id (string-ascii 32)))
        (let ((metric_info (get-metric metric_id)))
          (if (is-some metric_info)
              (begin
                (let ((metric (unwrap-optional metric_info)))
                  (append result { metric-id: metric-id, value: (get metric value), trend: (get metric trend) })
                )
              )
              result
          )
        )
      )
    )
  )
)

;; Utility functions

(define-read-only (get-dashboard-status)
  {
    active: (var-get dashboard-active),
    total-metrics: (var-get total-metrics),
    total-alerts: (var-get total-alerts),
    last-update: (var-get last-update),
    subscriber-count: u0 // Would count actual subscribers
  }
)

(define-read-only (get-metric-summary (metric_id (string-ascii 32)))
  (match (get-metric metric_id)
    metric
      (ok {
        name: (get metric name),
        category: (get metric category),
        value: (get metric value),
        unit: (get metric unit),
        trend: (get metric trend),
        threshold: (get metric threshold),
        alert-enabled: (get metric alert-enabled),
        last-updated: (get metric last-updated)
      })
    none (err ERR_METRIC_NOT_FOUND)
  )
)

(define-read-only (get-active-alerts)
  (begin
    ;; Return all unacknowledged alerts
    ;; Simplified implementation
    (list 0 { alert-id: (buff 32), metric-id: (string-ascii 32), severity: (string-ascii 16), timestamp: uint })
  )
)
