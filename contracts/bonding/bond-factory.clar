;; bond-factory.clar
;; Conxian Enterprise Standard: Bond Factory
;; Creates and manages bond issuances with configurable terms

;; Trait imports
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u9400))
(define-constant ERR_INVALID_AMOUNT (err u9401))
(define-constant ERR_INVALID_TERMS (err u9402))
(define-constant ERR_BOND_NOT_FOUND (err u9403))

;; Bond types
(define-constant BOND_TYPE_FLASH u1)        ;; ~1 hour
(define-constant BOND_TYPE_SHORT_TERM u2)    ;; 30-180 days  
(define-constant BOND_TYPE_MEDIUM_TERM u3)   ;; 1-5 years
(define-constant BOND_TYPE_LONG_TERM u4)     ;; 10-30 years

;; Data Vars
(define-data-var factory-admin principal tx-sender)
(define-data-var total-bonds-issued uint u0)
(define-data-var active-bonds-count uint u0)

;; Bond configurations
(define-map bond-templates
  uint
  {
    maturity-blocks: uint,
    min-amount: uint,
    max-amount: uint,
    interest-rate: uint, ;; basis points
    auto-renew: bool
  }
)

;; Individual bonds
(define-map bonds
  uint
  {
    issuer: principal,
    bond-type: uint,
    principal-amount: uint,
    interest-rate: uint,
    maturity-block: uint,
    issued-block: uint,
    is-active: bool,
    auto-renew: bool
  }
)

;; Bond holders
(define-map bond-holdings
  { bond-id: uint, holder: principal }
  { amount: uint, purchase-block: uint }
)

;; Initialize bond templates
(define-private (initialize-templates)
  (begin
    ;; Flash bonds (~1 hour)
    (map-set bond-templates BOND_TYPE_FLASH {
      maturity-blocks: u720,        ;; ~1 hour at 5s blocks
      min-amount: u1000000,         ;; 1 STX minimum
      max-amount: u100000000,       ;; 100 STX maximum
      interest-rate: u50,            ;; 0.5% annual
      auto-renew: false
    })
    
    ;; Short-term bonds (30-180 days)
    (map-set bond-templates BOND_TYPE_SHORT_TERM {
      maturity-blocks: u3110400,    ;; 180 days
      min-amount: u10000000,        ;; 10 STX minimum
      max-amount: u1000000000,     ;; 1000 STX maximum
      interest-rate: u200,           ;; 2% annual
      auto-renew: true
    })
    
    ;; Medium-term bonds (1-5 years)
    (map-set bond-templates BOND_TYPE_MEDIUM_TERM {
      maturity-blocks: u15768000,   ;; 913 days (~2.5 years)
      min-amount: u50000000,        ;; 50 STX minimum
      max-amount: u5000000000,     ;; 5000 STX maximum
      interest-rate: u400,           ;; 4% annual
      auto-renew: true
    })
    
    ;; Long-term bonds (10-30 years)
    (map-set bond-templates BOND_TYPE_LONG_TERM {
      maturity-blocks: u63072000,   ;; 3650 days (~10 years)
      min-amount: u100000000,       ;; 100 STX minimum
      max-amount: u10000000000,    ;; 10000 STX maximum
      interest-rate: u600,           ;; 6% annual
      auto-renew: false
    })
  )
)

;; Public functions
(define-public (create-bond
  (bond-type uint)
  (principal-amount uint)
  (interest-rate uint)
  (auto-renew bool)
)
  (begin
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    ;; Validate bond type
    (match (map-get? bond-templates bond-type)
      template
      (begin
        (asserts! 
          (and 
            (>= principal-amount (get min-amount template))
            (<= principal-amount (get max-amount template))
          )
          ERR_INVALID_AMOUNT
        )
        
        ;; Create bond
        (let 
          ((bond-id (+ (var-get total-bonds-issued) u1))
           (maturity-block (+ block-height (get maturity-blocks template))))
          
          (map-set bonds bond-id {
            issuer: tx-sender,
            bond-type: bond-type,
            principal-amount: principal-amount,
            interest-rate: (if (> interest-rate u0) interest-rate (get interest-rate template)),
            maturity-block: maturity-block,
            issued-block: block-height,
            is-active: true,
            auto-renew: auto-renew
          })
          
          (var-set total-bonds-issued bond-id)
          (var-set active-bonds-count (+ (var-get active-bonds-count) u1))
          
          (ok bond-id)
        )
      )
      (err ERR_INVALID_TERMS)
    )
  )
)

(define-public (purchase-bond (bond-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (match (map-get? bonds bond-id)
      bond
      (begin
        (asserts! (get is-active bond) ERR_BOND_NOT_FOUND)
        (asserts! (< block-height (get maturity-block bond)) ERR_BOND_NOT_FOUND)
        
        ;; Record purchase
        (map-set bond-holdings { bond-id: bond-id, holder: tx-sender } {
          amount: amount,
          purchase-block: block-height
        })
        
        (ok true)
      )
      (err ERR_BOND_NOT_FOUND)
    )
  )
)

(define-public (redeem-bond (bond-id uint))
  (begin
    (match (map-get? bonds bond-id)
      bond
      (begin
        (asserts! (>= block-height (get maturity-block bond)) ERR_BOND_NOT_FOUND)
        
        (match (map-get? bond-holdings { bond-id: bond-id, holder: tx-sender })
          holding
          (begin
            ;; Calculate interest
            (let 
              ((principal (get amount holding))
               (interest-rate (get interest-rate bond))
               (held-blocks (- block-height (get purchase-block holding)))
               (interest (/ (* principal (* interest-rate held-blocks)) (* u10000 63072000))) ;; Annualized
               (total-return (+ principal interest)))
              
              ;; Mark bond as inactive if this is the last holder
              (map-delete bond-holdings { bond-id: bond-id, holder: tx-sender })
              
              (if (is-none (map-get? bond-holdings { bond-id: bond-id, holder: (get issuer bond) }))
                (begin
                  (map-set bonds bond-id { 
                    issuer: (get issuer bond),
                    bond-type: (get bond-type bond),
                    principal-amount: (get principal-amount bond),
                    interest-rate: (get interest-rate bond),
                    maturity-block: (get maturity-block bond),
                    issued-block: (get issued-block bond),
                    is-active: false,
                    auto-renew: (get auto-renew bond)
                  })
                  (var-set active-bonds-count (- (var-get active-bonds-count) u1))
                )
                (ok true)
              )
              
              (ok { principal: principal, interest: interest, total-return: total-return })
            )
          )
          (err ERR_BOND_NOT_FOUND)
        )
      )
      (err ERR_BOND_NOT_FOUND)
    )
  )
)

;; Admin functions
(define-public (set-factory-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get factory-admin)) ERR_UNAUTHORIZED)
    (var-set factory-admin new-admin)
    (ok true)
  )
)

(define-public (update-bond-template 
  (bond-type uint) 
  (maturity-blocks uint) 
  (min-amount uint) 
  (max-amount uint) 
  (interest-rate uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get factory-admin)) ERR_UNAUTHORIZED)
    
    (map-set bond-templates bond-type {
      maturity-blocks: maturity-blocks,
      min-amount: min-amount,
      max-amount: max-amount,
      interest-rate: interest-rate,
      auto-renew: (get auto-renew (unwrap! (map-get? bond-templates bond-type) ERR_INVALID_TERMS))
    })
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-bond-info (bond-id uint))
  (match (map-get? bonds bond-id)
    bond (ok bond)
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-bond-template (bond-type uint))
  (match (map-get? bond-templates bond-type)
    template (ok template)
    (err ERR_INVALID_TERMS)
  )
)

(define-read-only (get-user-holdings (user principal))
  (ok {
    user: user,
    note: "Functionality to be implemented - map iteration not available in Clarity",
  })
)

(define-read-only (get-factory-stats)
  (ok {
    total-bonds-issued: (var-get total-bonds-issued),
    active-bonds-count: (var-get active-bonds-count),
    admin: (var-get factory-admin)
  })
)

(define-read-only (is-authorized (caller principal))
  (is-eq caller (var-get factory-admin))
)

;; Initialize templates on deployment
(initialize-templates)