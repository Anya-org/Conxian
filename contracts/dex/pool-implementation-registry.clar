;; pool-implementation-registry.clar
;; Conxian DEX: Registry for pool implementations and factory contracts

;; Dependencies
(use-trait factory-trait .traits.factory-trait)

;; Constants
(define-constant ERR_INVALID_IMPLEMENTATION (err u22001))
(define-constant ERR_IMPLEMENTATION_EXISTS (err u22002))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err u22003))
(define-constant ERR_UNAUTHORIZED (err u22004))
(define-constant ERR_INVALID_FACTORY (err u22005))
(define-constant ERR_REGISTRY_INACTIVE (err u22006))
(define-constant ERR_ALREADY_REGISTERED (err u22007))
(define-constant ERR_NOTHING_TO_DO (err u22008))


;; Registry parameters
(define-constant MAX_IMPLEMENTATIONS u50)
(define-constant MAX_FACTORIES_PER_TYPE u10)
(define-constant REGISTRATION_FEE u1000000) ;; 1 STX equivalent

;; Data variables
(define-data-var registry-active bool true)
(define-data-var total-implementations uint u0)
(define-data-var total-factories uint u0)
(define-data-var last-cleanup uint u0)

;; Storage maps
(define-map pool-implementations uint {
  name: (string-ascii 64),
  version: (string-ascii 16),
  contract-address: principal,
  factory-address: principal,
  pool-type: (string-ascii 32),
  features: (list 10 (string-ascii 32)),
  min-liquidity: uint,
  max-liquidity: uint,
  fee-tier: uint,
  active: bool,
  registration-time: uint,
  registration-fee: uint
})

(define-map factory-registrations principal {
  impl-id: uint,
  pool-type: (string-ascii 32),
  authorized: bool,
  registration-time: uint,
  total-pools-created: uint
})

(define-map implementation-factories uint {
  factories: (list 10 principal),
  primary-factory: principal
})

(define-map pool-type-implementations (string-ascii 32) {
  implementations: (list 25 uint),
  default-impl: (optional uint)
})

(define-map implementation-stats uint {
  total-pools: uint,
  total-volume: uint,
  total-fees: uint,
  average-utilization: uint,
  last-update: uint
})

;; Events
(define-event (implementation-registered (impl-id uint) (name (string-ascii 64)) (contract principal)))
(define-event (factory-registered (factory principal) (impl-id uint)))
(define-event (implementation-deactivated (impl-id uint)))
(define-event (default-implementation-updated (pool-type (string-ascii 32)) (old-impl (optional uint)) (new-impl (optional uint))))
(define-event (pool-created (impl-id uint) (pool principal) (factory principal)))
(define-event (registry-cleanup (implementations-removed uint)))

;; --- Private helper functions

(define-private (filter-active-implementations (impl-ids (list 25 uint)))
  (fold filter-active-helper impl-ids (list)))

(define-private (filter-active-helper (impl-id uint) (acc (list 25 uint)))
  (if (unwrap! (is-implementation-active impl-id) false)
      (unwrap-panic (as-max-len? (append acc impl-id) u25))
      acc))

(define-private (implementation-exists (name (string-ascii 64)) (version (string-ascii 16)))
  (begin
    (fold (lambda (impl-id-n result)
      (if result
        true
        (match (map-get? pool-implementations impl-id-n)
          impl
            (and (is-eq (get name impl) name) (is-eq (get version impl) version))
          false
        )
      )
    ) (sequence-of u1 (var-get total-implementations)) false)
  )
)

;; --- Read-only functions

(define-read-only (get-implementation (impl-id uint))
  (map-get? pool-implementations impl-id))

(define-read-only (get-factory-registration (factory principal))
  (map-get? factory-registrations factory))

(define-read-only (is-factory-authorized (factory principal))
  (match (get-factory-registration factory)
    reg (ok (get authorized reg))
    (ok false)))

(define-read-only (get-pool-type-implementations (pool-type (string-ascii 32)))
  (map-get? pool-type-implementations pool-type))

(define-read-only (get-default-implementation (pool-type (string-ascii 32)))
  (match (get-pool-type-implementations pool-type)
    types (ok (get default-impl types))
    (ok none)))

(define-read-only (get-implementation-stats (impl-id uint))
  (map-get? implementation-stats impl-id))

(define-read-only (is-implementation-active (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get active impl))
    (ok false)))

(define-read-only (is-registry-active)
  (ok (var-get registry-active)))

;; --- Public functions

(define-public (register-implementation
  (name (string-ascii 64)) (version (string-ascii 16)) (contract-address principal)
  (factory-address principal) (pool-type (string-ascii 32)) (features (list 10 (string-ascii 32)))
  (min-liquidity uint) (max-liquidity uint) (fee-tier uint))
  (begin
    (asserts! (var-get registry-active) ERR_REGISTRY_INACTIVE)
    (asserts! (> (len name) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> (len version) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> max-liquidity min-liquidity) ERR_INVALID_IMPLEMENTATION)
    (asserts! (not (implementation-exists name version)) ERR_IMPLEMENTATION_EXISTS)

    (let ((impl-id (+ (var-get total-implementations) u1)))
      (map-set pool-implementations impl-id {
        name: name, version: version, contract-address: contract-address, factory-address: factory-address,
        pool-type: pool-type, features: features, min-liquidity: min-liquidity, max-liquidity: max-liquidity,
        fee-tier: fee-tier, active: true, registration-time: block-height, registration-fee: REGISTRATION_FEE
      })
      (map-set factory-registrations factory-address {
        impl-id: impl-id, pool-type: pool-type, authorized: true,
        registration-time: block-height, total-pools-created: u0
      })
      (map-set implementation-factories impl-id {
        factories: (list factory-address), primary-factory: factory-address
      })
      (match (map-get? pool-type-implementations pool-type)
        current-types
          (map-set pool-type-implementations pool-type
            (merge current-types {
              implementations: (unwrap-panic (as-max-len? (append (get implementations current-types) impl-id) u25))
            }))
        (map-set pool-type-implementations pool-type {
          implementations: (list impl-id), default-impl: (some impl-id)
        }))
      (map-set implementation-stats impl-id {
        total-pools: u0, total-volume: u0, total-fees: u0,
        average-utilization: u0, last-update: block-height
      })

      (var-set total-implementations impl-id)
      (var-set total-factories (+ (var-get total-factories) u1))
      (emit-event (implementation-registered impl-id name contract-address))
      (ok impl-id))))

(define-public (register-additional-factory (impl-id uint) (factory-address principal))
  (begin
    (asserts! (var-get registry-active) ERR_REGISTRY_INACTIVE)
    (asserts! (is-none (map-get? factory-registrations factory-address)) ERR_ALREADY_REGISTERED)
    (let ((impl (unwrap! (get-implementation impl-id) ERR_IMPLEMENTATION_NOT_FOUND))
          (impl-factories (unwrap! (map-get? implementation-factories impl-id) ERR_IMPLEMENTATION_NOT_FOUND)))
      (map-set factory-registrations factory-address {
        impl-id: impl-id, pool-type: (get pool-type impl), authorized: true,
        registration-time: block-height, total-pools-created: u0
      })
      (map-set implementation-factories impl-id
        (merge impl-factories {
          factories: (unwrap-panic (as-max-len? (append (get factories impl-factories) factory-address) u10))
        }))
      (var-set total-factories (+ (var-get total-factories) u1))
      (emit-event (factory-registered factory-address impl-id))
      (ok true))))

(define-public (deactivate-implementation (impl-id uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (let ((impl (unwrap! (get-implementation impl-id) ERR_IMPLEMENTATION_NOT_FOUND)))
      (asserts! (get active impl) ERR_NOTHING_TO_DO)
      (map-set pool-implementations impl-id (merge impl { active: false }))
      (let ((pool-type (get pool-type impl))
            (pool-type-data (unwrap! (get-pool-type-implementations (get pool-type impl)) ERR_IMPLEMENTATION_NOT_FOUND)))
        (if (is-eq (some impl-id) (get default-impl pool-type-data))
            (let ((active-impls (filter-active-implementations (get implementations pool-type-data))))
              (map-set pool-type-implementations pool-type
                (merge pool-type-data { default-impl: (if (> (len active-impls) u0) (some (element-at active-impls u0)) none) }))
            )
            (ok true)))
      (emit-event (implementation-deactivated impl-id))
      (ok true))))

(define-public (set-default-implementation (pool-type (string-ascii 32)) (impl-id uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (let ((impl (unwrap! (get-implementation impl-id) ERR_IMPLEMENTATION_NOT_FOUND))
          (pool-type-data (unwrap! (get-pool-type-implementations pool-type) ERR_IMPLEMENTATION_NOT_FOUND)))
      (asserts! (get active impl) ERR_IMPLEMENTATION_NOT_FOUND)
      (asserts! (is-eq (get pool-type impl) pool-type) ERR_INVALID_IMPLEMENTATION)
      (let ((old-default (get default-impl pool-type-data)))
        (map-set pool-type-implementations pool-type (merge pool-type-data { default-impl: (some impl-id) }))
        (emit-event (default-implementation-updated pool-type old-default (some impl-id)))
        (ok true)))))

(define-public (record-pool-creation (impl-id uint) (pool principal) (factory principal))
  (begin
    (asserts! (unwrap! (is-factory-authorized factory) false) ERR_UNAUTHORIZED)
    (match (map-get? factory-registrations factory)
      reg (map-set factory-registrations factory (merge reg { total-pools-created: (+ (get total-pools-created reg) u1) }))
      (ok true))
    (match (map-get? implementation-stats impl-id)
      stats
        (map-set implementation-stats impl-id
          (merge stats { total-pools: (+ (get total-pools stats) u1), last-update: block-height }))
      (map-set implementation-stats impl-id {
            total-pools: u1, total-volume: u0, total-fees: u0,
            average-utilization: u0, last-update: block-height
          }))
    (emit-event (pool-created impl-id pool factory))
    (ok true)))

(define-public (update-implementation-stats (impl-id uint) (volume uint) (fees uint) (utilization uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (let ((stats (unwrap! (get-implementation-stats impl-id) ERR_IMPLEMENTATION_NOT_FOUND))
          (total-pools (get total-pools stats)))
      (asserts! (> total-pools u0) ERR_NOTHING_TO_DO)
      (map-set implementation-stats impl-id {
        total-pools: total-pools,
        total-volume: (+ (get total-volume stats) volume),
        total-fees: (+ (get total-fees stats) fees),
        average-utilization: (/ (+ (* (get average-utilization stats) total-pools) utilization) total-pools),
        last-update: block-height
      })
      (ok true))))

(define-public (set-registry-active (active bool))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (var-set registry-active active)
    (ok true)))

(define-public (emergency-remove-implementation (impl-id uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
    (map-delete pool-implementations impl-id)
    (map-delete implementation-stats impl-id)
    (map-delete implementation-factories impl-id)
    ;; Note: This does not clean up pool-type-implementations, which could leave dangling IDs.
    ;; A production-ready contract would need more robust cleanup logic.
    (var-set total-implementations (- (var-get total-implementations) u1))
    (ok true)))

(define-read-only (get-implementations-by-type (pool-type (string-ascii 32)))
  (match (get-pool-type-implementations pool-type)
    types (ok (get implementations types))
    (ok (list))))

(define-read-only (get-factories-by-implementation (impl-id uint))
  (match (map-get? implementation-factories impl-id)
    factories (ok (get factories factories))
    (ok (list))))

(define-read-only (get-registry-summary)
  (ok {
    active: (var-get registry-active),
    total-implementations: (var-get total-implementations),
    total-factories: (var-get total-factories),
    last-cleanup: (var-get last-cleanup)
  }))
