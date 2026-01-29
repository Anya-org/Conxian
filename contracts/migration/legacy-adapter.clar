;; legacy-adapter.clar
;; Provides a backward-compatible interface to legacy contracts during migration

(define-constant ERR_MIGRATION_COMPLETED u7000)

(define-read-only (is-migration-completed)
    (is-eq (unwrap-panic (contract-call? .migration-manager get-migration-status)) "COMPLETED")
)

(define-public (legacy-function)
    (begin
        (asserts! (not (is-migration-completed)) (err ERR_MIGRATION_COMPLETED))
        ;; Call the legacy contract function
        (ok true)
    )
)
