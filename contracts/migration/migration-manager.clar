;; migration-manager.clar
;; Manages data migration from legacy contracts to the enhanced system

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_MIGRATION_IN_PROGRESS (err u6001))
(define-constant ERR_MIGRATION_NOT_STARTED (err u6002))

(define-data-var migration-status (string-ascii 20) "NOT_STARTED")

(define-public (start-migration)
    (begin
        (asserts! (is-eq (var-get migration-status) "NOT_STARTED") ERR_MIGRATION_IN_PROGRESS)
        (var-set migration-status "IN_PROGRESS")
        (ok true)
    )
)

(define-public (complete-migration)
    (begin
        (asserts! (is-eq (var-get migration-status) "IN_PROGRESS") ERR_MIGRATION_NOT_STARTED)
        (var-set migration-status "COMPLETED")
        (ok true)
    )
)

(define-read-only (get-migration-status)
    (ok (var-get migration-status))
)
