;; ownership-trait.clar
;; Defines the standard ownership interface for contracts

(define-trait ownership-trait
  (
    ;; Get the current owner of the contract
    (get-owner () (response principal uint))
    
    ;; Transfer ownership to a new principal
    (transfer-ownership (principal) (response bool uint))
    
    ;; Renounce ownership (set to contract itself or burn address)
    (renounce-ownership () (response bool uint))
    
    ;; Check if caller is the owner
    (is-owner (principal) (response bool uint))
  )
)
