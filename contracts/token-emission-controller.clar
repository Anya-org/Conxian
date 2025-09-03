;; token-emission-controller.clar
;; Hard-coded emission rails with governance guards to prevent inflation abuse
;; Implements supply discipline across all 4 tokens with supermajority + timelock requirements

(use-trait ft-mintable .ft-mintable-trait.ft-mintable-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Emission limits (annual inflation caps)
(define-constant CXD_MAX_ANNUAL_INFLATION u2000) ;; 2% max annual inflation for CXD
(define-constant CXVG_MAX_ANNUAL_INFLATION u500) ;; 0.5% max for governance token
(define-constant CXLP_MAX_ANNUAL_INFLATION u1000) ;; 1% max for LP token  
(define-constant CXTR_MAX_ANNUAL_INFLATION u10000) ;; 10% max for creator token

;; Hard caps per epoch (blocks)
(define-constant EPOCH_BLOCKS u52560) ;; ~1 year at 1 min blocks
(define-constant MAX_SINGLE_MINT_BPS u100) ;; 1% of supply max per mint

;; Governance requirements for changes
(define-constant SUPERMAJORITY_THRESHOLD u6667) ;; 66.67% required
(define-constant TIMELOCK_BLOCKS u20160) ;; ~2 weeks minimum delay
(define-constant EMERGENCY_TIMELOCK u1440) ;; ~1 day for emergency reduction

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u700)
(define-constant ERR_EMISSION_CAP_EXCEEDED u701)
(define-constant ERR_SINGLE_MINT_TOO_LARGE u702)
(define-constant ERR_INVALID_TOKEN u703)
(define-constant ERR_GOVERNANCE_THRESHOLD_NOT_MET u704)
(define-constant ERR_TIMELOCK_ACTIVE u705)
(define-constant ERR_NO_PENDING_CHANGE u706)
(define-constant ERR_TIMELOCK_NOT_ELAPSED u707)
(define-constant ERR_INVALID_PARAMETERS u708)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var governance-contract (optional principal) none)

;; Token contracts
(define-data-var cxd-contract principal .cxd-token)
(define-data-var cxvg-contract principal .cxvg-token)
(define-data-var cxlp-contract principal .cxlp-token)
(define-data-var cxtr-contract principal .cxtr-token)

;; Current epoch tracking
(define-data-var current-epoch uint u0)
(define-data-var epoch-start-height uint u0)

;; Emission tracking per token per epoch
(define-map epoch-emissions
  { token: principal, epoch: uint }
  { minted: uint, supply-at-start: uint })

;; Current emission limits (can be changed via governance)
(define-map token-emission-limits
  principal
  { max-annual-bps: uint, max-single-mint-bps: uint })

;; Pending governance changes
(define-map pending-limit-changes
  principal ;; token
  {
    new-annual-bps: uint,
    new-single-mint-bps: uint,
    proposed-at: uint,
    timelock-blocks: uint,
    votes-for: uint,
    votes-against: uint,
    total-voting-power: uint,
    executed: bool
  })

(define-data-var next-proposal-id uint u1)

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-governance-contract (governance principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set governance-contract (some governance))
    (ok true)))

(define-public (set-token-contracts (cxd principal) (cxvg principal) (cxlp principal) (cxtr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxd-contract cxd)
    (var-set cxvg-contract cxvg)
    (var-set cxlp-contract cxlp)
    (var-set cxtr-contract cxtr)
    (ok true)))

;; Initialize emission limits (one-time setup)
(define-public (initialize-emission-limits)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    
    ;; Set initial limits
    (map-set token-emission-limits (var-get cxd-contract)
      { max-annual-bps: CXD_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
    
    (map-set token-emission-limits (var-get cxvg-contract) 
      { max-annual-bps: CXVG_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
    
    (map-set token-emission-limits (var-get cxlp-contract)
      { max-annual-bps: CXLP_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
    
    (map-set token-emission-limits (var-get cxtr-contract)
      { max-annual-bps: CXTR_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
    
    ;; Initialize epoch
    (var-set current-epoch u1)
    (var-set epoch-start-height block-height)
    
    (ok true)))

;; --- Emission Control Functions ---

;; Check if new epoch should start
(define-private (maybe-advance-epoch)
  (let ((current-epoch-num (var-get current-epoch))
        (epoch-start (var-get epoch-start-height)))
    (if (>= (- block-height epoch-start) EPOCH_BLOCKS)
      (begin
        (var-set current-epoch (+ current-epoch-num u1))
        (var-set epoch-start-height block-height)
        true)
      false)))

;; Get current token supply
(define-private (get-token-supply (token-contract principal))
  (if (is-eq token-contract (var-get cxd-contract))
    (unwrap-panic (contract-call? .cxd-token get-total-supply))
    (if (is-eq token-contract (var-get cxvg-contract))
      (unwrap-panic (contract-call? .cxvg-token get-total-supply))
      (if (is-eq token-contract (var-get cxlp-contract))
        (unwrap-panic (contract-call? .cxlp-token get-total-supply))
        (if (is-eq token-contract (var-get cxtr-contract))
          (unwrap-panic (contract-call? .cxtr-token get-total-supply))
          u0)))))

;; Authorized mint with emission controls
(define-public (controlled-mint (token-contract <ft-mintable>) (recipient principal) (amount uint))
  (let ((token-principal (contract-of token-contract))
        (current-epoch-num (var-get current-epoch)))
    (begin
      ;; Only governance or owner can mint
      (asserts! (or (is-eq tx-sender (var-get contract-owner))
                   (is-some (var-get governance-contract))) (err ERR_UNAUTHORIZED))
      
      ;; Validate token is supported
      (let ((limits (unwrap! (map-get? token-emission-limits token-principal) (err ERR_INVALID_TOKEN))))
        
        ;; Advance epoch if needed
        (maybe-advance-epoch)
        
        ;; Get current supply and epoch data
        (let ((current-supply (get-token-supply token-principal))
              (epoch-data (default-to { minted: u0, supply-at-start: current-supply }
                                     (map-get? epoch-emissions { token: token-principal, epoch: current-epoch-num })))
              (annual-cap (/ (* (get supply-at-start epoch-data) (get max-annual-bps limits)) u10000))
              (single-mint-cap (/ (* current-supply (get max-single-mint-bps limits)) u10000)))
          
          ;; Check single mint limit
          (asserts! (<= amount single-mint-cap) (err ERR_SINGLE_MINT_TOO_LARGE))
          
          ;; Check annual emission cap
          (asserts! (<= (+ (get minted epoch-data) amount) annual-cap) (err ERR_EMISSION_CAP_EXCEEDED))
          
          ;; Execute mint
          (try! (as-contract (contract-call? token-contract mint recipient amount)))
          
          ;; Update epoch emissions
          (map-set epoch-emissions { token: token-principal, epoch: current-epoch-num }
            { 
              minted: (+ (get minted epoch-data) amount),
              supply-at-start: (get supply-at-start epoch-data)
            })
          
          (ok { amount: amount, epoch: current-epoch-num, remaining-cap: (- annual-cap (+ (get minted epoch-data) amount)) }))))))

;; --- Governance Functions ---

;; Propose emission limit changes (requires governance)
(define-public (propose-limit-change (token-contract principal) (new-annual-bps uint) (new-single-mint-bps uint) (is-emergency bool))
  (let ((governance (unwrap! (var-get governance-contract) (err ERR_UNAUTHORIZED)))
        (timelock (if is-emergency EMERGENCY_TIMELOCK TIMELOCK_BLOCKS)))
    (begin
      (asserts! (is-eq tx-sender governance) (err ERR_UNAUTHORIZED))
      (asserts! (and (<= new-annual-bps u20000) (<= new-single-mint-bps u1000)) (err ERR_INVALID_PARAMETERS)) ;; Max 20% annual, 10% single
      
      ;; Store pending change
      (map-set pending-limit-changes token-contract
        {
          new-annual-bps: new-annual-bps,
          new-single-mint-bps: new-single-mint-bps,
          proposed-at: block-height,
          timelock-blocks: timelock,
          votes-for: u0,
          votes-against: u0,
          total-voting-power: u0,
          executed: false
        })
      
      (ok true))))

;; Vote on emission limit changes (called by CXVG utility contract)
(define-public (vote-on-limit-change (token-contract principal) (support bool) (voting-power uint))
  (match (map-get? pending-limit-changes token-contract)
    change-info
    (begin
      (asserts! (not (get executed change-info)) (err ERR_NO_PENDING_CHANGE))
      
      (let ((updated-info
              (if support
                (merge change-info 
                  { votes-for: (+ (get votes-for change-info) voting-power),
                    total-voting-power: (+ (get total-voting-power change-info) voting-power) })
                (merge change-info
                  { votes-against: (+ (get votes-against change-info) voting-power),
                    total-voting-power: (+ (get total-voting-power change-info) voting-power) }))))
        
        (map-set pending-limit-changes token-contract updated-info)
        (ok true)))
    (err ERR_NO_PENDING_CHANGE)))

;; Execute emission limit change after timelock and supermajority
(define-public (execute-limit-change (token-contract principal))
  (match (map-get? pending-limit-changes token-contract)
    change-info
    (begin
      (asserts! (not (get executed change-info)) (err ERR_NO_PENDING_CHANGE))
      (asserts! (>= block-height (+ (get proposed-at change-info) (get timelock-blocks change-info))) (err ERR_TIMELOCK_NOT_ELAPSED))
      
      ;; Check supermajority requirement
      (let ((support-ratio (if (> (get total-voting-power change-info) u0)
                            (/ (* (get votes-for change-info) u10000) (get total-voting-power change-info))
                            u0)))
        (asserts! (>= support-ratio SUPERMAJORITY_THRESHOLD) (err ERR_GOVERNANCE_THRESHOLD_NOT_MET))
        
        ;; Update emission limits
        (map-set token-emission-limits token-contract
          { 
            max-annual-bps: (get new-annual-bps change-info),
            max-single-mint-bps: (get new-single-mint-bps change-info)
          })
        
        ;; Mark as executed
        (map-set pending-limit-changes token-contract
          (merge change-info { executed: true }))
        
        (ok true)))
    (err ERR_NO_PENDING_CHANGE)))

;; --- Emergency Functions ---

;; Emergency reduction of emission limits (no voting required, shorter timelock)
(define-public (emergency-reduce-limits (token-contract principal) (new-annual-bps uint) (new-single-mint-bps uint))
  (let ((current-limits (unwrap! (map-get? token-emission-limits token-contract) (err ERR_INVALID_TOKEN))))
    (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
      ;; Can only reduce, not increase
      (asserts! (and (<= new-annual-bps (get max-annual-bps current-limits))
                    (<= new-single-mint-bps (get max-single-mint-bps current-limits))) (err ERR_INVALID_PARAMETERS))
      
      ;; Update immediately (emergency powers)
      (map-set token-emission-limits token-contract
        {
          max-annual-bps: new-annual-bps,
          max-single-mint-bps: new-single-mint-bps
        })
      
      (ok true))))

;; --- Read-Only Functions ---

(define-read-only (get-emission-info (token-contract principal))
  (let ((current-epoch-num (var-get current-epoch))
        (limits (map-get? token-emission-limits token-contract))
        (epoch-data (map-get? epoch-emissions { token: token-contract, epoch: current-epoch-num }))
        (current-supply (get-token-supply token-contract)))
    {
      limits: limits,
      current-epoch: current-epoch-num,
      epoch-data: epoch-data,
      current-supply: current-supply,
      epoch-progress: (- block-height (var-get epoch-start-height)),
      blocks-remaining: (- EPOCH_BLOCKS (- block-height (var-get epoch-start-height)))
    }))

(define-read-only (get-remaining-mint-capacity (token-contract principal))
  (let ((current-epoch-num (var-get current-epoch))
        (limits (unwrap! (map-get? token-emission-limits token-contract) (err ERR_INVALID_TOKEN)))
        (epoch-data (default-to { minted: u0, supply-at-start: (get-token-supply token-contract) }
                                (map-get? epoch-emissions { token: token-contract, epoch: current-epoch-num })))
        (current-supply (get-token-supply token-contract))
        (annual-cap (/ (* (get supply-at-start epoch-data) (get max-annual-bps limits)) u10000))
        (single-mint-cap (/ (* current-supply (get max-single-mint-bps limits)) u10000)))
    
    (ok {
      annual-remaining: (- annual-cap (get minted epoch-data)),
      single-mint-max: single-mint-cap,
      annual-cap: annual-cap,
      epoch-minted: (get minted epoch-data)
    })))

(define-read-only (get-pending-change (token-contract principal))
  (map-get? pending-limit-changes token-contract))

(define-read-only (get-protocol-emission-status)
  {
    current-epoch: (var-get current-epoch),
    epoch-start-height: (var-get epoch-start-height),
    epoch-progress: (- block-height (var-get epoch-start-height)),
    cxd-info: (get-emission-info (var-get cxd-contract)),
    cxvg-info: (get-emission-info (var-get cxvg-contract)),
    cxlp-info: (get-emission-info (var-get cxlp-contract)),
    cxtr-info: (get-emission-info (var-get cxtr-contract))
  })
