;; Dimensional Oracle
;; Oracle for dimensional data and metrics

(define-data-var oracle-data { metric: (string-ascii 64) } { value: uint, timestamp: uint, confidence: uint })
(define-map oracle-feeds { feed-id: (string-ascii 32) } { 
  owner: principal,
  last-update: uint,
  update-frequency: uint,
  active: bool
})

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var oracle-registry principal CONTRACT_OWNER)

;; Oracle parameters
(define-constant MAX_CONFIDENCE u10000) ;; 100%
(define-constant MIN_CONFIDENCE u1000) ;; 10%
(define-constant MAX_STALENESS u3600) ;; 1 hour in blocks
(define-constant MIN_UPDATE_FREQUENCY u100) ;; ~5 minutes

;; Events
(define-event (oracle-updated (metric (string-ascii 64)) (value uint) (confidence uint)))
(define-event (feed-registered (feed-id (string-ascii 32)) (owner principal)))
(define-event (feed-deactivated (feed-id (string-ascii 32))))
(define-event (oracle-query (metric (string-ascii 64)) (value uint)))

;; Read-only functions

(define-read-only (get-oracle-data (metric (string-ascii 64)))
  (map-get? oracle-data { metric: metric }))

(define-read-only (get-oracle-value (metric (string-ascii 64)))
  (match (get-oracle-data metric)
    data (ok (get data value))
    none (err 6001)
  )
)

(define-read-only (get-oracle-confidence (metric (string-ascii 64)))
  (match (get-oracle-data metric)
    data (ok (get data confidence))
    none (err 6002)
  )
)

(define-read-only (get-oracle-timestamp (metric (string-ascii 64)))
  (match (get-oracle-data metric)
    data (ok (get data timestamp))
    none (err 6003)
  )
)

(define-read-only (is-oracle-fresh (metric (string-ascii 64)))
  (match (get-oracle-data metric)
    data (ok (< (- block-height (get data timestamp)) MAX_STALENESS))
    none (ok false)
  )
)

(define-read-only (get-feed-info (feed-id (string-ascii 32)))
  (map-get? oracle-feeds { feed-id: feed-id }))

(define-read-only (is-feed-active (feed-id (string-ascii 32)))
  (match (get-feed-info feed-id)
    feed (ok (get feed active))
    none (ok false)
  )
)

(define-read-only (get-feed-owner (feed-id (string-ascii 32)))
  (match (get-feed-info feed-id)
    feed (ok (get feed owner))
    none (err 6004)
  )
)

;; Public functions

(define-public (update-oracle (metric (string-ascii 64)) (value uint) (confidence uint))
  (begin
    ;; Validate inputs
    (asserts! (> value u0) (err 6005))
    (asserts! (>= confidence MIN_CONFIDENCE) (err 6006))
    (asserts! (<= confidence MAX_CONFIDENCE) (err 6007))
    
    ;; Check if caller is authorized (feed owner or admin)
    (let ((feed-id (extract-feed-id metric)))
      (match (get-feed-info feed-id)
        feed
          (begin
            (asserts! (or 
              (is-eq tx-sender (get feed owner))
              (is-eq tx-sender (var-get admin))
              (is-eq tx-sender (var-get oracle-registry))
            ) (err 6008))
            
            ;; Check update frequency
            (asserts! (>= (- block-height (get feed last-update)) (get feed update-frequency)) (err 6009))
            
            ;; Update oracle data
            (map-set oracle-data { metric: metric } {
              value: value,
              timestamp: block-height,
              confidence: confidence
            })
            
            ;; Update feed last update
            (map-set oracle-feeds { feed-id: feed-id } {
              owner: (get feed owner),
              last-update: block-height,
              update-frequency: (get feed update-frequency),
              active: (get feed active)
            })
            
            ;; Emit event
            (emit-event (oracle-updated metric value confidence))
            
            (ok true)
          )
        none (err 6010) ;; Feed not found
      )
    )
  )
)

(define-public (register-feed (feed-id (string-ascii 32)) (update-frequency uint))
  (begin
    ;; Only admin or oracle registry can register feeds
    (asserts! (or 
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender (var-get oracle-registry))
    ) (err 6011))
    
    ;; Validate inputs
    (asserts! (>= update-frequency MIN_UPDATE_FREQUENCY) (err 6012))
    
    ;; Register feed
    (map-set oracle-feeds { feed-id: feed-id } {
      owner: tx-sender,
      last-update: u0,
      update-frequency: update-frequency,
      active: true
    })
    
    ;; Emit event
    (emit-event (feed-registered feed-id tx-sender))
    
    (ok true)
  )
)

(define-public (deactivate-feed (feed-id (string-ascii 32)))
  (begin
    ;; Only feed owner or admin can deactivate
    (match (get-feed-info feed-id)
      feed
        (begin
          (asserts! (or 
            (is-eq tx-sender (get feed owner))
            (is-eq tx-sender (var-get admin))
          ) (err 6013))
          
          ;; Deactivate feed
          (map-set oracle-feeds { feed-id: feed-id } {
            owner: (get feed owner),
            last-update: (get feed last-update),
            update-frequency: (get feed update-frequency),
            active: false
          })
          
          ;; Emit event
          (emit-event (feed-deactivated feed-id))
          
          (ok true)
        )
      none (err 6014) ;; Feed not found
    )
  )
)

(define-public (query-oracle (metric (string-ascii 64)))
  (begin
    ;; Check if oracle data exists and is fresh
    (match (get-oracle-data metric)
      data
        (begin
          (asserts! (is-oracle-fresh metric) (err 6015))
          
          ;; Emit query event
          (emit-event (oracle-query metric (get data value)))
          
          (ok {
            value: (get data value),
            confidence: (get data confidence),
            timestamp: (get data timestamp)
          })
        )
      none (err 6016) ;; No data available
    )
  )
)

(define-public (batch-update-oracle (updates (list 20 { metric: (string-ascii 64), value: uint, confidence: uint })))
  (begin
    ;; Validate list size
    (asserts! (<= (len updates) u20) (err 6017))
    
    ;; Process each update
    (fold updates u0
      (lambda ((result uint) (update { metric: (string-ascii 64), value: uint, confidence: uint }))
        (match (update-oracle (get update metric) (get update value) (get update confidence))
          success (+ result u1)
          error result
        )
      )
    )
    
    (ok true)
  )
)

;; Aggregation functions

(define-public (aggregate-values (metrics (list 10 (string-ascii 64))) (aggregation-type (string-ascii 16)))
  (begin
    ;; Validate aggregation type
    (asserts! (or 
      (is-eq aggregation-type "average")
      (is-eq aggregation-type "median")
      (is-eq aggregation-type "min")
      (is-eq aggregation-type "max")
      (is-eq aggregation-type "sum")
    ) (err 6018))
    
    ;; Get values for all metrics
    (let ((values (map 
      (lambda ((metric (string-ascii 64)))
        (match (get-oracle-value metric)
          value value
          error u0) ;; Use 0 for missing values
      )
      metrics)))
      
      (match aggregation-type
        "average" (ok (/ (fold values u0 +) (len values)))
        "median" (ok (calculate-median values))
        "min" (ok (fold values u1000000000 min))
        "max" (ok (fold values u0 max))
        "sum" (ok (fold values u0 +))
        (err 6019) ;; Invalid aggregation type
      )
    )
  )
)

;; Dimensional-specific functions

(define-public (update-dimension-metric (dimension (string-ascii 32)) (value uint) (confidence uint))
  (let ((metric (concat "dimension-" dimension)))
    (update-oracle metric value confidence))
)

(define-public (get-dimension-value (dimension (string-ascii 32)))
  (let ((metric (concat "dimension-" dimension)))
    (get-oracle-value metric))
  )
)

(define-public (calculate-dimension-score (dimensions (list 10 (string-ascii 32))))
  (begin
    ;; Get values for all dimensions
    (let ((values (map 
      (lambda ((dimension (string-ascii 32)))
        (unwrap-panic (get-dimension-value dimension))
      )
      dimensions)))
      
    ;; Calculate weighted score (simple average for now)
    (ok (/ (fold values u0 +) (len values)))
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 6020))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-oracle-registry (new-registry principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 6021))
    (var-set oracle-registry new-registry)
    (ok true)
  )
)

(define-public (emergency-update (metric (string-ascii 64)) (value uint) (confidence uint))
  (begin
    ;; Only admin can do emergency updates
    (asserts! (is-eq tx-sender (var-get admin)) (err 6022))
    
    ;; Update oracle data without checks
    (map-set oracle-data { metric: metric } {
      value: value,
      timestamp: block-height,
      confidence: confidence
    })
    
    ;; Emit event
    (emit-event (oracle-updated metric value confidence))
    
    (ok true)
  )
)

;; Helper functions

(define-private (extract-feed-id (metric (string-ascii 64)))
  ;; Extract feed ID from metric (simplified)
  (let ((parts (split metric "-")))
    (get (get parts 0) value)
  )
)

(define-private (calculate-median (values (list 10 uint)))
  (begin
    ;; Sort values (simplified - would need proper sorting implementation)
    (let ((sorted-values values))
      (let ((len (len sorted-values)))
        (if (is-eq (mod len u2) u0)
            ;; Even number of values - average of middle two
            (/ (+ (get sorted-values (/ len u2)) (get sorted-values (- (/ len u2) u1))) u2)
            ;; Odd number of values - middle value
            (get sorted-values (/ len u2))
        )
      )
    )
  )
)
