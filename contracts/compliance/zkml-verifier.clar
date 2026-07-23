;; zkml-verifier.clar
;; Conxian Protocol: quarantined ZKML verification boundary.
;;
;; This contract is retained for local compilation and negative regression tests
;; only. No reviewed cryptographic verifier backend exists yet, so the public
;; boundary must never turn structural/scaffold input into an acceptance.

(define-constant ERR_VERIFIER_UNAVAILABLE (err u503))
(define-constant ERR_UNAUTHORIZED (err u7002))

(define-data-var admin principal tx-sender)

;; @desc Fail closed until a reviewed cryptographic ZKML backend is available.
;; @param model-id: The identifier for the ML model.
;; @param input-hash: Hash of the input data.
;; @param proof: The reserved ZK proof payload.
;; @return (response bool uint) - Always returns ERR_VERIFIER_UNAVAILABLE.
(define-public (verify-proof (model-id (string-ascii 64)) (input-hash (buff 32)) (proof (buff 1024)))
  ;; Keep the compatible input boundary, but do not inspect or accept any
  ;; payload until the canonical evidence contract has a reviewed backend.
  ERR_VERIFIER_UNAVAILABLE
)

;; Admin functions

;; @desc Update the contract administrator. Admin only.
;; @param new-admin: The new administrator principal.
;; @return (response bool uint) - Returns ok(true) on success.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  ;; Status is an unavailable error rather than a success-shaped readiness
  ;; record. Callers must not treat this scaffold as active ZKML evidence.
  ERR_VERIFIER_UNAVAILABLE
)
