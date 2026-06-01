;; dex-factory.clar
;; Conxian Protocol Standard Contract - Apex Upgrade (v1.1.0)
;; Enhanced DEX Factory supporting multiple pool types and CSF-compliant external protocols.

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_POOL_EXISTS (err u2002))
(define-constant ERR_PROTOCOL_NOT_REGISTERED (err u2003))

;; --- Data Vars ---
(define-data-var pool-count uint u0)
(define-data-var csf-registry-count uint u0)

;; --- Maps ---
(define-map pools
    { token0: principal, token1: principal, type: uint }
    principal
)

(define-map pool-by-id
    uint
    { token0: principal, token1: principal, type: uint, pool: principal }
)

;; CSF Registry: Tracks external protocols (e.g. Zest StackingDAO Arkadiko) that implement CSF
(define-map csf-registry principal { name: (string-ascii 256), registered-at: uint, active: bool })
(define-map csf-by-index uint principal)

;; --- Public Administrative Functions ---

;; @desc Register pool
;; @returns (response bool uint)
(define-public (register-pool (token-a principal) (token-b principal) (type uint) (pool-contract principal))
    (let
        (
            (token0 token-a)
            (token1 token-b)
            (current-count (var-get pool-count))
        )
        (begin
            (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) ERR_UNAUTHORIZED)
            (asserts! (is-none (map-get? pools { token0: token0, token1: token1, type: type })) ERR_POOL_EXISTS)

            (map-set pools { token0: token0, token1: token1, type: type } pool-contract)
            (map-set pool-by-id (+ current-count u1) {
                token0: token0,
                token1: token1,
                type: type,
                pool: pool-contract
            })
            (var-set pool-count (+ current-count u1))
            (ok true)
        )
    )
)

;; @desc Register a CSF-compliant external protocol for global discovery
(define-public (register-csf-protocol (protocol principal) (name (string-ascii 256)))
  (let ((current-index (var-get csf-registry-count)))
    (begin
      (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) ERR_UNAUTHORIZED)
      (map-set csf-registry protocol { name: name, registered-at: block-height, active: true })
      (map-set csf-by-index (+ current-index u1) protocol)
      (var-set csf-registry-count (+ current-index u1))
      (print { event: "csf-protocol-registered", protocol: protocol, name: name })
      (ok true)
    )
  )
)

;; @desc Toggle the active state of a registered CSF protocol
(define-public (toggle-csf-protocol (protocol principal))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) ERR_UNAUTHORIZED)
    (let ((current-data (unwrap! (map-get? csf-registry protocol) ERR_PROTOCOL_NOT_REGISTERED)))
      (map-set csf-registry protocol (merge current-data { active: (not (get active current-data)) }))
      (ok (not (get active current-data)))
    )
  )
)

;; --- Read-only Functions ---

;; @desc Returns the contract principal for a specific pool
(define-read-only (get-pool (token0 principal) (token1 principal) (type uint))
    (map-get? pools { token0: token0, token1: token1, type: type })
)

;; @desc Returns the total number of registered pools
(define-read-only (get-pool-count) (ok (var-get pool-count)))

;; @desc Returns metadata for a registered external protocol
(define-read-only (get-csf-protocol (protocol principal))
  (ok (map-get? csf-registry protocol))
)

;; @desc Returns the total number of registered CSF protocols
(define-read-only (get-csf-registry-count) (ok (var-get csf-registry-count)))

;; @desc Returns the protocol principal at a specific registry index
(define-read-only (get-csf-protocol-by-index (index uint))
  (ok (map-get? csf-by-index index))
)
