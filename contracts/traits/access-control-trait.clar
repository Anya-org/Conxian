(define-trait access-control-trait
  (
    (is-authorized (principal (buff 32)) (response bool uint))
  )
)
