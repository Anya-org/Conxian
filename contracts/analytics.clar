;; Analytics System - Comprehensive Event Processing and Metrics
;; On-chain analytics for vault operations, governance, and bounty activities

;; Constants
(define-constant EVENT_TYPES_VAULT u0)
(define-constant EVENT_TYPES_GOVERNANCE u1)
(define-constant EVENT_TYPES_BOUNTY u2)
(define-constant EVENT_TYPES_TREASURY u3)
(define-constant EVENT_TYPES_TOKEN u4)

(define-constant METRIC_PERIODS_DAILY u0)
(define-constant METRIC_PERIODS_WEEKLY u1)
(define-constant METRIC_PERIODS_MONTHLY u2)

;; Data Variables
(define-data-var event-count uint u0)
(define-data-var dao-governance principal .dao-governance)

;; Event storage
(define-map events
  { id: uint }
  {
    event-type: uint,
    contract-source: principal,
    event-name: (string-ascii 50),
    user: principal,
    amount: uint,
    metadata: (string-utf8 200),
    block-height: uint,
    timestamp: uint
  }
)

;; Aggregated metrics by time period
(define-map period-metrics
  { period-type: uint, period-start: uint }
  {
    vault-deposits: uint,
    vault-withdrawals: uint,
    vault-deposit-volume: uint,
    vault-withdrawal-volume: uint,
    governance-proposals: uint,
    governance-votes: uint,
    bounties-created: uint,
    bounties-completed: uint,
    bounty-rewards-paid: uint,
    unique-users: uint,
    total-events: uint
  }
)

;; User activity tracking
(define-map user-activity
  { user: principal, period-type: uint, period-start: uint }
  {
    deposits: uint,
    withdrawals: uint,
    deposit-volume: uint,
    withdrawal-volume: uint,
    proposals-created: uint,
    votes-cast: uint,
    bounties-created: uint,
    bounties-completed: uint,
    last-activity-block: uint
  }
)

;; Protocol health metrics
(define-map protocol-health
  { metric-name: (string-ascii 30) }
  {
    current-value: uint,
    previous-value: uint,
    trend: int, ;; -1 = decreasing, 0 = stable, 1 = increasing
    last-updated: uint,
    threshold-warning: uint,
    threshold-critical: uint
  }
)

;; Events
(define-private (emit-analytics-event (event-type uint) (event-name (string-ascii 50)) (metadata (string-utf8 200)))
  (print {
    event: "analytics-recorded",
    event-type: event-type,
    event-name: event-name,
    metadata: metadata,
    block: block-height
  })
)

;; Read-only functions
(define-read-only (get-event (id uint))
  (map-get? events { id: id })
)

(define-read-only (get-period-metrics (period-type uint) (period-start uint))
  (default-to
    {
      vault-deposits: u0,
      vault-withdrawals: u0,
      vault-deposit-volume: u0,
      vault-withdrawal-volume: u0,
      governance-proposals: u0,
      governance-votes: u0,
      bounties-created: u0,
      bounties-completed: u0,
      bounty-rewards-paid: u0,
      unique-users: u0,
      total-events: u0
    }
    (map-get? period-metrics { period-type: period-type, period-start: period-start })
  )
)

(define-read-only (get-user-activity (user principal) (period-type uint) (period-start uint))
  (default-to
    {
      deposits: u0,
      withdrawals: u0,
      deposit-volume: u0,
      withdrawal-volume: u0,
      proposals-created: u0,
      votes-cast: u0,
      bounties-created: u0,
      bounties-completed: u0,
      last-activity-block: u0
    }
    (map-get? user-activity { user: user, period-type: period-type, period-start: period-start })
  )
)

(define-read-only (get-protocol-health (metric-name (string-ascii 30)))
  (map-get? protocol-health { metric-name: metric-name })
)

(define-read-only (calculate-period-start (period-type uint) (block-height-ref uint))
  (if (is-eq period-type METRIC_PERIODS_DAILY)
    (- block-height-ref (mod block-height-ref u144)) ;; Daily periods (144 blocks ~= 1 day)
    (if (is-eq period-type METRIC_PERIODS_WEEKLY)
      (- block-height-ref (mod block-height-ref u1008)) ;; Weekly periods (1008 blocks ~= 1 week)
      (- block-height-ref (mod block-height-ref u4320)) ;; Monthly periods (4320 blocks ~= 1 month)
    )
  )
)

;; Public functions for recording events
(define-public (record-vault-event 
  (event-name (string-ascii 50))
  (user principal)
  (amount uint)
  (metadata (string-utf8 200))
)
  (begin
    ;; Only vault contract can record vault events
    (asserts! (is-eq tx-sender .vault) (err u100))
    (unwrap! (record-event EVENT_TYPES_VAULT .vault event-name user amount metadata) (err u201))
    (unwrap! (update-vault-metrics event-name user amount) (err u202))
    (ok true)
  )
)

;; Specialized autonomics adjustment record (syntactic sugar)
(define-public (record-autonomics
  (withdraw-fee uint)
  (deposit-fee uint)
  (utilization uint)
  (reserve-ratio uint)
)
  (begin
    ;; callable by vault or any keeper after an update (no sensitive mutation)
  ;; Record event with empty metadata (string-utf8 0) due to removal of to-string in current dialect
  (unwrap-panic (record-event EVENT_TYPES_VAULT .vault "autonomics" .vault u0 u""))
    (print {
      event: "autonomics-metrics",
      wfee: withdraw-fee,
      dfee: deposit-fee,
      util: utilization,
      reserve: reserve-ratio
    })
    (ok true)
  )
)

(define-public (record-governance-event 
  (event-name (string-ascii 50))
  (user principal)
  (amount uint)
  (metadata (string-utf8 200))
)
  (begin
    ;; Only governance contract can record governance events
    (asserts! (is-eq tx-sender .dao-governance) (err u100))
    (unwrap! (record-event EVENT_TYPES_GOVERNANCE .dao-governance event-name user amount metadata) (err u201))
    (unwrap! (update-governance-metrics event-name user amount) (err u202))
    (ok true)
  )
)

(define-public (record-bounty-event 
  (event-name (string-ascii 50))
  (user principal)
  (amount uint)
  (metadata (string-utf8 200))
)
  (begin
    ;; Only bounty system can record bounty events
    (asserts! (is-eq tx-sender .bounty-system) (err u100))
    (unwrap! (record-event EVENT_TYPES_BOUNTY .bounty-system event-name user amount metadata) (err u201))
    (unwrap! (update-bounty-metrics event-name user amount) (err u202))
    (ok true)
  )
)

(define-public (record-treasury-event 
  (event-name (string-ascii 50))
  (user principal)
  (amount uint)
  (metadata (string-utf8 200))
)
  (begin
    ;; Only treasury contract can record treasury events
    (asserts! (is-eq tx-sender .treasury) (err u100))
    (unwrap! (record-event EVENT_TYPES_TREASURY .treasury event-name user amount metadata) (err u201))
    (ok true)
  )
)

;; Private helper functions
(define-private (record-event 
  (event-type uint)
  (contract-source principal)
  (event-name (string-ascii 50))
  (user principal)
  (amount uint)
  (metadata (string-utf8 200))
)
  (let ((event-id (+ (var-get event-count) u1)))
    (map-set events { id: event-id }
      {
        event-type: event-type,
        contract-source: contract-source,
        event-name: event-name,
        user: user,
        amount: amount,
        metadata: metadata,
        block-height: block-height,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      }
    )
    (var-set event-count event-id)
    (emit-analytics-event event-type event-name metadata)
    (ok event-id)
  )
)

(define-private (update-vault-metrics (event-name (string-ascii 50)) (user principal) (amount uint))
  (begin
    ;; Update daily metrics
    (unwrap-panic (update-period-vault-metrics METRIC_PERIODS_DAILY event-name user amount))
    ;; Update weekly metrics
    (unwrap-panic (update-period-vault-metrics METRIC_PERIODS_WEEKLY event-name user amount))
    ;; Update monthly metrics
    (unwrap-panic (update-period-vault-metrics METRIC_PERIODS_MONTHLY event-name user amount))
    (ok true)
  )
)

(define-private (update-period-vault-metrics (period-type uint) (event-name (string-ascii 50)) (user principal) (amount uint))
  (let (
    (period-start (calculate-period-start period-type block-height))
    (current-metrics (get-period-metrics period-type period-start))
    (current-user-activity (get-user-activity user period-type period-start))
  )
    ;; Update period metrics
    (let ((updated-metrics
      (if (is-eq event-name "deposit")
        (merge current-metrics {
          vault-deposits: (+ (get vault-deposits current-metrics) u1),
          vault-deposit-volume: (+ (get vault-deposit-volume current-metrics) amount),
          total-events: (+ (get total-events current-metrics) u1)
        })
        (if (is-eq event-name "withdraw")
          (merge current-metrics {
            vault-withdrawals: (+ (get vault-withdrawals current-metrics) u1),
            vault-withdrawal-volume: (+ (get vault-withdrawal-volume current-metrics) amount),
            total-events: (+ (get total-events current-metrics) u1)
          })
          current-metrics
        )
      )
    ))
      (map-set period-metrics { period-type: period-type, period-start: period-start } updated-metrics)
    )
    
    ;; Update user activity
    (let ((updated-user-activity
      (if (is-eq event-name "deposit")
        (merge current-user-activity {
          deposits: (+ (get deposits current-user-activity) u1),
          deposit-volume: (+ (get deposit-volume current-user-activity) amount),
          last-activity-block: block-height
        })
        (if (is-eq event-name "withdraw")
          (merge current-user-activity {
            withdrawals: (+ (get withdrawals current-user-activity) u1),
            withdrawal-volume: (+ (get withdrawal-volume current-user-activity) amount),
            last-activity-block: block-height
          })
          current-user-activity
        )
      )
    ))
      (map-set user-activity { user: user, period-type: period-type, period-start: period-start } updated-user-activity)
    )
    (ok true)
  )
)

(define-private (update-governance-metrics (event-name (string-ascii 50)) (user principal) (amount uint))
  (begin
    ;; Update daily metrics
    (unwrap-panic (update-period-governance-metrics METRIC_PERIODS_DAILY event-name user amount))
    ;; Update weekly metrics  
    (unwrap-panic (update-period-governance-metrics METRIC_PERIODS_WEEKLY event-name user amount))
    ;; Update monthly metrics
    (unwrap-panic (update-period-governance-metrics METRIC_PERIODS_MONTHLY event-name user amount))
    (ok true)
  )
)

(define-private (update-period-governance-metrics (period-type uint) (event-name (string-ascii 50)) (user principal) (amount uint))
  (let (
    (period-start (calculate-period-start period-type block-height))
    (current-metrics (get-period-metrics period-type period-start))
    (current-user-activity (get-user-activity user period-type period-start))
  )
    ;; Update period metrics
    (let ((updated-metrics
      (if (is-eq event-name "proposal-created")
        (merge current-metrics {
          governance-proposals: (+ (get governance-proposals current-metrics) u1),
          total-events: (+ (get total-events current-metrics) u1)
        })
        (if (is-eq event-name "vote-cast")
          (merge current-metrics {
            governance-votes: (+ (get governance-votes current-metrics) u1),
            total-events: (+ (get total-events current-metrics) u1)
          })
          current-metrics
        )
      )
    ))
      (map-set period-metrics { period-type: period-type, period-start: period-start } updated-metrics)
    )
    
    ;; Update user activity
    (let ((updated-user-activity
      (if (is-eq event-name "proposal-created")
        (merge current-user-activity {
          proposals-created: (+ (get proposals-created current-user-activity) u1),
          last-activity-block: block-height
        })
        (if (is-eq event-name "vote-cast")
          (merge current-user-activity {
            votes-cast: (+ (get votes-cast current-user-activity) u1),
            last-activity-block: block-height
          })
          current-user-activity
        )
      )
    ))
      (map-set user-activity { user: user, period-type: period-type, period-start: period-start } updated-user-activity)
    )
    (ok true)
  )
)

(define-private (update-bounty-metrics (event-name (string-ascii 50)) (user principal) (amount uint))
  (begin
    ;; Update daily metrics
    (unwrap! (update-period-bounty-metrics METRIC_PERIODS_DAILY event-name user amount) (err u500))
    ;; Update weekly metrics
    (unwrap! (update-period-bounty-metrics METRIC_PERIODS_WEEKLY event-name user amount) (err u500))
    ;; Update monthly metrics
    (unwrap! (update-period-bounty-metrics METRIC_PERIODS_MONTHLY event-name user amount) (err u500))
    (ok true)
  )
)

(define-private (update-period-bounty-metrics (period-type uint) (event-name (string-ascii 50)) (user principal) (amount uint))
  (let (
    (period-start (calculate-period-start period-type block-height))
    (current-metrics (get-period-metrics period-type period-start))
    (current-user-activity (get-user-activity user period-type period-start))
  )
    ;; Update period metrics
    (let ((updated-metrics
      (if (is-eq event-name "bounty-created")
        (merge current-metrics {
          bounties-created: (+ (get bounties-created current-metrics) u1),
          total-events: (+ (get total-events current-metrics) u1)
        })
        (if (is-eq event-name "bounty-completed")
          (merge current-metrics {
            bounties-completed: (+ (get bounties-completed current-metrics) u1),
            bounty-rewards-paid: (+ (get bounty-rewards-paid current-metrics) amount),
            total-events: (+ (get total-events current-metrics) u1)
          })
          current-metrics
        )
      )
    ))
      (map-set period-metrics { period-type: period-type, period-start: period-start } updated-metrics)
    )
    
    ;; Update user activity
    (let ((updated-user-activity
      (if (is-eq event-name "bounty-created")
        (merge current-user-activity {
          bounties-created: (+ (get bounties-created current-user-activity) u1),
          last-activity-block: block-height
        })
        (if (is-eq event-name "bounty-completed")
          (merge current-user-activity {
            bounties-completed: (+ (get bounties-completed current-user-activity) u1),
            last-activity-block: block-height
          })
          current-user-activity
        )
      )
    ))
      (map-set user-activity { user: user, period-type: period-type, period-start: period-start } updated-user-activity)
      (ok true)
    )
  )
)

;; Protocol health monitoring
(define-public (update-protocol-health 
  (metric-name (string-ascii 30))
  (new-value uint)
  (warning-threshold uint)
  (critical-threshold uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    
    (let ((current-health (get-protocol-health metric-name)))
      (match current-health
        health (let (
          (previous-value (get current-value health))
          (trend (if (> new-value previous-value) 1 (if (< new-value previous-value) -1 0)))
        )
        (map-set protocol-health { metric-name: metric-name }
          {
            current-value: new-value,
            previous-value: previous-value,
            trend: trend,
            last-updated: block-height,
            threshold-warning: warning-threshold,
            threshold-critical: critical-threshold
          }
        ))
        ;; First time setting this metric
        (map-set protocol-health { metric-name: metric-name }
          {
            current-value: new-value,
            previous-value: u0,
            trend: 0,
            last-updated: block-height,
            threshold-warning: warning-threshold,
            threshold-critical: critical-threshold
          }
        )
      )
    )
    
    (print {
      event: "protocol-health-updated",
      metric-name: metric-name,
      value: new-value,
      block: block-height
    })
    (ok true)
  )
)

;; Analytics queries
(define-read-only (get-vault-utilization-trend (periods uint))
  ;; Calculate vault utilization over multiple periods
  (let ((current-period (calculate-period-start METRIC_PERIODS_DAILY block-height)))
    ;; This would need recursive implementation for multiple periods
    (get-period-metrics METRIC_PERIODS_DAILY current-period)
  )
)

(define-read-only (get-top-contributors (period-type uint) (period-start uint))
  ;; This would need additional data structures to efficiently query top contributors
  ;; For now, return placeholder
  { message: "Top contributors query - requires additional indexing" }
)

(define-read-only (get-governance-participation-rate (period-type uint) (period-start uint))
  (let (
    (metrics (get-period-metrics period-type period-start))
    (total-proposals (get governance-proposals metrics))
    (total-votes (get governance-votes metrics))
  )
  {
    proposals: total-proposals,
    votes: total-votes,
    CXG-votes-per-proposal: (if (is-eq total-proposals u0) u0 (/ total-votes total-proposals))
  })
)

;; Configuration
(define-public (set-dao-governance (new-dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set dao-governance new-dao)
    (ok true)
  )
)

;; Errors
;; u100: unauthorized
