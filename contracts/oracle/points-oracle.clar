;; points-oracle.clar
;; Conxian Protocol: Points-based oracle for gamification and rewards

;; Dependencies
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_INVALID_POINTS u21001)
(define-constant ERR_INSUFFICIENT_PERMISSIONS u21002)
(define-constant ERR_POINTS_NOT_AVAILABLE u21003)
(define-constant ERR_INVALID_RECIPIENT u21004)
(define-constant ERR_POINTS_EXPIRED u21005)

;; Points system parameters
(define-constant POINTS_PRECISION u1000000) ;; 6 decimal places
(define-constant MAX_POINTS_PER_TRANSACTION u100000000) ;; 100 points max
(define-constant POINTS_EXPIRY_SECONDS u86400) ;; 1 day expiry
(define-constant MIN_POINTS_THRESHOLD u1000) ;; Minimum points for rewards
(define-constant POINTS_DECAY_RATE u100) ;; 0.01% decay per block

;; Data variables
(define-data-var total-points-issued uint u0)
(define-data-var total-points-burned uint u0)
(define-data-var points-decay-enabled bool true)
(define-data-var last-decay-block uint u0)

(define-data-var conxian-protocol-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Event definitions
(define-map points-earned { event-id: uint } { user: principal, amount: uint, source: (string-ascii 16) })
(define-map points-burned { event-id: uint } { user: principal, amount: uint, reason: (string-ascii 16) })
(define-map points-transferred { event-id: uint } { from: principal, to: principal, amount: uint })
(define-map reward-claimed { event-id: uint } { user: principal, reward-id: (string-ascii 32), cost: uint })

;; Storage maps
(define-map user-points { user: principal } { 
  balance: uint,
  earned: uint,
  burned: uint,
  last-activity: uint,
  points-tier: uint,
  expiry-time: uint
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

;; Read-only functions

(define-read-only (get-user-points (user principal))
  (ok (default-to {
    balance: u0,
    earned: u0,
    burned: u0,
    last-activity: u0,
    points-tier: u0,
    expiry-time: u0
  } (map-get? user-points { user: user })))
)

(define-read-only (get-points-balance (user principal))
  (ok (get balance (unwrap-panic (get-user-points user))))
)

(define-read-only (get-points-tier (user principal))
  (ok (get points-tier (unwrap-panic (get-user-points user))))
)

(define-read-only (get-points-earned (user principal))
  (ok (get earned (unwrap-panic (get-user-points user))))
)

(define-read-only (get-points-burned (user principal))
  (ok (get burned (unwrap-panic (get-user-points user))))
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

;; @desc Award points to a user for a specific action
(define-public (award-points (user principal) (amount uint) (source (string-ascii 16)))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) (err ERR_INVALID_POINTS))
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) (err ERR_INVALID_POINTS))
    
    ;; Check permissions
    (asserts! (is-authorized-issuer tx-sender) (err ERR_INSUFFICIENT_PERMISSIONS))
    
    ;; Get current user points
    (let ((current-points (unwrap-panic (get-user-points user))))
      (let ((current-balance (get balance current-points))
            (current-earned (get earned current-points))
            (current-tier (unwrap-panic (calculate-user-tier user))))
        
        ;; Update user points
        (map-set user-points { user: user } {
          balance: (+ current-balance amount),
          earned: (+ current-earned amount),
          burned: (get burned current-points),
          last-activity: burn-block-height,
          points-tier: current-tier,
          expiry-time: (+ burn-block-height POINTS_EXPIRY_SECONDS)
        })
        
        ;; Update totals
        (var-set total-points-issued (+ (var-get total-points-issued) amount))
        
        ;; Emit event
        (print { event: "points-earned", user: user, amount: amount, source: source })
        
        (ok {
          new-balance: (+ current-balance amount),
          total-earned: (+ current-earned amount),
          tier: current-tier
        })
      )
    )
  )
)

;; @desc Burn points from the user's balance
(define-public (burn-points (amount uint) (reason (string-ascii 16)))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) (err ERR_INVALID_POINTS))
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) (err ERR_INVALID_POINTS))
    
    ;; Get current user points
    (let ((current-points (unwrap-panic (get-user-points tx-sender))))
      (let ((current-balance (get balance current-points))
            (current-burned (get burned current-points)))
        
        ;; Check sufficient balance
        (asserts! (>= current-balance amount) (err ERR_POINTS_NOT_AVAILABLE))
        
        ;; Update user points
        (map-set user-points { user: tx-sender } {
          balance: (- current-balance amount),
          earned: (get earned current-points),
          burned: (+ current-burned amount),
          last-activity: burn-block-height,
          points-tier: (unwrap-panic (calculate-user-tier tx-sender)),
          expiry-time: (get expiry-time current-points)
        })
        
        ;; Update totals
        (var-set total-points-burned (+ (var-get total-points-burned) amount))
        
        ;; Emit event
        (print { event: "points-burned", user: tx-sender, amount: amount, reason: reason })
        
        (ok {
          new-balance: (- current-balance amount),
          total-burned: (+ current-burned amount)
        })
      )
    )
  )
)

;; @desc Transfer points to another user
(define-public (transfer-points (to principal) (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) (err ERR_INVALID_POINTS))
    (asserts! (<= amount MAX_POINTS_PER_TRANSACTION) (err ERR_INVALID_POINTS))
    (asserts! (not (is-eq tx-sender to)) (err ERR_INVALID_RECIPIENT))
    
    ;; Get current user points
    (let ((sender-points (unwrap-panic (get-user-points tx-sender))))
      (let ((sender-balance (get balance sender-points))
            (receiver-points (unwrap-panic (get-user-points to))))
        
        (let ((receiver-balance (get balance receiver-points)))
          
          ;; Check sufficient balance
          (asserts! (>= sender-balance amount) (err ERR_POINTS_NOT_AVAILABLE))
          
          ;; Update sender points
          (map-set user-points { user: tx-sender } {
            balance: (- sender-balance amount),
            earned: (get earned sender-points),
            burned: (get burned sender-points),
            last-activity: burn-block-height,
            points-tier: (unwrap-panic (calculate-user-tier tx-sender)),
            expiry-time: (get expiry-time sender-points)
          })
          
          ;; Update receiver points
          (map-set user-points { user: to } {
            balance: (+ receiver-balance amount),
            earned: (get earned receiver-points),
            burned: (get burned receiver-points),
            last-activity: burn-block-height,
            points-tier: (unwrap-panic (calculate-user-tier to)),
            expiry-time: (+ burn-block-height POINTS_EXPIRY_SECONDS)
          })
          
          ;; Emit event
          (print { event: "points-transferred", from: tx-sender, to: to, amount: amount })
          
          (ok {
            sender-balance: (- sender-balance amount),
            receiver-balance: (+ receiver-balance amount)
          })
        )
      )
    )
  )
)

;; @desc Spend points to claim a specific reward
(define-public (claim-reward (reward-id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len reward-id) u0) (err ERR_INVALID_POINTS))
    
    ;; Check if reward exists and is active
    (let ((reward-info (get-reward-info reward-id)))
      (asserts! (is-some reward-info) (err ERR_POINTS_NOT_AVAILABLE))
      
      (let ((reward (unwrap! reward-info (err ERR_POINTS_NOT_AVAILABLE))))
        (asserts! (get active reward) (err ERR_POINTS_NOT_AVAILABLE))
        
        ;; Check if user has sufficient points
        (let ((user-balance (unwrap! (get-points-balance tx-sender) (err ERR_POINTS_NOT_AVAILABLE))))
          (asserts! (>= user-balance (get points-cost reward)) (err ERR_POINTS_NOT_AVAILABLE))
          
          ;; Check claim limits
          (let ((user-claim (get-user-reward-claim tx-sender reward-id)))
            (if (is-some user-claim)
                (asserts!
                  (< (get claim-count (unwrap! user-claim (err ERR_POINTS_NOT_AVAILABLE)))
                    (get max-claims reward)
                  )
                  (err ERR_POINTS_NOT_AVAILABLE)
                )
                true ;; First time claiming
            )
            
            ;; Burn points for reward
            (match (burn-points (get points-cost reward) "reward-claim")
              success
                (begin
                  ;; Update user reward claim
                  (let ((current-claims (if (is-some user-claim) (get claim-count (unwrap! user-claim (err ERR_POINTS_NOT_AVAILABLE))) u0)))
                    (map-set user-rewards { user: tx-sender, reward-id: reward-id } {
                      claimed-at: burn-block-height,
                      claim-count: (+ current-claims u1)
                    })
                  )
                  
                  ;; Update reward claims used
                  (map-set points-rewards { reward-id: reward-id } {
                    name: (get name reward),
                    description: (get description reward),
                    points-cost: (get points-cost reward),
                    reward-type: (get reward-type reward),
                    active: (get active reward),
                    max-claims: (get max-claims reward),
                    claims-used: (+ (get claims-used reward) u1)
                  })
                  
                  ;; Emit event
                  (print { event: "reward-claimed", user: tx-sender, reward-id: reward-id, cost: (get points-cost reward) })
                  
                  (ok {
                    reward-name: (get name reward),
                    reward-type: (get reward-type reward),
                    points-spent: (get points-cost reward)
                  })
                )
              error (err error)
            )
          )
        )
      )
    )
  )
)

;; @desc Apply points decay logic globally (Heartbeat-compatible)
(define-public (apply-points-decay)
  (begin
    ;; Check if decay is enabled
    (asserts! (var-get points-decay-enabled) (err ERR_POINTS_NOT_AVAILABLE))
    
    ;; Only run decay if enough blocks have passed
    (asserts! (>= (- burn-block-height (var-get last-decay-block)) u100) (err ERR_POINTS_NOT_AVAILABLE))
    
    ;; Update last decay block
    (var-set last-decay-block burn-block-height)
    (ok u0)
  )
)

;; @desc Create a new reward that users can claim
(define-public (create-reward (reward-id (string-ascii 32)) (name (string-ascii 64)) (description (string-ascii 256)) (points-cost uint) (reward-type (string-ascii 16)) (max-claims uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len reward-id) u0) (err ERR_INVALID_POINTS))
    (asserts! (> (len name) u0) (err ERR_INVALID_POINTS))
    (asserts! (> points-cost u0) (err ERR_INVALID_POINTS))
    (asserts! (> max-claims u0) (err ERR_INVALID_POINTS))
    
    ;; Check permissions
    (asserts! (is-authorized-issuer tx-sender) (err ERR_INSUFFICIENT_PERMISSIONS))
    
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

(define-private (is-authorized-issuer (issuer principal))
  (or
    (is-eq issuer (contract-call? .conxian-protocol get-admin))
    (is-eq issuer (contract-call? .conxian-protocol get-protocol-admin))
  )
)

;; Oracle trait implementation

(define-read-only (get-price (asset principal))
  ;; Return points balance as "price"
  (ok (get balance (unwrap-panic (get-user-points asset))))
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-confidence (asset principal))
  ;; Return tier as confidence
  (ok (unwrap-panic (get-points-tier asset)))
)

(define-read-only (get-timestamp (asset principal))
  ;; Return last activity as timestamp
  (ok (get last-activity (unwrap-panic (get-user-points asset))))
)

(define-read-only (is-feed-available (asset principal))
  (is-some (map-get? user-points { user: asset }))
)

;; Admin functions

;; @desc Enable or disable points decay
(define-public (set-decay-enabled (enabled bool))
  (begin
    ;; Only admin can set decay
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) (err ERR_INSUFFICIENT_PERMISSIONS))
    (var-set points-decay-enabled enabled)
    (ok true)
  )
)

;; @desc Emergency reset of a user's points balance
(define-public (emergency-reset-user-points (user principal))
  (begin
    ;; Only admin can reset user points
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) (err ERR_INSUFFICIENT_PERMISSIONS))
    
    ;; Reset user points
    (map-set user-points { user: user } {
      balance: u0,
      earned: u0,
      burned: u0,
      last-activity: burn-block-height,
      points-tier: u0,
      expiry-time: u0
    })
    (ok true)
  )
)

;; @desc Deactivate a reward to prevent further claims
(define-public (deactivate-reward (reward-id (string-ascii 32)))
  (begin
    ;; Only admin can deactivate rewards
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) (err ERR_INSUFFICIENT_PERMISSIONS))
    
    ;; Deactivate reward
    (let ((reward-info (get-reward-info reward-id)))
      (asserts! (is-some reward-info) (err ERR_POINTS_NOT_AVAILABLE))
      
      (let ((reward (unwrap! reward-info (err ERR_POINTS_NOT_AVAILABLE))))
        (map-set points-rewards { reward-id: reward-id } {
          name: (get name reward),
          description: (get description reward),
          points-cost: (get points-cost reward),
          reward-type: (get reward-type reward),
          active: false,
          max-claims: (get max-claims reward),
          claims-used: (get claims-used reward)
        })
        (ok true)
      )
    )
  )
)
