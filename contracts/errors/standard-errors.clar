;; standard-errors.clar
;; Unified error codes for Conxian Protocol

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_OWNER (err u1001))
(define-constant ERR_INVALID_PRINCIPAL (err u1002))
(define-constant ERR_ACCESS_DENIED (err u1003))

(define-constant ERR_INSUFFICIENT_BALANCE (err u2000))
(define-constant ERR_INVALID_AMOUNT (err u2001))
(define-constant ERR_TRANSFER_FAILED (err u2002))

(define-constant ERR_NOT_FOUND (err u3000))
(define-constant ERR_ALREADY_EXISTS (err u3001))
(define-constant ERR_INVALID_STATE (err u3002))

(define-constant ERR_MATH_OVERFLOW (err u4000))
(define-constant ERR_MATH_UNDERFLOW (err u4001))
(define-constant ERR_DIVISION_BY_ZERO (err u4002))

(define-constant ERR_CONTRACT_PAUSED (err u5000))
(define-constant ERR_CIRCUIT_BREAKER_TRIGGERED (err u5001))
