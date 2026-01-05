;; Factory Trait
;; Trait for factory contracts that create other contracts

;; Trait definition for factory functionality
(define-trait factory-trait
  ;; Create a new instance
  (create-instance (principal) (response uint principal))
  
  ;; Get all instances created by this factory
  (get-instances () (response (list 100 principal) uint))
  
  ;; Get instance by ID
  (get-instance (uint) (response principal uint))
  
  ;; Get total number of instances
  (get-instance-count () (response uint uint))
  
  ;; Check if an instance exists
  (instance-exists (principal) (response bool uint))
  
  ;; Get instance metadata
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  
  ;; Update instance metadata
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  
  ;; Deactivate an instance
  (deactivate-instance (principal) (response bool uint))
  
  ;; Reactivate an instance
  (reactivate-instance (principal) (response bool uint))
  
  ;; Get factory owner
  (get-owner () (response principal uint))
  
  ;; Transfer factory ownership
  (transfer-ownership (principal) (response bool uint))
)

;; Extended factory trait with additional functionality
(define-trait advanced-factory-trait
  ;; Include basic factory trait
  (create-instance (principal) (response uint principal))
  (get-instances () (response (list 100 principal) uint))
  (get-instance (uint) (response principal uint))
  (get-instance-count () (response uint uint))
  (instance-exists (principal) (response bool uint))
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  (deactivate-instance (principal) (response bool uint))
  (reactivate-instance (principal) (response bool uint))
  (get-owner () (response principal uint))
  (transfer-ownership (principal) (response bool uint))
  
  ;; Advanced functionality
  (batch-create-instances ((list 20 principal)) (response (list 20 uint) uint))
  (get-active-instances () (response (list 100 principal) uint))
  (get-inactive-instances () (response (list 100 principal) uint))
  (get-instance-creation-time (principal) (response uint uint))
  (get-instance-creator (principal) (response principal uint))
  (set-instance-template (principal (string-ascii 256)) (response bool uint))
  (get-instance-template (principal) (response (string-ascii 256) uint))
  (clone-instance (principal principal) (response principal uint))
  (migrate-instance (principal principal) (response bool uint))
)

;; Pool factory trait (specialized for DEX pools)
(define-trait pool-factory-trait
  ;; Basic factory functionality
  (create-instance (principal) (response uint principal))
  (get-instances () (response (list 100 principal) uint))
  (get-instance (uint) (response principal uint))
  (get-instance-count () (response uint uint))
  (instance-exists (principal) (response bool uint))
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  (deactivate-instance (principal) (response bool uint))
  (reactivate-instance (principal) (response bool uint))
  (get-owner () (response principal uint))
  (transfer-ownership (principal) (response bool uint))
  
  ;; Pool-specific functionality
  (create-pool (principal principal (list 10 uint)) (response uint principal))
  (get-pools-by-token (principal) (response (list 50 principal) uint))
  (get-pool-type (principal) (response (string-ascii 32) uint))
  (get-pool-tokens (principal) (response (list 10 principal) uint))
  (calculate-pool-address (principal (list 10 uint)) (response principal uint))
  (validate-pool-parameters (principal (list 10 uint)) (response bool uint))
  (get-pool-fee (principal) (response uint uint))
  (set-pool-fee (principal uint) (response bool uint))
)

;; Token factory trait (specialized for token creation)
(define-trait token-factory-trait
  ;; Basic factory functionality
  (create-instance (principal) (response uint principal))
  (get-instances () (response (list 100 principal) uint))
  (get-instance (uint) (response principal uint))
  (get-instance-count () (response uint uint))
  (instance-exists (principal) (response bool uint))
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  (deactivate-instance (principal) (response bool uint))
  (reactivate-instance (principal) (response bool uint))
  (get-owner () (response principal uint))
  (transfer-ownership (principal) (response bool uint))
  
  ;; Token-specific functionality
  (create-token ((string-ascii 32) (string-ascii 8) (string-ascii 256) uint) (response uint principal))
  (get-tokens-by-symbol ((string-ascii 8)) (response (list 50 principal) uint))
  (get-token-info (principal) (response { name: (string-ascii 32), symbol: (string-ascii 8), uri: (string-ascii 256), decimals: uint } uint))
  (validate-token-parameters ((string-ascii 32) (string-ascii 8) (string-ascii 256) uint) (response bool uint))
  (calculate-token-address ((string-ascii 32) (string-ascii 8)) (response principal uint))
  (set-token-uri (principal (string-ascii 256)) (response bool uint))
)

;; NFT factory trait (specialized for NFT creation)
(define-trait nft-factory-trait
  ;; Basic factory functionality
  (create-instance (principal) (response uint principal))
  (get-instances () (response (list 100 principal) uint))
  (get-instance (uint) (response principal uint))
  (get-instance-count () (response uint uint))
  (instance-exists (principal) (response bool uint))
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  (deactivate-instance (principal) (response bool uint))
  (reactivate-instance (principal) (response bool uint))
  (get-owner () (response principal uint))
  (transfer-ownership (principal) (response bool uint))
  
  ;; NFT-specific functionality
  (create-nft-collection ((string-ascii 32) (string-ascii 8) (string-ascii 256)) (response uint principal))
  (get-nft-collections-by-owner (principal) (response (list 50 principal) uint))
  (get-nft-collection-info (principal) (response { name: (string-ascii 32), symbol: (string-ascii 8), uri: (string-ascii 256), total-supply: uint } uint))
  (validate-nft-parameters ((string-ascii 32) (string-ascii 8) (string-ascii 256)) (response bool uint))
  (calculate-nft-address ((string-ascii 32) (string-ascii 8)) (response principal uint))
  (set-collection-uri (principal (string-ascii 256)) (response bool uint))
  (mint-nft (principal (string-ascii 256)) (response uint uint))
)

;; Registry factory trait (specialized for registry creation)
(define-trait registry-factory-trait
  ;; Basic factory functionality
  (create-instance (principal) (response uint principal))
  (get-instances () (response (list 100 principal) uint))
  (get-instance (uint) (response principal uint))
  (get-instance-count () (response uint uint))
  (instance-exists (principal) (response bool uint))
  (get-instance-metadata (principal) (response (string-ascii 256) uint))
  (update-instance-metadata (principal (string-ascii 256)) (response bool uint))
  (deactivate-instance (principal) (response bool uint))
  (reactivate-instance (principal) (response bool uint))
  (get-owner () (response principal uint))
  (transfer-ownership (principal) (response bool uint))
  
  ;; Registry-specific functionality
  (create-registry ((string-ascii 32) (string-ascii 16)) (response uint principal))
  (get-registries-by-type ((string-ascii 16)) (response (list 50 principal) uint))
  (get-registry-info (principal) (response { name: (string-ascii 32), type: (string-ascii 16), entries: uint } uint))
  (validate-registry-parameters ((string-ascii 32) (string-ascii 16)) (response bool uint))
  (calculate-registry-address ((string-ascii 32) (string-ascii 16)) (response principal uint))
  (register-entry (principal (string-ascii 64) principal) (response bool uint))
  (get-registry-entry (principal (string-ascii 64)) (response (optional principal) uint))
)

;; Utility functions for factory implementations
(define-read-only (validate-factory-name (name (string-ascii 32)))
  (and (> (len name) u0) (<= (len name) u32))
)

(define-read-only (validate-instance-id (id uint))
  (> id u0)
)

(define-read-only (calculate-instance-address (factory principal creator principal nonce uint))
  (begin
    ;; Simplified address calculation - in practice would use more sophisticated method
    (hash160 (concat (concat (principal-to-buff? factory) (principal-to-buff? creator)) (int-to-buff nonce)))
  )
)

(define-read-only (generate-instance-id (creator principal) (nonce uint))
  (begin
    ;; Generate unique ID based on creator and nonce
    (hash160 (concat (principal-to-buff? creator) (int-to-buff nonce)))
  )
)

;; Standard factory errors
(define-constant ERR_FACTORY_NOT_OWNER u9001)
(define-constant ERR_FACTORY_INVALID_NAME u9002)
(define-constant ERR_FACTORY_INVALID_ID u9003)
(define-constant ERR_FACTORY_INSTANCE_EXISTS u9004)
(define-constant ERR_FACTORY_INSTANCE_NOT_FOUND u9005)
(define-constant ERR_FACTORY_INSTANCE_INACTIVE u9006)
(define-constant ERR_FACTORY_INVALID_PARAMETERS u9007)
(define-constant ERR_FACTORY_CREATION_FAILED u9008)
(define-constant ERR_FACTORY_TRANSFER_FAILED u9009)
(define-constant ERR_FACTORY_METADATA_UPDATE_FAILED u9010)
(define-constant ERR_FACTORY_BATCH_SIZE_EXCEEDED u9011)
(define-constant ERR_FACTORY_UNAUTHORIZED u9012)

;; Factory events
(define-event (instance-created (instance-id uint) (instance-address principal) (creator principal)))
(define-event (instance-deactivated (instance-id uint) (instance-address principal)))
(define-event (instance-reactivated (instance-id uint) (instance-address principal)))
(define-event (instance-metadata-updated (instance-id uint) (instance-address principal) (metadata (string-ascii 256))))
(define-event (factory-ownership-transferred (old-owner principal) (new-owner principal)))
(define-event (batch-instances-created (instance-ids (list 20 uint)) (instance-addresses (list 20 principal))))
(define-event (instance-cloned (original-instance principal) (new-instance principal) (instance-id uint)))
(define-event (instance-migrated (old-instance principal) (new-instance principal)))
