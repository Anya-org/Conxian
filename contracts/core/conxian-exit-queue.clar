;; conxian-exit-queue.clar
;; Implements the Exit Queue for the Conxian Protocol
;; Adheres to queue-traits.clar

(impl-trait .queue-traits.queue-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_QUEUE_EMPTY u1001)
(define-constant ERR_QUEUE_FULL u1002)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var head uint u0)
(define-data-var tail uint u0)

;; Maps
(define-map exit-queue
  uint
  {
    user: principal,
    amount: uint
  }
)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Trait Implementation

;; @desc Enqueues a user exit request
;; @param user principal
;; @param amount uint
;; @returns (response bool uint)
(define-public (enqueue (user principal) (amount uint))
  (let ((current-tail (var-get tail)))
    (begin
      ;; Access control: Only allow approved contracts (placeholder for now effectively public or restricted)
      ;; In production this should check a whitelist from conxian-protocol
      (map-set exit-queue current-tail { user: user, amount: amount })
      (var-set tail (+ current-tail u1))
      (ok true)
    )
  )
)

;; @desc Dequeues the next request
;; @returns (response (optional {user amount}) uint)
(define-public (dequeue)
  (let (
      (current-head (var-get head))
      (current-tail (var-get tail))
    )
    (begin
      (asserts! (is-owner) (err ERR_UNAUTHORIZED))

      (if (is-eq current-head current-tail)
        (ok none) ;; Queue is empty
        (let ((request (map-get? exit-queue current-head)))
           (map-delete exit-queue current-head)
           (var-set head (+ current-head u1))
           (ok request)
        )
      )
    )
  )
)

;; @desc Gets the current length of the queue
;; @returns (response uint uint)
(define-public (get-length)
  (ok (- (var-get tail) (var-get head)))
)
