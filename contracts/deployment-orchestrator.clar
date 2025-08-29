;; deployment-orchestrator.clar
;; Orchestrates the deployment and initialization of Conxian contracts

;; Traits
(use-trait ft-trait .sip-010-trait.sip-010-trait)
(use-trait nft-trait .sip-009-trait.sip-009-trait)
;; Oracle trait for dynamic calls
(use-trait oracle-trait .oracle-aggregator-trait.oracle-aggregator-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_INITIALIZED u101)
(define-constant ERR_NOT_INITIALIZED u102)
(define-constant ERR_INVALID_CONTRACT u103)
(define-constant ERR_DEPLOYMENT_FAILED u104)

;; State variables
(define-data-var admin principal tx-sender)
(define-data-var deployment-status (string-ascii 32) "not-started")
(define-data-var vault-address (optional principal) none)
(define-data-var token-address (optional principal) none)
(define-data-var oracle-address (optional principal) none)
(define-data-var enhanced-caller-address (optional principal) none)

;; Deployment registry
(define-map deployed-contracts
  { contract-name: (string-ascii 64) }
  {
    address: principal,
    version: (string-utf8 128),
    deployed-at: uint,
    initialized: bool
  }
)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (register-contract 
                (contract-name (string-ascii 64)) 
                (contract-address principal)
                (contract-version (string-utf8 128)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    
    ;; Register the contract
    (map-set deployed-contracts
      { contract-name: contract-name }
      {
        address: contract-address,
        version: contract-version,
        deployed-at: block-height,
        initialized: false
      }
    )
    
    ;; Set core contract addresses if applicable
    (if (is-eq contract-name "vault")
      (var-set vault-address (some contract-address))
      false
    )
    
    (if (is-eq contract-name "token")
      (var-set token-address (some contract-address))
      false
    )
    
    (if (is-eq contract-name "oracle")
      (var-set oracle-address (some contract-address))
      false
    )
    
    (if (is-eq contract-name "enhanced-caller")
      (var-set enhanced-caller-address (some contract-address))
      false
    )
    
    (ok contract-address)
  )
)

(define-public (mark-contract-initialized (contract-name (string-ascii 64)))
  (let (
    (contract-data (unwrap! (map-get? deployed-contracts { contract-name: contract-name }) (err ERR_INVALID_CONTRACT)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    
    ;; Update initialization status
    (map-set deployed-contracts
      { contract-name: contract-name }
      (merge contract-data { initialized: true })
    )
    
    (ok true)
  )
)

;; Orchestration functions
(use-trait vault-init .vault-init-trait.vault-init-trait)

(define-public (initialize-vault (vault <vault-init>) (token-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
  (try! (as-contract (contract-call? vault initialize-token token-principal)))
    (try! (mark-contract-initialized "vault"))
    (ok true)
  )
)

(use-trait ec-admin .enhanced-caller-admin-trait.enhanced-caller-admin-trait)

(define-public (initialize-enhanced-caller (enhanced-caller <ec-admin>) (vault principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (try! (as-contract (contract-call? enhanced-caller authorize-contract vault true)))
    (try! (mark-contract-initialized "enhanced-caller"))
    (ok true)
  )
)

(define-public (initialize-oracle (oracle <oracle-trait>) (base principal) (quote principal) (min-sources uint) (initial-oracles (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    ;; Initialize oracle with base trading pair
    (try! (as-contract (contract-call? oracle register-pair base quote initial-oracles min-sources)))
    ;; Mark as initialized
    (try! (mark-contract-initialized "oracle"))
    (ok (contract-of oracle))
  )
)

;; Status tracking
(define-public (update-deployment-status (new-status (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set deployment-status new-status)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-deployment-status)
  (var-get deployment-status)
)

(define-read-only (get-contract-info (contract-name (string-ascii 64)))
  (map-get? deployed-contracts { contract-name: contract-name })
)

(define-read-only (is-contract-initialized (contract-name (string-ascii 64)))
  (default-to false (get initialized (map-get? deployed-contracts { contract-name: contract-name })))
)

(define-read-only (get-all-deployed-contracts)
  (ok true)  ;; This would return list of all contracts in a real implementation
)

;; Production deployment checklist
(define-map deployment-checklist
  { item-id: (string-ascii 64) }
  { completed: bool, completed-at: (optional uint) }
)

(define-public (complete-checklist-item (item-id (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set deployment-checklist
      { item-id: item-id }
      { completed: true, completed-at: (some block-height) }
    )
    (ok true)
  )
)

(define-read-only (get-checklist-status (item-id (string-ascii 64)))
  (default-to { completed: false, completed-at: none } (map-get? deployment-checklist { item-id: item-id }))
)

;; Initialize checklist
(map-set deployment-checklist { item-id: "contracts-deployed" } { completed: false, completed-at: none })
(map-set deployment-checklist { item-id: "integration-tested" } { completed: false, completed-at: none })
(map-set deployment-checklist { item-id: "security-audited" } { completed: false, completed-at: none })
(map-set deployment-checklist { item-id: "admin-configured" } { completed: false, completed-at: none })
(map-set deployment-checklist { item-id: "production-ready" } { completed: false, completed-at: none })
