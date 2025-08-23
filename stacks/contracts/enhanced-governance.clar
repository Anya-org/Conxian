;; Minimal Enhanced Governance stub to make manifest enabling safe.
;; TODO: Replace with full implementation when ready.

(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
	(begin
		(asserts! (is-eq tx-sender (var-get admin)) (err u100))
		(var-set admin new-admin)
		(ok true)))

(define-read-only (get-admin)
	(var-get admin))

