;; Enterprise Monitoring Extensions for AutoVault DEX
;; Advanced analytics, alerts, and performance tracking for enterprise users

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_INVALID_THRESHOLD u402)
(define-constant ERR_ALERT_NOT_FOUND u403)

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var monitoring-enabled bool true)
(define-data-var alert-count uint u0)

;; Enterprise metrics tracking
(define-map performance-metrics
  { metric-type: (string-ascii 20), period: uint }
  {
    value: uint,
    timestamp: uint,
    trend: int, ;; positive/negative trend indicator
    alert-threshold: uint
  }
)

;; Alert configuration
(define-map alert-config
  { alert-id: uint }
  {
    name: (string-ascii 50),
    metric-type: (string-ascii 20),
    threshold-high: uint,
    threshold-low: uint,
    enabled: bool,
    last-triggered: uint
  }
)

;; Active alerts
(define-map active-alerts
  { alert-id: uint }
  {
    triggered-at: uint,
    metric-value: uint,
    severity: (string-ascii 10), ;; "LOW", "MEDIUM", "HIGH", "CRITICAL"
    acknowledged: bool
  }
)

;; Enterprise user monitoring
(define-map enterprise-users
  { user: principal }
  {
    tier: (string-ascii 20), ;; "INSTITUTIONAL", "PROFESSIONAL", "RETAIL"
    volume-limit: uint,
    daily-volume: uint,
    last-reset: uint,
    alerts-enabled: bool
  }
)

;; Performance dashboard data
(define-map dashboard-metrics
  { user: principal, metric: (string-ascii 30) }
  {
    current-value: uint,
    daily-change: int,
    weekly-change: int,
    monthly-change: int,
    last-updated: uint
  }
)

;; Authorization check
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Enterprise monitoring functions
(define-public (update-performance-metric 
  (metric-type (string-ascii 20)) 
  (period uint) 
  (value uint) 
  (threshold uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    ;; Calculate trend (simplified)
    (let ((previous-metric (map-get? performance-metrics { metric-type: metric-type, period: (- period u1) })))
      (let ((trend (match previous-metric
                     prev (if (> value (get value prev)) 1 -1)
                     0)))
        
        (map-set performance-metrics 
          { metric-type: metric-type, period: period }
          {
            value: value,
            timestamp: block-height,
            trend: trend,
            alert-threshold: threshold
          })
        
        ;; Check for alert conditions
        (if (or (> value threshold) (< value (/ threshold u2)))
          (begin
            (unwrap! (trigger-alert metric-type value threshold) (err u500))
            (ok true))
          (ok true))
        
        (print {
          event: "performance-metric-updated",
          metric-type: metric-type,
          value: value,
          trend: trend,
          period: period
        })
        (ok true)))))

;; Alert management
(define-public (create-alert 
  (name (string-ascii 50))
  (metric-type (string-ascii 20))
  (threshold-high uint)
  (threshold-low uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> threshold-high threshold-low) (err ERR_INVALID_THRESHOLD))
    
    (let ((alert-id (+ (var-get alert-count) u1)))
      (map-set alert-config
        { alert-id: alert-id }
        {
          name: name,
          metric-type: metric-type,
          threshold-high: threshold-high,
          threshold-low: threshold-low,
          enabled: true,
          last-triggered: u0
        })
      
      (var-set alert-count alert-id)
      (print {
        event: "alert-created",
        alert-id: alert-id,
        name: name,
        metric-type: metric-type
      })
      (ok alert-id))))

(define-public (trigger-alert (metric-type (string-ascii 20)) (value uint) (threshold uint))
  (let (
    (alert-id (+ (var-get alert-count) u1))
    (severity (if (> value (* threshold u2)) "CRITICAL" "WARNING"))
  )
    (map-set active-alerts
      { alert-id: alert-id }
      {
        triggered-at: block-height,
        metric-value: value,
        severity: severity,
        acknowledged: false
      })
    
    (var-set alert-count alert-id)
    (print {
      event: "alert-triggered",
      alert-id: alert-id,
      metric-type: metric-type,
      value: value,
      severity: severity
    })
    (ok alert-id)
  )
)

;; Enterprise user management
(define-public (register-enterprise-user 
  (user principal)
  (tier (string-ascii 20))
  (volume-limit uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    (map-set enterprise-users
      { user: user }
      {
        tier: tier,
        volume-limit: volume-limit,
        daily-volume: u0,
        last-reset: block-height,
        alerts-enabled: true
      })
    
    (print {
      event: "enterprise-user-registered",
      user: user,
      tier: tier,
      volume-limit: volume-limit
    })
    (ok true)))

;; Dashboard metrics update
(define-public (update-dashboard-metric
  (user principal)
  (metric (string-ascii 30))
  (current-value uint)
  (daily-change int)
  (weekly-change int)
  (monthly-change int))
  (begin
    (map-set dashboard-metrics
      { user: user, metric: metric }
      {
        current-value: current-value,
        daily-change: daily-change,
        weekly-change: weekly-change,
        monthly-change: monthly-change,
        last-updated: block-height
      })
    
    (print {
      event: "dashboard-metric-updated",
      user: user,
      metric: metric,
      value: current-value
    })
    (ok true)))

;; Volume tracking for enterprise users
(define-public (track-user-volume (user principal) (volume uint))
  (let ((user-data (map-get? enterprise-users { user: user })))
    (match user-data
      user-info
        (let ((current-volume (get daily-volume user-info))
              (volume-limit (get volume-limit user-info))
              (last-reset (get last-reset user-info)))
          
          ;; Reset daily volume if new day (simplified - every 144 blocks)
          (let ((new-volume (if (> (- block-height last-reset) u144) volume (+ current-volume volume))))
            (asserts! (<= new-volume volume-limit) (err u301)) ;; Volume limit exceeded
            
            (map-set enterprise-users
              { user: user }
              (merge user-info {
                daily-volume: new-volume,
                last-reset: (if (> (- block-height last-reset) u144) block-height last-reset)
              }))
            
            (print {
              event: "user-volume-tracked",
              user: user,
              volume: volume,
              daily-total: new-volume,
              limit: volume-limit
            })
            (ok new-volume)))
      (ok u0)))) ;; User not registered

;; Real-time performance analytics
(define-public (calculate-performance-score (user principal))
  (let ((tvl-metric (get-dashboard-metric user "TVL"))
        (volume-metric (get-dashboard-metric user "VOLUME"))
        (fees-metric (get-dashboard-metric user "FEES")))
    
    (let ((score (+ 
                  (/ (default-to u0 tvl-metric) u1000000) ;; TVL component
                  (/ (default-to u0 volume-metric) u100000) ;; Volume component  
                  (/ (default-to u0 fees-metric) u10000)))) ;; Fees component
      
      (print {
        event: "performance-score-calculated",
        user: user,
        score: score,
        block: block-height
      })
      (ok score))))

;; Read-only functions
(define-read-only (get-performance-metric (metric-type (string-ascii 20)) (period uint))
  (map-get? performance-metrics { metric-type: metric-type, period: period }))

(define-read-only (get-alert-config (alert-id uint))
  (map-get? alert-config { alert-id: alert-id }))

(define-read-only (get-active-alert (alert-id uint))
  (map-get? active-alerts { alert-id: alert-id }))

(define-read-only (get-enterprise-user (user principal))
  (map-get? enterprise-users { user: user }))

(define-read-only (get-dashboard-metric (user principal) (metric (string-ascii 30)))
  (get current-value (map-get? dashboard-metrics { user: user, metric: metric })))

(define-read-only (is-monitoring-enabled)
  (var-get monitoring-enabled))

;; Advanced analytics functions
(define-read-only (get-trend-analysis (metric-type (string-ascii 20)) (periods uint))
  (let ((current-period (var-get alert-count))) ;; Using alert-count as period counter
    (let ((trends (map get-period-trend (list u1 u2 u3 u4 u5))))
      {
        metric-type: metric-type,
        periods-analyzed: periods,
        trend-direction: (fold + trends 0),
        analysis-timestamp: block-height
      })))

(define-private (get-period-trend (period uint))
  (let ((metric (get-performance-metric "VOLUME" period)))
    (match metric
      m (get trend m)
      0)))

;; Risk assessment
(define-read-only (assess-user-risk (user principal))
  (let ((user-data (get-enterprise-user user)))
    (match user-data
      data
        (let ((volume-ratio (/ (get daily-volume data) (max (get volume-limit data) u1)))
              (risk-score (if (> volume-ratio u8000) u100 ;; High risk if >80% of limit
                           (if (> volume-ratio u5000) u60  ;; Medium risk if >50% of limit
                            u20))))                        ;; Low risk otherwise
          {
            user: user,
            risk-score: risk-score,
            volume-utilization: volume-ratio,
            tier: (get tier data)
          })
      {
        user: user,
        risk-score: u0,
        volume-utilization: u0,
        tier: "UNREGISTERED"
      })))

(define-private (max (a uint) (b uint))
  (if (> a b) a b))
