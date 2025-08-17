;; ------------------------------------------------------------
;; oracle-aggregator.clar (Scaffold / BETA)
;; Purpose: Collect multiple oracle submissions for (base, quote) pairs
;;          and compute a simple average price once minimum sources met.
;; SECURITY (scaffold):
;; - Registration gated to deployer for now (replace with governance gate).
;; - Uses simple average (NOT median/TWAP) - upgrade before production reliance.
;; - NOW: Whitelist enforced per pair for submissions.
;; EVENTS:
;; - price-aggregate (code u3001)
;; ROADMAP HARDENING:
;; - Add oracle membership check (whitelist) via fixed-size tuple or bitmap
;; - Support median + configurable decay-weighted TWAP
;; - Governance-controlled parameter updates
;; ------------------------------------------------------------

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_ORACLE (err u102)) ;; reserved for future ACL use
(define-constant ERR_PAIR_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_ORACLE (err u104))
(define-constant ERR_MIN_SOURCES (err u105))

;; Pair registration: list of oracle principals & min sources required
(define-map pairs { base: principal, quote: principal }
  { oracles: (list 10 principal), min-sources: uint })

;; Individual oracle submissions per pair
(define-map submissions { base: principal, quote: principal, oracle: principal }
  { price: uint, height: uint })

;; Aggregated latest price per pair
(define-map prices { base: principal, quote: principal }
  { price: uint, height: uint, sources: uint })

;; Deployer captured at publish time
(define-constant DEPLOYER tx-sender)

;; Admin (mutable so governance/timelock can assume control)
(define-data-var admin principal DEPLOYER)

;; Helper: check caller authorized (deployer placeholder). In future replace
;; with governance / timelock principal.
(define-read-only (is-authorized (sender principal))
  (ok (is-eq sender DEPLOYER)))

(define-read-only (get-admin)
  (ok (var-get admin)))

(define-public (set-admin (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set admin p)
    (print { event: "oa-set-admin", new: p })
    (ok true)))

;; Register a pair with initial oracle list & min sources
(define-public (register-pair (base principal) (quote principal) (oracles (list 10 principal)) (min-sources uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len oracles) u0) ERR_NOT_ORACLE)
    (asserts! (<= min-sources (len oracles)) ERR_MIN_SOURCES)
    (let ((existing (map-get? pairs { base: base, quote: quote })))
      (asserts! (is-none existing) ERR_ALREADY_REGISTERED))
    (map-set pairs { base: base, quote: quote } { oracles: oracles, min-sources: min-sources })
    (print { event: "oa-register-pair", base: base, quote: quote, min: min-sources, count: (len oracles) })
    (ok true)))

;; Oracle whitelist (explicit) to enforce ACL without list iteration
(define-map oracle-whitelist { base: principal, quote: principal, oracle: principal } { enabled: bool })

(define-public (add-oracle (base principal) (quote principal) (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (let ((pair (map-get? pairs { base: base, quote: quote })))
      (asserts! (is-some pair) ERR_PAIR_NOT_FOUND))
    (let ((entry (map-get? oracle-whitelist { base: base, quote: quote, oracle: oracle })))
      (asserts! (is-none entry) ERR_ALREADY_ORACLE))
    (map-set oracle-whitelist { base: base, quote: quote, oracle: oracle } { enabled: true })
    (print { event: "oa-add-oracle", base: base, quote: quote, oracle: oracle })
    (ok true)))

(define-public (remove-oracle (base principal) (quote principal) (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (map-delete oracle-whitelist { base: base, quote: quote, oracle: oracle })
    (print { event: "oa-remove-oracle", base: base, quote: quote, oracle: oracle })
    (ok true)))

(define-public (set-min-sources (base principal) (quote principal) (min-sources uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (let ((pair (map-get? pairs { base: base, quote: quote })))
      (asserts! (is-some pair) ERR_PAIR_NOT_FOUND)
      (let ((p (unwrap! pair ERR_PAIR_NOT_FOUND)))
        (asserts! (>= min-sources u1) ERR_MIN_SOURCES)
        (map-set pairs { base: base, quote: quote } { oracles: (get oracles p), min-sources: min-sources })
        (print { event: "oa-set-min", base: base, quote: quote, min: min-sources })
        (ok true)))))

;; Incremental aggregation stats per pair (sum + number of distinct submitting
;; sources). This avoids list iteration recursion limitations.
(define-map stats { base: principal, quote: principal } { sum: uint, submitted: uint })

;; Rolling history (for TWAP / future median). Fixed size ring buffer length 5.
(define-constant HISTORY_SIZE u5)
(define-map history { base: principal, quote: principal, slot: uint } { price: uint, height: uint })
(define-map meta { base: principal, quote: principal } { count: uint, next: uint })

(define-private (record-history (base principal) (quote principal) (price uint))
  (let ((m (map-get? meta { base: base, quote: quote })))
    (match m present
      (let ((slot (get next present)) (count (get count present)))
        (map-set history { base: base, quote: quote, slot: slot } { price: price, height: block-height })
        (map-set meta { base: base, quote: quote } { count: (if (< count HISTORY_SIZE) (+ count u1) count), next: (mod (+ slot u1) HISTORY_SIZE) })
        true)
      (begin
        (map-set history { base: base, quote: quote, slot: u0 } { price: price, height: block-height })
        (map-set meta { base: base, quote: quote } { count: u1, next: u1 })
        true))))

(define-read-only (get-twap (base principal) (quote principal))
  (let ((m (map-get? meta { base: base, quote: quote })))
    (match m present
      (let ((count (get count present)))
        (if (is-eq count u0)
            u0
            (let ((s (+
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u0 })))
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u1 })))
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u2 })))
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u3 })))
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u4 }))))) )
              (/ s count))))
      u0)))

;; Submit a price for a pair as an authorized oracle
;; Submit a price (any sender for now - add oracle ACL later). Distinct oracle
;; tracking based on first submission per principal. Subsequent submissions
;; update the sum (replace old price) but not submitted count.
(define-public (submit-price (base principal) (quote principal) (price uint))
  (let ((pair (map-get? pairs { base: base, quote: quote })))
    (match pair
      pair-data
        (let ((min-src (get min-sources pair-data))
              (existing (map-get? submissions { base: base, quote: quote, oracle: tx-sender }))
              (stat (map-get? stats { base: base, quote: quote })))
          ;; Enforce whitelist
          (let ((auth (map-get? oracle-whitelist { base: base, quote: quote, oracle: tx-sender })))
            (asserts! (is-some auth) ERR_NOT_ORACLE))
          (let ((curr-sum (if (is-some stat) (get sum (unwrap! stat (err u998))) u0))
                (curr-sub (if (is-some stat) (get submitted (unwrap! stat (err u998))) u0)))
            (if (is-some existing)
                (let ((prev (unwrap! existing (err u997))))
                  (map-set submissions { base: base, quote: quote, oracle: tx-sender } { price: price, height: block-height })
                  (let ((new-sum (+ (- curr-sum (get price prev)) price)))
                    (map-set stats { base: base, quote: quote } { sum: new-sum, submitted: curr-sub })
                    (if (>= curr-sub min-src)
                        (let ((avg (/ new-sum curr-sub)))
                          (map-set prices { base: base, quote: quote } { price: avg, height: block-height, sources: curr-sub })
                          (record-history base quote avg)
                          (print { event: "price-aggregate", code: u3001, base: base, quote: quote, price: avg, sources: curr-sub, height: block-height })
                          (ok { aggregated: true, sources: curr-sub, price: avg }))
                        (ok { aggregated: false, sources: curr-sub, price: price }))))
                (begin
                  (map-set submissions { base: base, quote: quote, oracle: tx-sender } { price: price, height: block-height })
                  (let ((new-sub (+ curr-sub u1)) (new-sum (+ curr-sum price)))
                    (map-set stats { base: base, quote: quote } { sum: new-sum, submitted: new-sub })
                    (if (>= new-sub min-src)
                        (let ((avg (/ new-sum new-sub)))
                          (map-set prices { base: base, quote: quote } { price: avg, height: block-height, sources: new-sub })
                          (record-history base quote avg)
                          (print { event: "price-aggregate", code: u3001, base: base, quote: quote, price: avg, sources: new-sub, height: block-height })
                          (ok { aggregated: true, sources: new-sub, price: avg }))
                        (ok { aggregated: false, sources: new-sub, price: price })))))))
      (err u404))))

;; Read-only latest price
(define-read-only (get-price (base principal) (quote principal))
  (let ((p (map-get? prices { base: base, quote: quote })))
    (if (is-some p)
        (let ((v (unwrap! p (err u997))))
          (ok { price: (get price v), height: (get height v), sources: (get sources v) }))
        (err u404))))
