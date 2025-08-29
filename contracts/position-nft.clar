;; Position NFT Contract
;; SIP-009 compliant NFT contract for concentrated liquidity positions

;; Import SIP-009 trait
(impl-trait .sip-009-nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY u4000)
(define-constant ERR_NOT_TOKEN_OWNER u4001)
(define-constant ERR_NOT_AUTHORIZED u4002)
(define-constant ERR_TOKEN_NOT_FOUND u4003)
(define-constant ERR_ALREADY_EXISTS u4004)
(define-constant ERR_INVALID_METADATA u4005)

;; NFT definition
(define-non-fungible-token position-nft uint)

;; Data variables
(define-data-var last-token-id uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)

;; Position metadata structure
(define-map token-metadata
  {token-id: uint}
  {pool: principal,
   tick-lower: int,
   tick-upper: int,
   liquidity: uint,
   fee-tier: uint,
   token-0: principal,
   token-1: principal,
   created-at: uint,
   last-updated: uint})

;; Position value tracking for PnL calculations
(define-map position-values
  {token-id: uint}
  {initial-value-0: uint,
   initial-value-1: uint,
   current-value-0: uint,
   current-value-1: uint,
   fees-earned-0: uint,
   fees-earned-1: uint,
   last-fee-collection: uint})

;; Position performance metrics
(define-map position-metrics
  {token-id: uint}
  {total-fees-collected-0: uint,
   total-fees-collected-1: uint,
   impermanent-loss: int,
   roi-percentage: int,
   days-active: uint,
   fee-apr: uint})

;; Operator approvals for position management
(define-map operator-approvals
  {owner: principal, operator: principal}
  {approved: bool})

;; Token approvals
(define-map token-approvals
  {token-id: uint}
  {approved: principal})

;; SIP-009 Implementation

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat 
    "https://Conxian.finance/api/position/"
    (uint-to-ascii token-id)))))

;; Get token owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? position-nft token-id)))

;; Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender sender)
                  (is-eq tx-sender (unwrap! (get approved (map-get? token-approvals {token-id: token-id})) (err ERR_NOT_AUTHORIZED)))
                  (default-to false (get approved (map-get? operator-approvals {owner: sender, operator: tx-sender}))))
              (err ERR_NOT_AUTHORIZED))
    (asserts! (is-eq sender (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND)))
              (err ERR_NOT_TOKEN_OWNER))
    
    ;; Clear token approval
    (map-delete token-approvals {token-id: token-id})
    
    ;; Transfer NFT
    (nft-transfer? position-nft token-id sender recipient)))

;; Get contract URI
(define-read-only (get-contract-uri)
  (ok (var-get contract-uri)))

;; Set contract URI (owner only)
(define-public (set-contract-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_OWNER_ONLY))
    (var-set contract-uri (some uri))
    (ok true)))

;; Position Management Functions

;; Mint new position NFT
(define-public (mint-position
  (recipient principal)
  (pool principal)
  (tick-lower int)
  (tick-upper int)
  (liquidity uint)
  (fee-tier uint)
  (token-0 principal)
  (token-1 principal)
  (initial-amount-0 uint)
  (initial-amount-1 uint))
  (let ((token-id (+ (var-get last-token-id) u1))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Mint NFT
    (try! (nft-mint? position-nft token-id recipient))
    
    ;; Store position metadata
    (map-set token-metadata
      {token-id: token-id}
      {pool: pool,
       tick-lower: tick-lower,
       tick-upper: tick-upper,
       liquidity: liquidity,
       fee-tier: fee-tier,
       token-0: token-0,
       token-1: token-1,
       created-at: current-time,
       last-updated: current-time})
    
    ;; Initialize position values
    (map-set position-values
      {token-id: token-id}
      {initial-value-0: initial-amount-0,
       initial-value-1: initial-amount-1,
       current-value-0: initial-amount-0,
       current-value-1: initial-amount-1,
       fees-earned-0: u0,
       fees-earned-1: u0,
       last-fee-collection: current-time})
    
    ;; Initialize metrics
    (map-set position-metrics
      {token-id: token-id}
      {total-fees-collected-0: u0,
       total-fees-collected-1: u0,
       impermanent-loss: 0,
       roi-percentage: 0,
       days-active: u0,
       fee-apr: u0})
    
    ;; Update last token ID
    (var-set last-token-id token-id)
    
    (ok token-id)))

;; Burn position NFT
(define-public (burn-position (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND))))
    (asserts! (or (is-eq tx-sender owner)
                  (is-eq tx-sender (unwrap! (get approved (map-get? token-approvals {token-id: token-id})) (err ERR_NOT_AUTHORIZED)))
                  (default-to false (get approved (map-get? operator-approvals {owner: owner, operator: tx-sender}))))
              (err ERR_NOT_AUTHORIZED))
    
    ;; Burn NFT
    (try! (nft-burn? position-nft token-id owner))
    
    ;; Clean up metadata
    (map-delete token-metadata {token-id: token-id})
    (map-delete position-values {token-id: token-id})
    (map-delete position-metrics {token-id: token-id})
    (map-delete token-approvals {token-id: token-id})
    
    (ok true)))

;; Update position liquidity
(define-public (update-position-liquidity (token-id uint) (new-liquidity uint))
  (let ((owner (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND)))
        (metadata (unwrap! (map-get? token-metadata {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND))))
    
    (asserts! (or (is-eq tx-sender owner)
                  (is-eq tx-sender (unwrap! (get approved (map-get? token-approvals {token-id: token-id})) (err ERR_NOT_AUTHORIZED)))
                  (default-to false (get approved (map-get? operator-approvals {owner: owner, operator: tx-sender}))))
              (err ERR_NOT_AUTHORIZED))
    
    ;; Update metadata
    (map-set token-metadata
      {token-id: token-id}
      (merge metadata 
        {liquidity: new-liquidity,
         last-updated: (unwrap-panic (get-block-info? time (- block-height u1)))}))
    
    (ok true)))

;; Update position values for PnL tracking
(define-public (update-position-values
  (token-id uint)
  (current-amount-0 uint)
  (current-amount-1 uint)
  (fees-earned-0 uint)
  (fees-earned-1 uint))
  (let ((owner (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND)))
        (values (unwrap! (map-get? position-values {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND))))
    
    (asserts! (or (is-eq tx-sender owner)
                  (is-eq tx-sender (unwrap! (get approved (map-get? token-approvals {token-id: token-id})) (err ERR_NOT_AUTHORIZED)))
                  (default-to false (get approved (map-get? operator-approvals {owner: owner, operator: tx-sender}))))
              (err ERR_NOT_AUTHORIZED))
    
    ;; Update position values
    (map-set position-values
      {token-id: token-id}
      (merge values
        {current-value-0: current-amount-0,
         current-value-1: current-amount-1,
         fees-earned-0: fees-earned-0,
         fees-earned-1: fees-earned-1}))
    
    (ok true)))

;; Collect fees and update metrics
(define-public (collect-position-fees
  (token-id uint)
  (fees-collected-0 uint)
  (fees-collected-1 uint))
  (let ((owner (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND)))
        (values (unwrap! (map-get? position-values {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND)))
        (metrics (unwrap! (map-get? position-metrics {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND)))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    (asserts! (or (is-eq tx-sender owner)
                  (is-eq tx-sender (unwrap! (get approved (map-get? token-approvals {token-id: token-id})) (err ERR_NOT_AUTHORIZED)))
                  (default-to false (get approved (map-get? operator-approvals {owner: owner, operator: tx-sender}))))
              (err ERR_NOT_AUTHORIZED))
    
    ;; Update position values
    (map-set position-values
      {token-id: token-id}
      (merge values
        {fees-earned-0: u0,
         fees-earned-1: u0,
         last-fee-collection: current-time}))
    
    ;; Update metrics
    (map-set position-metrics
      {token-id: token-id}
      (merge metrics
        {total-fees-collected-0: (+ (get total-fees-collected-0 metrics) fees-collected-0),
         total-fees-collected-1: (+ (get total-fees-collected-1 metrics) fees-collected-1)}))
    
    (ok true)))

;; Calculate and update position metrics
(define-public (update-position-metrics (token-id uint))
  (let ((metadata (unwrap! (map-get? token-metadata {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND)))
        (values (unwrap! (map-get? position-values {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND)))
        (metrics (unwrap! (map-get? position-metrics {token-id: token-id}) (err ERR_TOKEN_NOT_FOUND)))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    
    ;; Calculate days active
    (let ((days-active (/ (- current-time (get created-at metadata)) u86400))) ;; seconds per day
      
      ;; Calculate impermanent loss
      (let ((il (calculate-impermanent-loss 
                 (get initial-value-0 values)
                 (get initial-value-1 values)
                 (get current-value-0 values)
                 (get current-value-1 values))))
        
        ;; Calculate ROI percentage
        (let ((roi (calculate-roi
                    (+ (get initial-value-0 values) (get initial-value-1 values))
                    (+ (get current-value-0 values) (get current-value-1 values))
                    (+ (get total-fees-collected-0 metrics) (get total-fees-collected-1 metrics)))))
          
          ;; Calculate fee APR
          (let ((fee-apr (if (> days-active u0)
                          (/ (* (+ (get total-fees-collected-0 metrics) (get total-fees-collected-1 metrics)) u36500)
                             (* (+ (get initial-value-0 values) (get initial-value-1 values)) days-active))
                          u0)))
            
            ;; Update metrics
            (map-set position-metrics
              {token-id: token-id}
              (merge metrics
                {impermanent-loss: il,
                 roi-percentage: roi,
                 days-active: days-active,
                 fee-apr: fee-apr}))
            
            (ok true)))))))

;; Calculate impermanent loss
(define-private (calculate-impermanent-loss 
  (initial-0 uint) 
  (initial-1 uint) 
  (current-0 uint) 
  (current-1 uint))
  (let ((initial-total (+ initial-0 initial-1))
        (current-total (+ current-0 current-1)))
    (if (> initial-total u0)
      (to-int (- (/ (* current-total u10000) initial-total) u10000)) ;; Basis points
      0)))

;; Calculate ROI percentage
(define-private (calculate-roi (initial-value uint) (current-value uint) (fees-collected uint))
  (let ((total-current (+ current-value fees-collected)))
    (if (> initial-value u0)
      (to-int (- (/ (* total-current u10000) initial-value) u10000)) ;; Basis points
      0)))

;; Approval Functions

;; Approve token transfer
(define-public (approve (token-id uint) (approved principal))
  (let ((owner (unwrap! (nft-get-owner? position-nft token-id) (err ERR_TOKEN_NOT_FOUND))))
    (asserts! (is-eq tx-sender owner) (err ERR_NOT_TOKEN_OWNER))
    (map-set token-approvals {token-id: token-id} {approved: approved})
    (ok true)))

;; Set approval for all tokens
(define-public (set-approval-for-all (operator principal) (approved bool))
  (map-set operator-approvals 
    {owner: tx-sender, operator: operator} 
    {approved: approved})
  (ok true))

;; Check if approved
(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (get approved (map-get? operator-approvals {owner: owner, operator: operator}))))

;; Get approved for token
(define-read-only (get-approved (token-id uint))
  (ok (get approved (map-get? token-approvals {token-id: token-id}))))

;; Position Query Functions

;; Get position metadata
(define-read-only (get-position-metadata (token-id uint))
  (map-get? token-metadata {token-id: token-id}))

;; Get position values
(define-read-only (get-position-values (token-id uint))
  (map-get? position-values {token-id: token-id}))

;; Get position metrics
(define-read-only (get-position-metrics (token-id uint))
  (map-get? position-metrics {token-id: token-id}))

;; Get complete position info
(define-read-only (get-position-info (token-id uint))
  (let ((metadata (map-get? token-metadata {token-id: token-id}))
        (values (map-get? position-values {token-id: token-id}))
        (metrics (map-get? position-metrics {token-id: token-id})))
    {metadata: metadata,
     values: values,
     metrics: metrics}))

;; Get positions owned by user
(define-read-only (get-user-positions (user principal))
  (filter is-owned-by-user (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))

(define-private (is-owned-by-user (token-id uint))
  (is-eq (nft-get-owner? position-nft token-id) (some tx-sender)))

;; Position enumeration
(define-read-only (get-positions-in-range (start uint) (end uint))
  (map get-position-summary (generate-range start end)))

(define-private (generate-range (start uint) (end uint))
  ;; Simplified range generation - in production would be more sophisticated
  (list start (+ start u1) (+ start u2) (+ start u3) (+ start u4)))

(define-private (get-position-summary (token-id uint))
  {token-id: token-id,
   owner: (nft-get-owner? position-nft token-id),
   metadata: (map-get? token-metadata {token-id: token-id})})

;; Utility functions
(define-private (uint-to-ascii (value uint))
  ;; Simplified conversion - in production would handle all digits
  (if (< value u10)
    (if (is-eq value u0) "0"
      (if (is-eq value u1) "1"
        (if (is-eq value u2) "2"
          (if (is-eq value u3) "3"
            (if (is-eq value u4) "4"
              (if (is-eq value u5) "5"
                (if (is-eq value u6) "6"
                  (if (is-eq value u7) "7"
                    (if (is-eq value u8) "8" "9")))))))))
    "10+")) ;; Simplified for large numbers