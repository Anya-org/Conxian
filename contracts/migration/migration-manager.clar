;; migration-manager.clar
;; Manages data migration from legacy contracts to the enhanced system

(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_MIGRATION_IN_PROGRESS u6001)
(define-constant ERR_MIGRATION_NOT_STARTED u6002)

(define-data-var migration-status (string-ascii 20) "NOT_STARTED")

(define-public (start-migration)
    (begin
        (asserts! (is-eq (var-get migration-status) "NOT_STARTED") (err ERR_MIGRATION_IN_PROGRESS))
        (var-set migration-status "IN_PROGRESS")
        (ok true)
    )
)

(define-public (complete-migration)
    (begin
        (asserts! (is-eq (var-get migration-status) "IN_PROGRESS") (err ERR_MIGRATION_NOT_STARTED))
        (var-set migration-status "COMPLETED")
        (ok true)
    )
)

(define-read-only (get-migration-status)
    (ok (var-get migration-status))
)
