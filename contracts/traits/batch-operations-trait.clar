;; batch-operations-trait.clar
(define-trait batch-operations-trait
  (
    (batch-pause-contracts ((list 20 principal)) (response bool uint))
    (batch-unpause-contracts ((list 20 principal)) (response bool uint))
    (batch-set-roles ((list 20 principal) (list 20 uint) (list 20 bool)) (response bool uint))
  )
)
