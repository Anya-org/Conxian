;; Conxian Contract Registry
;; Central registry for contract discovery and management
;; Provides unified access to all Conxian protocol contracts

;; Error constants
(define-constant ERR_UNAUTHORIZED u9000)
(define-constant ERR_CONTRACT_NOT_FOUND u9001)
(define-constant ERR_CONTRACT_ALREADY_REGISTERED u9002)
(define-constant ERR_INVALID_CONTRACT_TYPE u9003)
(define-constant ERR_CONTRACT_INACTIVE u9004)

;; Contract types
(define-constant CONTRACT_TYPE_VAULT "vault")
(define-constant CONTRACT_TYPE_DEX_FACTORY "dex-factory")
(define-constant CONTRACT_TYPE_DEX_POOL "dex-pool")
(define-constant CONTRACT_TYPE_ROUTER "router")
(define-constant CONTRACT_TYPE_ORACLE "oracle")
(define-constant CONTRACT_TYPE_GOVERNANCE "governance")
(define-constant CONTRACT_TYPE_TREASURY "treasury")
(define-constant CONTRACT_TYPE_MATH_LIB "math-lib")
(define-constant CONTRACT_TYPE_CONCENTRATED_POOL "concentrated-pool")
(define-constant CONTRACT_TYPE_WEIGHTED_POOL "weighted-pool")
(define-constant CONTRACT_TYPE_STABLE_POOL "stable-pool")

;; Admin controls
(define-data-var admin principal tx-sender)
(define-data-var registry-active bool true)

;; Contract registry mapping
(define-map contract-registry
  {contract-type: (string-ascii 20), version: (string-ascii 10)}
  {
    contract-address: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    active: bool,
    deployed-at: uint,
    last-updated: uint
  })

;; Contract address to metadata mapping
(define-map contract-metadata
  principal
  {
    contract-type: (string-ascii 20),
    version: (string-ascii 10),
    dependencies: (list 10 principal),
    interfaces: (list 5 (string-ascii 30))
  })

;; Active contract versions for each type
(define-map active-contracts
  (string-ascii 20)
  {
    current-version: (string-ascii 10),
    contract-address: principal,
    backup-address: (optional principal)
  })

;; Initialize registry with core production contracts
(define-private (initialize-core-contracts)
  (begin
    ;; Register core vault
    (try! (register-contract 
      CONTRACT_TYPE_VAULT 
      "v1.0" 
      .vault 
      "Conxian Core Vault" 
      "Main vault contract for liquidity provision and yield farming"))
    
    ;; Register enhanced DEX factory
    (try! (register-contract 
      CONTRACT_TYPE_DEX_FACTORY 
      "v2.0" 
      .dex-factory-enhanced 
      "Enhanced DEX Factory" 
      "Multi-pool type factory with advanced features"))
    
    ;; Register advanced router
    (try! (register-contract 
      CONTRACT_TYPE_ROUTER 
      "v3.0" 
      .multi-hop-router-v3 
      "Multi-Hop Router V3" 
      "Advanced routing with Dijkstra algorithm and price optimization"))
    
    ;; Register enhanced oracle
    (try! (register-contract 
      CONTRACT_TYPE_ORACLE 
      "v2.0" 
      .oracle-aggregator-enhanced 
      "Enhanced Oracle Aggregator" 
      "TWAP-enabled oracle with manipulation detection and caching"))
    
    ;; Register concentrated liquidity pool
    (try! (register-contract 
      CONTRACT_TYPE_CONCENTRATED_POOL 
      "v1.0" 
      .concentrated-liquidity-pool 
      "Concentrated Liquidity Pool" 
      "Uniswap V3-style concentrated liquidity with tick-based ranges"))
    
    ;; Register advanced math library
    (try! (register-contract 
      CONTRACT_TYPE_MATH_LIB 
      "v2.0" 
      .math-lib-advanced 
      "Advanced Math Library" 
      "18-decimal precision math with Newton-Raphson and Taylor series"))
    
    ;; Register governance
    (try! (register-contract 
      CONTRACT_TYPE_GOVERNANCE 
      "v1.0" 
      .dao-governance 
      "DAO Governance" 
      "Decentralized governance with proposal and voting mechanisms"))
    
    ;; Register treasury
    (try! (register-contract 
      CONTRACT_TYPE_TREASURY 
      "v1.0" 
      .treasury 
      "Treasury Management" 
      "Protocol treasury with multi-signature controls"))
    
    (ok true)))

;; Register a new contract in the registry
(define-public (register-contract 
  (contract-type (string-ascii 20))
  (version (string-ascii 10))
  (contract-address principal)
  (name (string-ascii 50))
  (description (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (var-get registry-active) (err ERR_CONTRACT_INACTIVE))
    
    ;; Check if contract already registered
    (asserts! (is-none (map-get? contract-registry {contract-type: contract-type, version: version})) 
              (err ERR_CONTRACT_ALREADY_REGISTERED))
    
    ;; Register contract
    (map-set contract-registry
      {contract-type: contract-type, version: version}
      {
        contract-address: contract-address,
        name: name,
        description: description,
        active: true,
        deployed-at: block-height,
        last-updated: block-height
      })
    
    ;; Update active contract for this type
    (map-set active-contracts
      contract-type
      {
        current-version: version,
        contract-address: contract-address,
        backup-address: none
      })
    
    (print {
      event: "contract-registered",
      contract-type: contract-type,
      version: version,
      contract-address: contract-address,
      name: name
    })
    
    (ok true)))

;; Get active contract for a specific type
(define-read-only (get-active-contract (contract-type (string-ascii 20)))
  (map-get? active-contracts contract-type))

;; Get contract details by type and version
(define-read-only (get-contract-details (contract-type (string-ascii 20)) (version (string-ascii 10)))
  (map-get? contract-registry {contract-type: contract-type, version: version}))

;; Get all versions of a contract type
(define-read-only (get-contract-versions (contract-type (string-ascii 20)))
  ;; Simplified implementation - in production would iterate through all versions
  (let ((active (map-get? active-contracts contract-type)))
    (match active
      contract-info (list (get current-version contract-info))
      (list))))

;; Update contract status (activate/deactivate)
(define-public (update-contract-status 
  (contract-type (string-ascii 20))
  (version (string-ascii 10))
  (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    
    (let ((contract-info (unwrap! (map-get? contract-registry {contract-type: contract-type, version: version})
                                  (err ERR_CONTRACT_NOT_FOUND))))
      
      (map-set contract-registry
        {contract-type: contract-type, version: version}
        (merge contract-info {active: active, last-updated: block-height}))
      
      (print {
        event: "contract-status-updated",
        contract-type: contract-type,
        version: version,
        active: active
      })
      
      (ok true))))

;; Set active version for a contract type
(define-public (set-active-version 
  (contract-type (string-ascii 20))
  (version (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    
    (let ((contract-info (unwrap! (map-get? contract-registry {contract-type: contract-type, version: version})
                                  (err ERR_CONTRACT_NOT_FOUND))))
      
      ;; Ensure contract is active
      (asserts! (get active contract-info) (err ERR_CONTRACT_INACTIVE))
      
      ;; Update active contracts mapping
      (map-set active-contracts
        contract-type
        {
          current-version: version,
          contract-address: (get contract-address contract-info),
          backup-address: none
        })
      
      (print {
        event: "active-version-updated",
        contract-type: contract-type,
        version: version,
        contract-address: (get contract-address contract-info)
      })
      
      (ok true))))

;; Get contract address by type (returns active version)
(define-read-only (get-contract-address (contract-type (string-ascii 20)))
  (let ((active-info (map-get? active-contracts contract-type)))
    (match active-info
      contract-data (some (get contract-address contract-data))
      none)))

;; Check if contract is registered and active
(define-read-only (is-contract-active (contract-address principal))
  (let ((metadata (map-get? contract-metadata contract-address)))
    (match metadata
      meta-data 
        (let ((contract-info (map-get? contract-registry 
                               {contract-type: (get contract-type meta-data), 
                                version: (get version meta-data)})))
          (match contract-info
            info (get active info)
            false))
      false)))

;; Get all active contracts
(define-read-only (get-all-active-contracts)
  ;; Simplified implementation - returns core contract types
  (list
    {type: CONTRACT_TYPE_VAULT, address: (get-contract-address CONTRACT_TYPE_VAULT)}
    {type: CONTRACT_TYPE_DEX_FACTORY, address: (get-contract-address CONTRACT_TYPE_DEX_FACTORY)}
    {type: CONTRACT_TYPE_ROUTER, address: (get-contract-address CONTRACT_TYPE_ROUTER)}
    {type: CONTRACT_TYPE_ORACLE, address: (get-contract-address CONTRACT_TYPE_ORACLE)}
    {type: CONTRACT_TYPE_CONCENTRATED_POOL, address: (get-contract-address CONTRACT_TYPE_CONCENTRATED_POOL)}
    {type: CONTRACT_TYPE_MATH_LIB, address: (get-contract-address CONTRACT_TYPE_MATH_LIB)}
    {type: CONTRACT_TYPE_GOVERNANCE, address: (get-contract-address CONTRACT_TYPE_GOVERNANCE)}
    {type: CONTRACT_TYPE_TREASURY, address: (get-contract-address CONTRACT_TYPE_TREASURY)}
  ))

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set registry-active false)
    (print {event: "registry-paused", admin: tx-sender})
    (ok true)))

(define-public (emergency-resume)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set registry-active true)
    (print {event: "registry-resumed", admin: tx-sender})
    (ok true)))

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (print {event: "admin-updated", old-admin: tx-sender, new-admin: new-admin})
    (ok true)))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-registry-active)
  (var-get registry-active))

;; Initialize the registry with core contracts on deployment
(initialize-core-contracts)