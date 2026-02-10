;; protocol-errors.clar
;; Centralized error definitions for Conxian Protocol

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_PARAMS u1001)
(define-constant ERR_NOT_FOUND u404)

(define-public (get-err (err-code uint))
  (ok err-code)
)
