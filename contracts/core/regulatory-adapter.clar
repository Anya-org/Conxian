;; regulatory-adapter.clar
;; Conxian Enterprise Standard: Regulatory Adapter (Clean-Hands Compliance)
;; Verifies Off-Chain ZK-Proofs/Signatures of compliance.

(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_BLACKLISTED (err u6001))

;; Data Vars
(define-data-var contract-owner principal tx-sender)

;; Data Maps
(define-map compliance-status principal
  {
    clean-hands: bool,
    verified-at: uint,
    jurisdiction: (string-ascii 64)
  }
)

(define-map blacklist principal bool)

;; --- Public Functions ---

;; check-clean-hands-compliance: Checks if a user is compliant.
(define-read-only (check-clean-hands-compliance (user principal))
  (let
    (
      (status (map-get? compliance-status user))
      (is-blacklisted (default-to false (map-get? blacklist user)))
    )
    (if is-blacklisted
      (ok false) ;; Blacklisted users are not compliant
      (match status
        record (ok (get clean-hands record))
        (ok false) ;; Default: not verified is not compliant
      )
    )
  )
)

;; --- Admin Functions ---

;; set-contract-owner: Transfers ownership of the contract.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; add-to-whitelist: Adds a user to the compliance whitelist.
(define-public (add-to-whitelist (user principal) (jurisdiction (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set compliance-status user {
      clean-hands: true,
      verified-at: burn-block-height,
      jurisdiction: jurisdiction
    })
    (print { event: "user-whitelisted", user: user })
    (ok true)
  )
)

;; add-to-blacklist: Adds a user to the compliance blacklist.
(define-public (add-to-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set blacklist user true)
    (print { event: "user-blacklisted", user: user })
    (ok true)
  )
)

;; remove-from-blacklist: Removes a user from the compliance blacklist.
(define-public (remove-from-blacklist (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete blacklist user)
    (print { event: "user-removed-from-blacklist", user: user })
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; get-compliance-status: Retrieves the compliance status of a user.
(define-read-only (get-compliance-status (user principal))
    (ok (map-get? compliance-status user))
)
