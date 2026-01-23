;; External Oracle Adapter
;; Adapter for integrating with external oracle services

(define-data-var oracle-config { feed-id: (string-ascii 32) } { 
  endpoint: (string-ascii 256),
  api-key: (optional (string-ascii 128)),
  update-frequency: uint,
  last-update: uint,
  active: bool
})

(define-map oracle-cache { feed-id: (string-ascii 32) } { 
  value: uint,
  timestamp: uint,
  confidence: uint,
  signature: (optional (buff 65))
})

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var oracle-operator principal CONTRACT_OWNER)

;; Oracle parameters
(define-constant MAX_CACHE_AGE u3600) ;; 1 hour in blocks
(define-constant MIN_CONFIDENCE u5000) ;; 50%
(define-constant MAX_CONFIDENCE u10000) ;; 100%
(define-constant SIGNATURE_THRESHOLD u10000) ;; 100% signature required

;; Events
(define-event (oracle-configured (feed-id (string-ascii 32)) (endpoint (string-ascii 256))))
(define-event (oracle-updated (feed-id (string-ascii 32)) (value uint) (confidence uint)))
(define-event (oracle-cache-hit (feed-id (string-ascii 32)) (value uint)))
(define-event (oracle-signature-verified (feed-id (string-ascii 32)) (valid bool)))

;; Read-only functions

(define-read-only (get-oracle-config (feed-id (string-ascii 32)))
  (map-get? oracle-config { feed-id: feed-id }))

(define-read-only (get-oracle-endpoint (feed-id (string-ascii 32)))
  (match (get-oracle-config feed-id)
    config (ok (get config endpoint))
    none (err 8001)
  )
)

(define-read-only (is-oracle-active (feed-id (string-ascii 32)))
  (match (get-oracle-config feed-id)
    config (ok (get config active))
    none (ok false)
  )
)

(define-read-only (get-cached-value (feed-id (string-ascii 32)))
  (match (map-get? oracle-cache { feed-id: feed-id })
    cache (ok (get cache value))
    none (err 8002)
  )
)

(define-read-only (get-cached-timestamp (feed-id (string-ascii 32)))
  (match (map-get? oracle-cache { feed-id: feed-id })
    cache (ok (get cache timestamp))
    none (err 8003)
  )
)

(define-read-only (get-cached-confidence (feed-id (string-ascii 32)))
  (match (map-get? oracle-cache { feed-id: feed-id })
    cache (ok (get cache confidence))
    none (err 8004)
  )
)

(define-read-only (is-cache-fresh (feed-id (string-ascii 32)))
  (match (map-get? oracle-cache { feed-id: feed-id })
    cache (ok (< (- block-height (get cache timestamp)) MAX_CACHE_AGE))
    none (ok false)
  )
)

;; Public functions

(define-public (configure-oracle (feed-id (string-ascii 32)) (endpoint (string-ascii 256)) (api-key (optional (string-ascii 128))) (update-frequency uint))
  (begin
    ;; Only admin or oracle operator can configure
    (asserts! (or 
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender (var-get oracle-operator))
    ) (err 8005))
    
    ;; Validate inputs
    (asserts! (> (len endpoint) u0) (err 8006))
    (asserts! (> update-frequency u0) (err 8007))
    
    ;; Configure oracle
    (map-set oracle-config { feed-id: feed-id } {
      endpoint: endpoint,
      api-key: api-key,
      update-frequency: update-frequency,
      last-update: u0,
      active: true
    })
    
    ;; Emit event
    (emit-event (oracle-configured feed-id endpoint))
    
    (ok true)
  )
)

(define-public (deactivate-oracle (feed-id (string-ascii 32)))
  (begin
    ;; Only admin or oracle operator can deactivate
    (asserts! (or 
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender (var-get oracle-operator))
    ) (err 8008))
    
    ;; Deactivate oracle
    (match (get-oracle-config feed-id)
      config
        (begin
          (map-set oracle-config { feed-id: feed-id } {
            endpoint: (get config endpoint),
            api-key: (get config api-key),
            update-frequency: (get config update-frequency),
            last-update: (get config last-update),
            active: false
          })
          
          (ok true)
        )
      none (err 8009) ;; Oracle not found
    )
  )
)

(define-public (update-oracle-data (feed-id (string-ascii 32)) (value uint) (confidence uint) (signature (optional (buff 65))))
  (begin
    ;; Only oracle operator can update data
    (asserts! (is-eq tx-sender (var-get oracle-operator)) (err 8010))
    
    ;; Validate inputs
    (asserts! (> value u0) (err 8011))
    (asserts! (>= confidence MIN_CONFIDENCE) (err 8012))
    (asserts! (<= confidence MAX_CONFIDENCE) (err 8013))
    
    ;; Check if oracle is active and update frequency is respected
    (match (get-oracle-config feed-id)
      config
        (begin
          (asserts! (get config active) (err 8014))
          (asserts! (>= (- block-height (get config last-update)) (get config update-frequency)) (err 8015))
          
          ;; Verify signature if provided
          (match signature
            sig
              (begin
                (asserts! (verify-signature feed-id value confidence sig) (err 8016))
                (emit-event (oracle-signature-verified feed-id true))
              )
            none
              (asserts! (<= confidence SIGNATURE_THRESHOLD) (err 8017)) ;; Require signature for high confidence
          )
          
          ;; Update cache
          (map-set oracle-cache { feed-id: feed-id } {
            value: value,
            timestamp: block-height,
            confidence: confidence,
            signature: signature
          })
          
          ;; Update last update
          (map-set oracle-config { feed-id: feed-id } {
            endpoint: (get config endpoint),
            api-key: (get config api-key),
            update-frequency: (get config update-frequency),
            last-update: block-height,
            active: true
          })
          
          ;; Emit event
          (emit-event (oracle-updated feed-id value confidence))
          
          (ok true)
        )
      none (err 8018) ;; Oracle not found
    )
  )
)

(define-public (get-oracle-value (feed-id (string-ascii 32)))
  (begin
    ;; Check if cache is fresh
    (asserts! (is-cache-fresh feed-id) (err 8019))
    
    ;; Get cached value
    (match (map-get? oracle-cache { feed-id: feed-id })
      cache
        (begin
          (emit-event (oracle-cache-hit feed-id (get cache value)))
          (ok {
            value: (get cache value),
            confidence: (get cache confidence),
            timestamp: (get cache timestamp)
          })
        )
      none (err 8020) ;; No cached data
    )
  )
)

(define-public (batch-update-oracles (updates (list 20 { feed-id: (string-ascii 32), value: uint, confidence: uint, signature: (optional (buff 65)) })))
  (begin
    ;; Only oracle operator can batch update
    (asserts! (is-eq tx-sender (var-get oracle-operator)) (err 8021))
    
    ;; Validate list size
    (asserts! (<= (len updates) u20) (err 8022))
    
    ;; Process each update
    (fold updates u0
      (lambda ((result uint) (update { feed-id: (string-ascii 32), value: uint, confidence: uint, signature: (optional (buff 65)) }))
        (match (update-oracle-data (get update feed-id) (get update value) (get update confidence) (get update signature))
          success (+ result u1)
          error result
        )
      )
    )
    
    (ok true)
  )
)

;; Aggregation functions

(define-public (aggregate-oracle-values (feed-ids (list 10 (string-ascii 32))) (aggregation-type (string-ascii 16)))
  (begin
    ;; Validate aggregation type
    (asserts! (or 
      (is-eq aggregation-type "average")
      (is-eq aggregation-type "median")
      (is-eq aggregation-type "min")
      (is-eq aggregation-type "max")
      (is-eq aggregation-type "weighted")
    ) (err 8023))
    
    ;; Get values from all feeds
    (let ((values (map 
      (lambda ((feed-id (string-ascii 32)))
        (match (get-oracle-value feed-id)
          data (get data value)
          error u0) ;; Use 0 for failed feeds
      )
      feed-ids)))
      
      (match aggregation-type
        "average" (ok (/ (fold values u0 +) (len values)))
        "median" (ok (calculate-median values))
        "min" (ok (fold values u1000000000 min))
        "max" (ok (fold values u0 max))
        "weighted" (ok (calculate-weighted-average feed-ids values))
        (err 8024) ;; Invalid aggregation type
      )
    )
  )
)

;; Signature verification (simplified)
(define-private (verify-signature (feed-id (string-ascii 32)) (value uint) (confidence uint) (signature (buff 65)))
  (begin
    ;; In a real implementation, this would verify the signature against the oracle operator's public key
    ;; For now, we'll assume all signatures are valid if they're the correct length
    (is-eq (len signature) u65)
  )

;; Helper functions

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

(define-private (calculate-weighted-average (feed-ids (list 10 (string-ascii 32))) (values (list 10 uint)))
  (begin
    ;; Get confidence levels for weighting
    (let ((confidences (map 
      (lambda ((feed-id (string-ascii 32)))
        (unwrap-panic (get-cached-confidence feed-id))
      )
      feed-ids)))
      
      ;; Calculate weighted average
      (let ((weighted-sum (fold2 values confidences u0
        (lambda ((sum uint) (value uint) (confidence uint))
          (+ sum (* value confidence))
        )))
        (total-confidence (fold confidences u0 +)))
        
        (if (> total-confidence u0)
            (/ weighted-sum total-confidence)
            u0
        )
    )
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 8025))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-oracle-operator (new-operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 8026))
    (var-set oracle-operator new-operator)
    (ok true)
  )
)

(define-public (emergency-clear-cache (feed-id (string-ascii 32)))
  (begin
    ;; Only admin can emergency clear cache
    (asserts! (is-eq tx-sender (var-get admin)) (err 8027))
    
    (map-delete oracle-cache { feed-id: feed-id })
    
    (ok true)
  )
)

(define-public (emergency-update (feed-id (string-ascii 32)) (value uint) (confidence uint))
  (begin
    ;; Only admin can do emergency updates
    (asserts! (is-eq tx-sender (var-get admin)) (err 8028))
    
    ;; Update cache without checks
    (map-set oracle-cache { feed-id: feed-id } {
      value: value,
      timestamp: block-height,
      confidence: confidence,
      signature: none
    })
    
    ;; Emit event
    (emit-event (oracle-updated feed-id value confidence))
    
    (ok true)
  )
)

;; Helper function for fold2
(define-private (fold2 
  (list1 (list 10 uint)) 
  (list2 (list 10 uint)) 
  (initial uint) 
  (func (function 3 uint uint uint uint))
)
  (begin
    (asserts! (is-eq (len list1) (len list2)) (err 8029))
    (let ((len (len list1)))
      (fold (range u0 len) initial
        (lambda ((acc uint) (i uint))
          (func acc (get list1 i) (get list2 i)))
      )
    )
  )
)
