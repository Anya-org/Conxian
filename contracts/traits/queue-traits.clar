;; queue-traits.clar
;; Standard Queue Traits

(define-trait queue-trait (
  (enqueue
    (principal uint)
    (response bool uint)
  )
  (dequeue
    ()
    (
      response       (optional {
      user: principal,
      amount: uint
    })
      uint
    )
  )
  (get-length
    ()
    (response uint uint)
  )
))
