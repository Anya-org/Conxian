;; Minimal Stable Pool (clean) stub for compilation safety
;; TODO: Implement full stable pool logic later

(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)

(define-public (initialize (token-x principal) (token-y principal))
	(begin
		(asserts! (not (var-get initialized)) (err u100))
		(var-set initialized true)
		(ok true)))

(define-read-only (is-initialized)
	(var-get initialized))

