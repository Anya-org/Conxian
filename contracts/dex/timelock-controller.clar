;; timelock-controller.clar
;; Conxian Protocol: Timelock controller for time-locked operations and governance

;; Dependencies
(use-trait core-traits .core-traits.core-traits)
(use-trait defi-traits .defi-traits.defi-traits)

;; Constants
(define-constant ERR_TIMELOCK_NOT_FOUND (err 36001))
(define-constant ERR_TIMELOCK_ALREADY_EXISTS (err 36002))
(define-constant ERR_TIMELOCK_NOT_EXPIRED (err 36003))
(define-constant ERR_TIMELOCK_NOT_ACTIVE (err 36004))
(define-constant ERR_INSUFFICIENT_PERMISSIONS (err 36005))
(define-constant ERR_INVALID_DURATION (err 36006))

;; Timelock parameters
(define-constant MIN_DURATION u10) ;; Minimum 10 blocks
(define-constant MAX_DURATION u1000000) ;; Maximum 1M blocks
(define-constant DEFAULT_DURATION u1000) ;; Default 1000 blocks
(define-constant MAX_TIMELOCKS u100) ;; Maximum timelocks per user
(define-constant TIMELOCK_PRECISION u1) ;; Block-level precision

;; Data variables
(define-data-var timelock-active bool true)
(define-data-var total-timelocks uint u0)
(define-data-var active-timelocks uint u0)
(define-data-var last-cleanup uint u0)

;; Storage maps
(define-map timelocks { timelock-id: (buff 32) } { 
  creator: principal,
  target-contract: principal,
  target-function: (string-ascii 64),
  parameters: (list 5 { key: (string-ascii 32), value: (string-ascii 128) }),
  unlock-height: uint,
  created-height: uint,
  executed: bool,
  execution-height: uint,
  cancelled: bool,
  cancellation-height: uint,
  active: bool,
  metadata: (string-ascii 256)
})

(define-map timelock-executions { execution-id: (buff 32) } { 
  timelock-id: (buff 32),
  executor: principal,
  execution-height: uint,
  result: (optional (string-ascii 256)),
  success: bool,
  gas-used: uint
})

(define-map user-timelocks { user: principal } { 
  active-timelocks: uint,
  total-timelocks: uint,
  last-timelock: uint,
  favorite-targets: (list 10 { contract: principal, function: (string-ascii 64) })
})

(define-map timelock-statistics { target-contract: principal } { 
  total-timelocks: uint,
  successful-executions: uint,
  failed-executions: uint,
  average-duration: uint,
  last-execution: uint
})

;; Events
(define-event (timelock-created (timelock-id (buff 32)) (creator principal) (target-contract principal) (unlock-height uint)))
(define-event (timelock-executed (timelock-id (buff 32)) (executor principal) (success bool)))
(define-event (timelock-cancelled (timelock-id (buff 32)) (canceller principal)))
(define-event (timelock-expired (timelock-id (buff 32))))
(define-event (timelock-activated (timelock-id (buff 32))))
(define-event (timelock-deactivated (timelock-id (buff 32))))

;; Read-only functions

(define-read-only (get-timelock (timelock-id (buff 32)))
  (map-get? timelocks { timelock-id: timelock-id }))

(define-read-only (get-timelock-creator (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock creator))
    none (ok tx-sender)
  )
)

(define-read-only (get-timelock-target (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock target-contract))
    none (ok tx-sender)
  )
)

(define-read-only (get-timelock-unlock-height (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock unlock-height))
    none (ok u0)
  )
)

(define-read-only (is-timelock-active (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock active))
    none (ok false)
  )
)

(define-read-only (is-timelock-executed (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock executed))
    none (ok false)
  )
)

(define-read-only (is-timelock-cancelled (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock (ok (get timelock cancelled))
    none (ok false)
  )
)

(define-read-only (get-timelock-execution (execution-id (buff 32)))
  (map-get? timelock-executions { execution-id: execution-id }))

(define-read-only (get-user-timelocks (user principal))
  (map-get? user-timelocks { user: user }))

(define-read-only (get-timelock-statistics (target-contract principal))
  (map-get? timelock-statistics { target-contract: target-contract }))

(define-read-only (is-timelock-active-global)
  (var-get timelock-active))

(define-read-only (get-total-timelocks)
  (var-get total-timelocks))

(define-read-only (get-active-timelocks)
  (var-get active-timelocks))

;; Public functions

(define-public (create-timelock 
  (target-contract principal)
  (target-function (string-ascii 64))
  (parameters (list 5 { key: (string-ascii 32), value: (string-ascii 128) }))
  (duration uint)
  (metadata (string-ascii 256))
)
  (begin
    ;; Validate inputs
    (asserts! (principal? target-contract) ERR_TIMELOCK_NOT_FOUND)
    (asserts! (> (len target-function) u0) ERR_TIMELOCK_NOT_FOUND)
    (asserts! (> duration MIN_DURATION) ERR_INVALID_DURATION)
    (asserts! (<= duration MAX_DURATION) ERR_INVALID_DURATION)
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check user timelock limit
    (let ((user_info (get-user-timelocks tx-sender)))
      (if (is-some user_info)
          (asserts! (< (get-optional user_info).active-timelocks MAX_TIMELOCKS) ERR_TIMELOCK_ALREADY_EXISTS)
          true
      )
    )
    
    ;; Generate timelock ID
    (let ((timelock-id (hash160 (concat (principal-to-buff? target-contract) (string-ascii target-function)))))
      (let ((unlock-height (+ block-height duration)))
        
        ;; Create timelock
        (map-set timelocks { timelock-id: timelock-id } {
          creator: tx-sender,
          target-contract: target-contract,
          target-function: target-function,
          parameters: parameters,
          unlock-height: unlock-height,
          created-height: block-height,
          executed: false,
          execution-height: u0,
          cancelled: false,
          cancellation-height: u0,
          active: true,
          metadata: metadata
        })
        
        ;; Update user timelocks
        (let ((user_info (get-user-timelocks tx-sender)))
          (if (is-some user_info)
              (begin
                (let ((user-timelocks (unwrap-optional user_info)))
                  (map-set user-timelocks { user: tx-sender } {
                    active-timelocks: (+ (get user-timelocks active-timelocks) u1),
                    total-timelocks: (+ (get user-timelocks total-timelocks) u1),
                    last-timelock: block-height,
                    favorite-targets: (get user-timelocks favorite-targets)
                  })
                )
              )
              ;; Create new user timelocks record
              (map-set user-timelocks { user: tx-sender } {
                active-timelocks: u1,
                total-timelocks: u1,
                last-timelock: block-height,
                favorite-targets: (list { contract: target-contract, function: target-function })
              })
          )
        )
        
        ;; Update target contract statistics
        (let ((contract_stats (get-timelock-statistics target-contract)))
          (if (is-some contract_stats)
              (begin
                (let ((stats (unwrap-optional contract_stats)))
                  (map-set timelock-statistics { target-contract: target-contract } {
                    total-timelocks: (+ (get stats total-timelocks) u1),
                    successful-executions: (get stats successful-executions),
                    failed-executions: (get stats failed-executions),
                    average-duration: duration,
                    last-execution: (get stats last-execution)
                  })
                )
              )
              ;; Create new statistics record
              (map-set timelock-statistics { target-contract: target-contract } {
                total-timelocks: u1,
                successful-executions: u0,
                failed-executions: u0,
                average-duration: duration,
                last-execution: u0
              })
          )
        )
        
        ;; Update global counters
        (var-set total-timelocks (+ (var-get total-timelocks) u1))
        (var-set active-timelocks (+ (var-get active-timelocks) u1))
        
        ;; Emit event
        (emit-event (timelock-created timelock-id tx-sender target-contract unlock-height))
        
        (ok {
          timelock-id: timelock-id,
          unlock-height: unlock-height,
          created-height: block-height,
          duration: duration
        })
      )
    )
  )
)

(define-public (execute-timelock (timelock-id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check if timelock exists
    (let ((timelock_info (get-timelock timelock-id)))
      (asserts! (is-some timelock_info) ERR_TIMELOCK_NOT_FOUND)
      
      (let ((timelock (unwrap-optional timelock_info)))
        ;; Check if timelock is active and not executed
        (asserts! (get timelock active) ERR_TIMELOCK_NOT_ACTIVE)
        (asserts! (not (get timelock executed)) ERR_TIMELOCK_ALREADY_EXISTS)
        (asserts! (not (get timelock cancelled)) ERR_TIMELOCK_NOT_ACTIVE)
        
        ;; Check if unlock height has been reached
        (asserts! (>= block-height (get timelock unlock-height)) ERR_TIMELOCK_NOT_EXPIRED)
        
        ;; Generate execution ID
        (let ((execution-id (hash160 (concat timelock-id (principal-to-buff? tx-sender)))))
          
          ;; Execute timelock (simplified - would call target contract)
          (let ((execution_result (execute-target-function timelock)))
            (match execution_result
              success
                (begin
                  ;; Update timelock state
                  (map-set timelocks { timelock-id: timelock-id } {
                    creator: (get timelock creator),
                    target-contract: (get timelock target-contract),
                    target-function: (get timelock target-function),
                    parameters: (get timelock parameters),
                    unlock-height: (get timelock unlock-height),
                    created-height: (get timelock created-height),
                    executed: true,
                    execution-height: block-height,
                    cancelled: (get timelock cancelled),
                    cancellation-height: (get timelock cancellation-height),
                    active: false,
                    metadata: (get timelock metadata)
                  })
                  
                  ;; Create execution record
                  (map-set timelock-executions { execution-id: execution-id } {
                    timelock-id: timelock-id,
                    executor: tx-sender,
                    execution-height: block-height,
                    result: (some (get success result)),
                    success: true,
                    gas-used: (get success gas-used)
                  })
                  
                  ;; Update user timelocks
                  (let ((user_info (get-user-timelocks (get timelock creator))))
                    (if (is-some user_info)
                        (begin
                          (let ((user-timelocks (unwrap-optional user_info)))
                            (map-set user-timelocks { user: (get timelock creator) } {
                              active-timelocks: (- (get user-timelocks active-timelocks) u1),
                              total-timelocks: (get user-timelocks total-timelocks),
                              last-timelock: block-height,
                              favorite-targets: (get user-timelocks favorite-targets)
                            })
                          )
                        )
                        true
                    )
                  )
                  
                  ;; Update target contract statistics
                  (let ((contract_stats (get-timelock-statistics (get timelock target-contract))))
                    (if (is-some contract_stats)
                        (begin
                          (let ((stats (unwrap-optional contract_stats))
                                (total-executions (+ (get stats successful-executions) (get stats failed-executions))))
                            
                            (map-set timelock-statistics { target-contract: (get timelock target-contract) } {
                              total-timelocks: (get stats total-timelocks),
                              successful-executions: (+ (get stats successful-executions) u1),
                              failed-executions: (get stats failed-executions),
                              average-duration: (/ (+ (* (get stats average-duration) (- total-executions (get stats successful-executions))) (- block-height (get timelock created-height))) total-executions),
                              last-execution: block-height
                            })
                          )
                        )
                        true
                    )
                  )
                  
                  ;; Update global counters
                  (var-set active-timelocks (- (var-get active-timelocks) u1))
                  
                  ;; Emit event
                  (emit-event (timelock-executed timelock-id tx-sender true))
                  
                  (ok {
                    timelock-id: timelock-id,
                    execution-id: execution-id,
                    result: (get success result),
                    gas-used: (get success gas-used)
                  })
                )
              error
                (begin
                  ;; Create failed execution record
                  (map-set timelock-executions { execution-id: execution-id } {
                    timelock-id: timelock-id,
                    executor: tx-sender,
                    execution-height: block-height,
                    result: (some (unwrap-panic error)),
                    success: false,
                    gas-used: u0
                  })
                  
                  ;; Update target contract statistics
                  (let ((contract_stats (get-timelock-statistics (get timelock target-contract))))
                    (if (is-some contract_stats)
                        (begin
                          (let ((stats (unwrap-optional contract_stats))
                                (total-executions (+ (get stats successful-executions) (get stats failed-executions))))
                            
                            (map-set timelock-statistics { target-contract: (get timelock target-contract) } {
                              total-timelocks: (get stats total-timelocks),
                              successful-executions: (get stats successful-executions),
                              failed-executions: (+ (get stats failed-executions) u1),
                              average-duration: (/ (+ (* (get stats average-duration) (- total-executions (get stats successful-executions))) (- block-height (get timelock created-height))) total-executions),
                              last-execution: block-height
                            })
                          )
                        )
                        true
                    )
                  )
                  
                  ;; Emit event
                  (emit-event (timelock-executed timelock-id tx-sender false))
                  
                  error
                )
            )
          )
        )
      )
    )
  )
)

(define-public (cancel-timelock (timelock-id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check if timelock exists
    (let ((timelock_info (get-timelock timelock-id)))
      (asserts! (is-some timelock_info) ERR_TIMELOCK_NOT_FOUND)
      
      (let ((timelock (unwrap-optional timelock_info)))
        ;; Check if timelock is active and not executed
        (asserts! (get timelock active) ERR_TIMELOCK_NOT_ACTIVE)
        (asserts! (not (get timelock executed)) ERR_TIMELOCK_ALREADY_EXISTS)
        (asserts! (not (get timelock cancelled)) ERR_TIMELOCK_NOT_ACTIVE)
        
        ;; Check permissions (only creator or admin can cancel)
        (asserts! (or (is-eq tx-sender (get timelock creator)) (is-eq tx-sender (contract-call? .conxian-protocol get-admin))) ERR_INSUFFICIENT_PERMISSIONS)
        
        ;; Cancel timelock
        (map-set timelocks { timelock-id: timelock-id } {
          creator: (get timelock creator),
          target-contract: (get timelock target-contract),
          target-function: (get timelock target-function),
          parameters: (get timelock parameters),
          unlock-height: (get timelock unlock-height),
          created-height: (get timelock created-height),
          executed: (get timelock executed),
          execution-height: (get timelock execution-height),
          cancelled: true,
          cancellation-height: block-height,
          active: false,
          metadata: (get timelock metadata)
        })
        
        ;; Update user timelocks
        (let ((user_info (get-user-timelocks (get timelock creator))))
          (if (is-some user_info)
              (begin
                (let ((user-timelocks (unwrap-optional user_info)))
                  (map-set user-timelocks { user: (get timelock creator) } {
                    active-timelocks: (- (get user-timelocks active-timelocks) u1),
                    total-timelocks: (get user-timelocks total-timelocks),
                    last-timelock: block-height,
                    favorite-targets: (get user-timelocks favorite-targets)
                  })
                )
              )
              true
          )
        )
        
        ;; Update global counters
        (var-set active-timelocks (- (var-get active-timelocks) u1))
        
        ;; Emit event
        (emit-event (timelock-cancelled timelock-id tx-sender))
        
        (ok true)
      )
    )
  )
)

(define-public (activate-timelock (timelock-id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check if timelock exists
    (let ((timelock_info (get-timelock timelock-id)))
      (asserts! (is-some timelock_info) ERR_TIMELOCK_NOT_FOUND)
      
      (let ((timelock (unwrap-optional timelock_info)))
        ;; Check if timelock is inactive
        (asserts! (not (get timelock active)) ERR_TIMELOCK_NOT_ACTIVE)
        
        ;; Activate timelock
        (map-set timelocks { timelock-id: timelock-id } {
          creator: (get timelock creator),
          target-contract: (get timelock target-contract),
          target-function: (get timelock target-function),
          parameters: (get timelock parameters),
          unlock-height: (get timelock unlock-height),
          created-height: (get timelock created-height),
          executed: (get timelock executed),
          execution-height: (get timelock execution-height),
          cancelled: (get timelock cancelled),
          cancellation-height: (get timelock cancellation-height),
          active: true,
          metadata: (get timelock metadata)
        })
        
        ;; Update global counters
        (var-set active-timelocks (+ (var-get active-timelocks) u1))
        
        ;; Emit event
        (emit-event (timelock-activated timelock-id))
        
        (ok true)
      )
    )
  )
)

(define-public (deactivate-timelock (timelock-id (buff 32)))
  (begin
    ;; Validate inputs
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check if timelock exists
    (let ((timelock_info (get-timelock timelock-id)))
      (asserts! (is-some timelock_info) ERR_TIMELOCK_NOT_FOUND)
      
      (let ((timelock (unwrap-optional timelock)))
        ;; Check if timelock is active
        (asserts! (get timelock active) ERR_TIMELOCK_NOT_ACTIVE)
        
        ;; Deactivate timelock
        (map-set timelocks { timelock-id: timelock-id } {
          creator: (get timelock creator),
          target-contract: (get timelock target-contract),
          target-function: (get timelock target-function),
          parameters: (get timelock parameters),
          unlock-height: (get timelock unlock-height),
          created-height: (get timelock created-height),
          executed: (get timelock executed),
          execution-height: (get timelock execution-height),
          cancelled: (get timelock cancelled),
          cancellation-height: (get timelock cancellation-height),
          active: false,
          metadata: (get timelock metadata)
        })
        
        ;; Update global counters
        (var-set active-timelocks (- (var-get active-timelocks) u1))
        
        ;; Emit event
        (emit-event (timelock-deactivated timelock-id))
        
        (ok true)
      )
    )
  )
)

(define-public (check-expired-timelocks)
  (begin
    ;; Validate inputs
    (asserts! (var-get timelock-active) ERR_TIMELOCK_NOT_ACTIVE)
    
    ;; Check all active timelocks for expiration
    (let ((expired-count u0))
      ;; This would iterate through all active timelocks
      ;; Simplified implementation
      
      ;; Update last cleanup time
      (var-set last-cleanup block-height)
      
      (ok expired-count)
    )
  )
)

(define-public (set-timelock-active (active bool))
  (begin
    ;; Only admin can set timelock status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INSUFFICIENT_PERMISSIONS)
    
    (var-set timelock-active active)
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { active-timelocks: uint, total-timelocks: uint, last-timelock: uint, favorite-targets: (list 10 { contract: principal, function: (string-ascii 64) }) } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (execute-target-function (timelock { creator: principal, target-contract: principal, target-function: (string-ascii 64), parameters: (list 5 { key: (string-ascii 32), value: (string-ascii 128) }), unlock-height: uint, created-height: uint, executed: bool, execution-height: uint, cancelled: bool, cancellation-height: uint, active: bool, metadata: (string-ascii 256) }))
  (begin
    ;; Execute target function (simplified implementation)
    ;; In practice, would use contract-call? to call the target function
    
    (ok {
      result: (concat "Executed " (get timelock target-function) " with parameters"),
      gas-used: u200000
    })
  )
)

;; Utility functions

(define-read-only (get-timelock-status)
  {
    active: (var-get timelock-active),
    total-timelocks: (var-get total-timelocks),
    active-timelocks: (var-get active-timelocks),
    last-cleanup: (var-get last-cleanup)
  }
)

(define-read-only (get-timelock-summary (timelock-id (buff 32)))
  (match (get-timelock timelock-id)
    timelock
      (ok {
        timelock-id: timelock-id,
        creator: (get timelock creator),
        target-contract: (get timelock target-contract),
        target-function: (get timelock target-function),
        unlock-height: (get timelock unlock-height),
        created-height: (get timelock created-height),
        executed: (get timelock executed),
        cancelled: (get timelock cancelled),
        active: (get timelock active),
        remaining-blocks: (if (get timelock active) (- (get timelock unlock-height) block-height) u0)
      })
    none (err ERR_TIMELOCK_NOT_FOUND)
  )
)

(define-read-only (get-user-timelock-summary (user principal))
  (match (get-user-timelocks user)
    user-timelocks
      (ok {
        user: user,
        active-timelocks: (get user-timelocks active-timelocks),
        total-timelocks: (get user-timelocks total-timelocks),
        last-timelock: (get user-timelocks last-timelock),
        favorite-targets: (get user-timelocks favorite-targets)
      })
    none (ok { user: user, active-timelocks: u0, total-timelocks: u0, last-timelock: u0, favorite-targets: (list 0 { contract: principal, function: (string-ascii 64) }) })
  )
)

(define-read-only (get-contract-timelock-summary (target-contract principal))
  (match (get-timelock-statistics target-contract)
    stats
      (ok {
        target-contract: target-contract,
        total-timelocks: (get stats total-timelocks),
        successful-executions: (get stats successful-executions),
        failed-executions: (get stats failed-executions),
        average-duration: (get stats average-duration),
        last-execution: (get stats last-execution),
        success-rate: (if (> (get stats total-timelocks) u0)
                        (/ (* (get stats successful-executions) u10000) (get stats total-timelocks))
                        u0)
      })
    none (ok { target-contract: target-contract, total-timelocks: u0, successful-executions: u0, failed-executions: u0, average-duration: u0, last-execution: u0, success-rate: u0 })
  )
)
