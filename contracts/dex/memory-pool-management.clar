;; memory-pool-management.clar
;; Conxian Protocol: Memory pool management for optimized data handling

;; Dependencies

;; Constants
(define-constant ERR_INSUFFICIENT_MEMORY u17001)
(define-constant ERR_INVALID_POOL_SIZE u17002)
(define-constant ERR_POOL_FULL u17003)
(define-constant ERR_POOL_EMPTY u17004)
(define-constant ERR_INVALID_ALLOCATION u17005)
(define-constant ERR_UNAUTHORIZED u17006)

;; Memory pool parameters
(define-constant MIN_POOL_SIZE u1000)
(define-constant MAX_POOL_SIZE u100000)
(define-constant DEFAULT_POOL_SIZE u10000)
(define-constant MAX_ALLOCATION_SIZE u1000)
(define-constant POOL_CLEANUP_THRESHOLD u9000) ;; 90% utilization

;; Data variables
(define-data-var total-pools-allocated uint u0)
(define-data-var total-memory-allocated uint u0)
(define-data-var cleanup-frequency uint u100)

;; Storage maps
(define-map memory-pools { pool-id: uint } { 
  pool-size: uint,
  allocated-slots: uint,
  free-slots: uint,
  last-cleanup: uint,
  pool-type: (string-ascii 16)
})

(define-map memory-allocations { pool-id: uint, slot-id: uint } { 
  allocated-to: principal,
  allocation-size: uint,
  allocation-time: uint,
  last-access: uint,
  data: (buff 256)
})

;; Read-only functions

;; @desc Get information about a specific memory pool
(define-read-only (get-pool-info (pool-id uint))
  (map-get? memory-pools { pool-id: pool-id }))

;; @desc Get the utilization percentage of a pool (scaled by 10000)
(define-read-only (get-pool-utilization (pool-id uint))
  (match (map-get? memory-pools { pool-id: pool-id })
    pool
      (let ((allocated (get allocated-slots pool))
            (total (get pool-size pool)))
        (if (> total u0)
            (ok (/ (* allocated u10000) total))
            (ok u0)
        )
    )
    (err ERR_INVALID_ALLOCATION)
  )
)

;; Public functions

;; @desc Create a new memory pool
(define-public (create-memory-pool (pool-size uint) (pool-type (string-ascii 16)))
  (begin
    (asserts! (>= pool-size MIN_POOL_SIZE) (err ERR_INVALID_POOL_SIZE))
    (asserts! (<= pool-size MAX_POOL_SIZE) (err ERR_INVALID_POOL_SIZE))
    
    (let ((pool-id (+ (var-get total-pools-allocated) u1)))
      (map-set memory-pools { pool-id: pool-id } {
        pool-size: pool-size,
        allocated-slots: u0,
        free-slots: pool-size,
        last-cleanup: stacks-block-time,
        pool-type: pool-type
      })
      
      (var-set total-pools-allocated pool-id)
      (var-set total-memory-allocated (+ (var-get total-memory-allocated) pool-size))
      
      (print { event: "pool-created", pool-id: pool-id, pool-size: pool-size, pool-type: pool-type })
      (ok pool-id)
    )
  )
)

;; @desc Allocate a slot in a memory pool
(define-public (allocate-memory (pool-id uint) (allocation-size uint) (initial-data (buff 256)))
  (begin
    (asserts! (> allocation-size u0) (err ERR_INVALID_ALLOCATION))
    (asserts! (<= allocation-size MAX_ALLOCATION_SIZE) (err ERR_INVALID_ALLOCATION))
    
    (let ((pool (unwrap! (map-get? memory-pools { pool-id: pool-id }) (err ERR_INVALID_ALLOCATION))))
      (asserts! (> (get free-slots pool) u0) (err ERR_POOL_FULL))
      
      (let ((slot-id (+ (get allocated-slots pool) u1)))
        (map-set memory-allocations { pool-id: pool-id, slot-id: slot-id } {
          allocated-to: tx-sender,
          allocation-size: allocation-size,
          allocation-time: stacks-block-time,
          last-access: stacks-block-time,
          data: initial-data
        })
        
        (map-set memory-pools { pool-id: pool-id } {
          pool-size: (get pool-size pool),
          allocated-slots: slot-id,
          free-slots: (- (get free-slots pool) u1),
          last-cleanup: (get last-cleanup pool),
          pool-type: (get pool-type pool)
        })

        (print { event: "memory-allocated", pool-id: pool-id, slot-id: slot-id, principal: tx-sender, size: allocation-size })
        (ok { pool-id: pool-id, slot-id: slot-id })
      )
    )
  )
)

;; @desc Deallocate a slot from a memory pool
(define-public (deallocate-memory (pool-id uint) (slot-id uint))
  (begin
    (let ((alloc (unwrap! (map-get? memory-allocations { pool-id: pool-id, slot-id: slot-id }) (err ERR_INVALID_ALLOCATION))))
      (asserts! (is-eq (get allocated-to alloc) tx-sender) (err ERR_UNAUTHORIZED))
      
      (map-delete memory-allocations { pool-id: pool-id, slot-id: slot-id })
      
      (let ((pool (unwrap-panic (map-get? memory-pools { pool-id: pool-id }))))
        (map-set memory-pools { pool-id: pool-id } {
          pool-size: (get pool-size pool),
          allocated-slots: (- (get allocated-slots pool) u1),
          free-slots: (+ (get free-slots pool) u1),
          last-cleanup: (get last-cleanup pool),
          pool-type: (get pool-type pool)
        })
        
        (print { event: "memory-deallocated", pool-id: pool-id, slot-id: slot-id, principal: tx-sender })
        (ok true)
      )
    )
  )
)

;; Admin functions

;; @desc Emergency cleanup of all memory pools
(define-public (emergency-cleanup-all-pools)
  (begin
    (asserts! (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    ;; Placeholder for full cleanup logic
    (ok true)
  )
)
