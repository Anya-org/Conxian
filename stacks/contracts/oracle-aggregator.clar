;; ------------------------------------------------------------
;; oracle-aggregator.clar (Scaffold / BETA)
;; Purpose: Collect multiple oracle submissions for (base, quote) pairs
;;          and compute a simple average price once minimum sources met.
;; SECURITY (scaffold):
;; - Registration gated to deployer for now (replace with governance gate).
;; - Uses average (not median) – upgrade to median/TWAP before production reliance.
;; EVENTS:
;; - price-aggregate (code u3001)
;; ------------------------------------------------------------

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_ORACLE (err u102))

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

;; Helper: check caller authorized (deployer placeholder)
(define-read-only (is-authorized (sender principal))
  (ok (is-eq sender DEPLOYER)))

;; Register a pair with initial oracle list & min sources
(define-public (register-pair (base principal) (quote principal) (oracles (list 10 principal)) (min-sources uint))
  (begin
    (match (is-authorized tx-sender)
      authorized (asserts! authorized ERR_NOT_AUTHORIZED))
    (asserts! (> (len oracles) u0) ERR_NOT_ORACLE)
    (asserts! (<= min-sources (len oracles)) ERR_NOT_ORACLE)
    (let ((existing (map-get? pairs { base: base, quote: quote })))
      (asserts! (is-none existing) ERR_ALREADY_REGISTERED))
    (map-set pairs { base: base, quote: quote } { oracles: oracles, min-sources: min-sources })
    (ok true)))

;; Utility: check membership
(define-read-only (contains? (items (list 10 principal)) (target principal))
  (if (is-eq (len items) u0)
      false
      (let ((head (unwrap! (element-at items u0) false))
            (tail (slice items u1 (len items))))
        (if (is-eq head target) true (contains? tail target)))))

;; Private recursive accumulator for average calculation
(define-private (accumulate (base principal) (quote principal) (oracle-list (list 10 principal)) (sum uint) (count uint))
  (if (is-eq (len oracle-list) u0)
      (ok (tuple (sum sum) (count count)))
      (let ((head (unwrap! (element-at oracle-list u0) ERR_NOT_ORACLE))
            (tail (slice oracle-list u1 (len oracle-list))))
        (let ((sub (map-get? submissions { base: base, quote: quote, oracle: head })))
          (if (is-some sub)
              (let ((val (unwrap! sub (err u999))))
                (accumulate base quote tail (+ sum (get price val)) (+ count u1)))
              (accumulate base quote tail sum count))))))

;; Submit a price for a pair as an authorized oracle
(define-public (submit-price (base principal) (quote principal) (price uint))
  (let ((pair (map-get? pairs { base: base, quote: quote })))
    (match pair
      pair-data
        (let ((oracle-list (get oracles pair-data))
              (min-src (get min-sources pair-data)))
          (asserts! (is-eq true (contains? oracle-list tx-sender)) ERR_NOT_ORACLE)
          (map-set submissions { base: base, quote: quote, oracle: tx-sender } { price: price, height: block-height })
          (let ((agg (unwrap! (accumulate base quote oracle-list u0 u0) (err u998))))
            (let ((src (get count agg)))
              (if (>= src min-src)
                  (let ((avg (/ (get sum agg) src)))
                    (map-set prices { base: base, quote: quote } { price: avg, height: block-height, sources: src })
                    (print { event: "price-aggregate", code: u3001, base: base, quote: quote, price: avg, sources: src, height: block-height })
                    (ok { aggregated: true, sources: src, price: avg }))
                  (ok { aggregated: false, sources: src, price: u0 }))))
      (err u404))))

;; Read-only latest price
(define-read-only (get-price (base principal) (quote principal))
  (let ((p (map-get? prices { base: base, quote: quote })))
    (if (is-some p)
        (let ((v (unwrap! p (err u997))))
          (ok { price: (get price v), height: (get height v), sources: (get sources v) }))
        (err u404))))
