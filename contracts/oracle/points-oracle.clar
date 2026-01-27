;; points-oracle.clar
;; Conxian Protocol: Points-based oracle for gamification and rewards

;; Dependencies
(use-trait oracle-trait .oracle-trait.oracle-trait)

;; Constants
(define-constant ERR_INVALID_POINTS (err 21001))
(define-constant ERR_INSUFFICIENT_PERMISSIONS (err 21002))
(define-constant ERR_POINTS_NOT_AVAILABLE (err 21003))
(define-constant ERR_INVALID_RECIPIENT (err 21004))
(define-constant ERR_POINTS_EXPIRED (err 21005))

;; Points system parameters
(define-constant POINTS_PRECISION u1000000) ;; 6 decimal places
(define-constant MAX_POINTS_PER_TRANSACTION u100000000) ;; 100 points max
(define-constant POINTS_EXPIRY_BLOCKS u10080) ;; 1 day expiry
(define-constant MIN_POINTS_THRESHOLD u1000) ;; Minimum points for rewards
(define-constant POINTS_DECAY_RATE u100) ;; 0.01% decay per block

;; Data variables
(define-data-var total-points-issued uint u0)
(define-data-var total-points-burned uint u0)
(define-data-var points-decay-enabled bool true)
(define-data-var last-decay-block uint u0)

(define-data-var conxian-protocol-contract principal .conxian-protocol)

;; Event definitions
(define-map points-earned { event-id: uint } { user: principal, amount: uint, source: (string-ascii 16) })
(define-map points-burned { event-id: uint } { user: principal, amount: uint, reason: (string-ascii 16) })
(define-map points-transferred { event-id: uint } { from: principal, to: principal, amount: uint })
(define-map reward-claimed { event-id: uint } { user: principal, reward-id: uint, cost: uint })

;; Storage maps
(define-map user-points { user: principal } { 
  balance: uint,
  earned: uint,
  burned: uint,
  last-activity: uint,
  points-tier: uint,
  expiry-block: uint
})

(define-map points-transactions { tx-id: (buff 32) } { 
  from: principal,
  to: principal,
  amount: uint,
  timestamp: uint,
  transaction-type: (string-ascii 16),
  metadata: (optional (string-ascii 256))
})

(define-map points-rewards { reward-id: (string-ascii 32) } { 
  name: (string-ascii 64),
  description: (string-ascii 256),
  points-cost: uint,
  reward-type: (string-ascii 16),
  active: bool,
  max-claims: uint,
  claims-used: uint
})

(define-map user-rewards { user: principal, reward-id: (string-ascii 32) } { 
  claimed-at: uint,
  claim-count: uint
})

(define-map points-tiers { tier: uint } { 
  name: (string-ascii 32),
  min-points: uint,
  benefits: (list 10 (string-ascii 64)),
  decay-rate: uint
})

;; Events
;; (points-earned (user principal) (amount uint) (source (string-ascii 16)))
;; (points-burned (user principal) (amount uint) (reason (string-ascii 16)))
;; (points-transferred (from principal) (to principal) (amount uint)))
;; (reward-claimed (user principal) (reward-id (string-ascii 32)) (points-cost uint)))
;; (tier-upgraded (user principal) (old-tier uint) (new-tier uint)))
;; (points-decayed (user principal) (amount uint)))

;; Read-only functions

(define-read-only (get-user-points (user principal))
  (ok (default-to u0 (map-get? user-points { user: user })))
)

(define-read-only (get-points-balance (user principal))
  (match (get-user-points user)
    points (ok (get points balance))
    none (ok u0)
  )
)

(define-read-only (get-points-tier (user principal))
  (match (get-user-points user)
    points (ok (get points points-tier))
    none (ok u0)
  )
)

(define-read-only (get-points-earned (user principal))
  (match (get-user-points user)
    points (ok (get points earned))
    none (ok u0)
  )
)

(define-read-only (get-points-burned (user principal))
  (match (get-user-points user)
    points (ok (get points burned))
    none (ok u0)
  )
)

(define-read-only (get-reward-info (reward-id (string-ascii 32)))
  (map-get? points-rewards { reward-id: reward-id }))

(define-read-only (get-tier-info (tier uint))
  (map-get? points-tiers { tier: tier }))

(define-read-only (get-user-reward-claim (user principal) (reward-id (string-ascii 32)))
  (map-get? user-rewards { user: user, reward-id: reward-id }))

(define-read-only (get-total-points-issued)
  (var-get total-points-issued))

(define-read-only (get-total-points-burned)
  (var-get total-points-burned))

(define-read-only (is-decay-enabled)
  (var-get points-decay-enabled))

(define-read-only (calculate-user-tier (user principal))
  (begin
    (let ((points-balance (unwrap! (get-points-balance user) (err ERR_POINTS_NOT_AVAILABLE))))
      (ok (if (>= points-balance u1000000) ;; 100+ points = Gold tier
          u3
          (if (>= points-balance u100000) ;; 10+ points = Silver tier
              u2
              (if (>= points-balance u10000) ;; 1+ points = Bronze tier
                  u1
                  u0 ;; No tier
              )
          )
      ))
    )
  )
)

;; Public functions

(define-public (award-points (user principal) (amount uint) (source (string-ascii 16)))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_POINTS)
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) ERR_INVALID_POINTS)
    
    ;; Check permissions (simplified - would use proper access control)
    (asserts! true ERR_INSUFFICIENT_PERMISSIONS) ;; Mock implementation
    
    ;; Get current user points
    (let ((current-points (get-user-points user)))
      (let ((current-balance (if (is-some current-points) (unwrap! (get-points-balance user)) u0))
            (current-earned (if (is-some current-points) (unwrap! (get-points-earned user)) u0))
            (current-tier (calculate-user-tier user)))
        
        ;; Update user points
        (map-set user-points { user: user } {
          balance: (+ current-balance amount),
          earned: (+ current-earned amount),
          burned: (if (is-some current-points) (unwrap! (get-points-burned user)) u0),
          last-activity: block-height,
          points-tier: current-tier,
          expiry-block: (+ block-height POINTS_EXPIRY_BLOCKS)
        })
        
        ;; Update totals
        (var-set total-points-issued (+ (var-get total-points-issued) amount))
        
        ;; Emit event
        (map-set points-earned { event-id: block-height } { user: user, amount: amount, source: source })
        
        (ok {
          new-balance: (+ current-balance amount),
          total-earned: (+ current-earned amount),
          tier: current-tier
        })
      )
    )
  )
)

(define-public (burn-points (amount uint) (reason (string-ascii 16)))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_POINTS)
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) ERR_INVALID_POINTS)
    
    ;; Get current user points
    (let ((current-points (get-user-points tx-sender)))
      (asserts! (is-some current-points) ERR_POINTS_NOT_AVAILABLE)
      
      (let ((current-balance (unwrap! (get-points-balance tx-sender) (err ERR_POINTS_NOT_AVAILABLE)))
            (current-burned (unwrap! (get-points-burned tx-sender) (err ERR_POINTS_NOT_AVAILABLE))))
        
        ;; Check sufficient balance
        (asserts! (>= current-balance amount) ERR_POINTS_NOT_AVAILABLE)
        
        ;; Update user points
        (map-set user-points { user: tx-sender } {
          balance: (- current-balance amount),
          earned: (unwrap! (get-points-earned tx-sender) (err ERR_POINTS_NOT_AVAILABLE)),
          burned: (+ current-burned amount),
          last-activity: block-height,
          points-tier: (unwrap! (calculate-user-tier tx-sender) (err ERR_POINTS_NOT_AVAILABLE)),
          expiry-block: (get (unwrap! current-points (err ERR_POINTS_NOT_AVAILABLE)) expiry-block)
        })
        
        ;; Update totals
        (var-set total-points-burned (+ (var-get total-points-burned) amount))
        
        ;; Emit event
        (map-set points-burned { event-id: block-height } { user: tx-sender, amount: amount, reason: reason })
        
        (ok {
          new-balance: (- current-balance amount),
          total-burned: (+ current-burned amount)
        })
      )
    )
  )
)

(define-public (transfer-points (to principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) ERR_INVALID_POINTS)
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) ERR_INVALID_POINTS)
    (asserts! (not (is-eq tx-sender to)) ERR_INVALID_RECIPIENT)
    
    ;; Get current user points
    (let ((sender-points (get-user-points tx-sender)))
      (asserts! (is-some sender-points) ERR_POINTS_NOT_AVAILABLE)
      
      (let ((sender-balance (unwrap! (get-points-balance tx-sender) (err ERR_POINTS_NOT_AVAILABLE)))
            (receiver-points (get-user-points to)))
        
        ;; Check sufficient balance
        (asserts! (>= sender-balance amount) ERR_POINTS_NOT_AVAILABLE)
        
        ;; Update sender points
        (map-set user-points { user: tx-sender } {
          balance: (- sender-balance amount),
          earned: (unwrap! (get-points-earned tx-sender) (err ERR_POINTS_NOT_AVAILABLE)),
          burned: (unwrap! (get-points-burned tx-sender) (err ERR_POINTS_NOT_AVAILABLE)),
          last-activity: block-height,
          points-tier: (unwrap! (calculate-user-tier tx-sender) (err ERR_POINTS_NOT_AVAILABLE)),
          expiry-block: (get sender-points expiry-block)
        })
        
        ;; Update receiver points
        (let ((receiver-balance (if (is-some receiver-points) (unwrap! (get-points-balance to) (err ERR_POINTS_NOT_AVAILABLE)) u0)))
          (map-set user-points { user: to } {
            balance: (+ receiver-balance amount),
            earned: (if (is-some receiver-points) (unwrap! (get-points-earned to) (err ERR_POINTS_NOT_AVAILABLE)) u0),
            burned: (if (is-some receiver-points) (unwrap! (get-points-burned to) (err ERR_POINTS_NOT_AVAILABLE)) u0),
            last-activity: block-height,
            points-tier: (unwrap! (calculate-user-tier to) (err ERR_POINTS_NOT_AVAILABLE)),
            expiry-block: (+ block-height POINTS_EXPIRY_BLOCKS)
          })
        )
        
        ;; Record transaction
        (let ((tx-id (hash160 (concat (principal-to-buff? tx-sender) (principal-to-buff? to)))))
          (map-set points-transactions { tx-id: tx-id } {
            from: tx-sender,
            to: to,
            amount: amount,
            timestamp: block-height,
            transaction-type: "transfer",
            metadata: none
          })
        )
        
        ;; Emit event
        (map-set points-transferred { event-id: block-height } { from: tx-sender, to: to, amount: amount })
        
        (ok {
          sender-balance: (- sender-balance amount),
          receiver-balance: (+ receiver-balance amount)
        })
      )
    )
  )
)

(define-public (claim-reward (reward-id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len reward-id) u0) ERR_INVALID_POINTS)
    
    ;; Check if reward exists and is active
    (let ((reward-info (get-reward-info reward-id)))
      (asserts! (is-some reward-info) ERR_POINTS_NOT_AVAILABLE)
      
      (let ((reward (unwrap! reward-info (err ERR_POINTS_NOT_AVAILABLE))))
        (asserts! (get reward active) ERR_POINTS_NOT_AVAILABLE)
        
        ;; Check if user has sufficient points
        (let ((user-balance (unwrap! (get-points-balance tx-sender) (err ERR_POINTS_NOT_AVAILABLE))))
          (asserts! (>= user-balance (get reward points-cost)) ERR_POINTS_NOT_AVAILABLE)
          
          ;; Check claim limits
          (let ((user-claim (get-user-reward-claim tx-sender reward-id)))
            (if (is-some user-claim)
                (asserts!
                  (< (get claim-count (unwrap! user-claim (err ERR_POINTS_NOT_AVAILABLE)))
                    (get reward max-claims)
                  )
                  ERR_POINTS_NOT_AVAILABLE
                )
                true ;; First time claiming
            )
            
            ;; Burn points for reward
            (match (burn-points (get reward points-cost) "reward-claim")
              success
                (begin
                  ;; Update user reward claim
                  (let ((current-claims (if (is-some user-claim) (get claim-count (unwrap! user-claim (err ERR_POINTS_NOT_AVAILABLE))) u0)))
                    (map-set user-rewards { user: tx-sender, reward-id: reward-id } {
                      claimed-at: block-height,
                      claim-count: (+ current-claims u1)
                    })
                  )
                  
                  ;; Update reward claims used
                  (map-set points-rewards { reward-id: reward-id } {
                    name: (get reward name),
                    description: (get reward description),
                    points-cost: (get reward points-cost),
                    reward-type: (get reward reward-type),
                    active: (get reward active),
                    max-claims: (get reward max-claims),
                    claims-used: (+ (get reward claims-used) u1)
                  })
                  
                  ;; Emit event
                  (map-set reward-claimed { event-id: block-height } { user: tx-sender, reward-id: reward-id, cost: (get reward points-cost) })
                  
                  (ok {
                    reward-name: (get reward name),
                    reward-type: (get reward reward-type),
                    points-spent: (get reward points-cost)
                  })
                )
              error error
            )
          )
        )
      )
    )
  )
)

(define-public (apply-points-decay)
  (begin
    ;; Check if decay is enabled
    (asserts! (var-get points-decay-enabled) ERR_POINTS_NOT_AVAILABLE)
    
    ;; Only run decay if enough blocks have passed
    (asserts! (>= (- block-height (var-get last-decay-block)) u100) ERR_POINTS_NOT_AVAILABLE)
    
    ;; Apply decay to all users (simplified - would need proper iteration)
    (let ((decay-applied u0))
      ;; This would iterate through all users and apply decay
      ;; Simplified implementation
      
      ;; Update last decay block
      (var-set last-decay-block block-height)
      
      (ok decay-applied)
    )
  )
)

(define-public (create-reward (reward-id (string-ascii 32)) (name (string-ascii 64)) (description (string-ascii 256)) (points-cost uint) (reward-type (string-ascii 16)) (max-claims uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len reward-id) u0) ERR_INVALID_POINTS)
    (asserts! (> (len name) u0) ERR_INVALID_POINTS)
    (asserts! (> points-cost u0) ERR_INVALID_POINTS)
    (asserts! (> max-claims u0) ERR_INVALID_POINTS)
    
    ;; Check permissions
    (asserts! (is-authorized-issuer tx-sender) ERR_INSUFFICIENT_PERMISSIONS)
    
    ;; Create reward
    (map-set points-rewards { reward-id: reward-id } {
      name: name,
      description: description,
      points-cost: points-cost,
      reward-type: reward-type,
      active: true,
      max-claims: max-claims,
      claims-used: u0
    })
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (is-authorized-issuer (issuer principal))
  (begin
    ;; Simplified authorization check
    ;; Would use proper RBAC system
    (or 
      (is-eq issuer (contract-call? .conxian-protocol get-admin))
      (is-eq issuer (contract-call? .conxian-protocol get-owner))
    )
  )
)

;; Oracle trait implementation

(define-read-only (get-price (feed-id (string-ascii 32)))
  (begin
    ;; Return points as "price" for oracle compatibility
    (match (get-user-points (principal-from-string feed-id)))
      points (ok (get points balance))
      none (ok u0)
    )
  )


(define-read-only (get-confidence (feed-id (string-ascii 32)))
  ;; Return tier as confidence
  (ok (get-points-tier (principal-from-string feed-id)))
)

(define-read-only (get-timestamp (feed-id (string-ascii 32)))
  ;; Return last activity as timestamp
  (match (get-user-points (principal-from-string feed-id))
    points (ok (get points last-activity))
    none (ok u0)
  )
)

(define-read-only (is-feed-available (feed-id (string-ascii 32)))
  (is-some (get-user-points (principal-from-string feed-id)))
)

;; Admin functions

(define-public (set-decay-enabled (enabled bool))
  (begin
    ;; Only admin can set decay
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INSUFFICIENT_PERMISSIONS)
    
    (var-set points-decay-enabled enabled)
    (ok true)
  )
)

(define-public (emergency-reset-user-points (user principal))
  (begin
    ;; Only admin can reset user points
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INSUFFICIENT_PERMISSIONS)
    
    ;; Reset user points
    (map-set user-points { user: user } {
      balance: u0,
      earned: u0,
      burned: u0,
      last-activity: block-height,
      points-tier: u0,
      expiry-block: u0
    })
    
    (ok true)
  )
)

(define-public (deactivate-reward (reward-id (string-ascii 32)))
  (begin
    ;; Only admin can deactivate rewards
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INSUFFICIENT_PERMISSIONS)
    
    ;; Deactivate reward
    (let ((reward-info (get-reward-info reward-id)))
      (asserts! (is-some reward-info) ERR_POINTS_NOT_AVAILABLE)
      
      (let ((reward (unwrap-optional reward-info)))
        (map-set points-rewards { reward-id: reward-id } {
          name: (get reward name),
          description: (get reward description),
          points-cost: (get reward points-cost),
          reward-type: (get reward reward-type),
          active: false,
          max-claims: (get reward max-claims),
          claims-used: (get reward claims-used)
        })
        
        (ok true)
      )
    )
  )
)

;; Utility functions

(define-private (principal-from-string (str (string-ascii 32)))
  ;; Simplified principal conversion
  ;; Would need proper implementation
  tx-sender
)
