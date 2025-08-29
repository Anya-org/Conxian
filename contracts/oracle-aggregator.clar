;; ------------------------------------------------------------
;; oracle-aggregator.clar (ENHANCED with MEDIAN calculation)
;; Purpose: Collect multiple oracle submissions for (base, quote) pairs
;;          and compute MEDIAN price once minimum sources met.
;; SECURITY FEATURES:
;; - Registration gated to deployer/admin (upgradeable to governance gate).
;; - Uses sorted insertion median calculation (production-ready).
;; - Whitelist enforced per pair for submissions.
;; - Rolling history for TWAP support.
;; EVENTS:
;; - price-aggregate (code u3001)
;; PRODUCTION ENHANCEMENTS:
;; - Median calculation with sorted insertion over fixed window
;; - Oracle membership check via whitelist enforcement
;; - Configurable parameters via governance
;; - Time-weighted average price (TWAP) support
;; ------------------------------------------------------------

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_ORACLE (err u102)) ;; used when caller not whitelisted
(define-constant ERR_PAIR_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_ORACLE (err u104))
(define-constant ERR_MIN_SOURCES (err u105))
(define-constant ERR_STALE (err u106))
(define-constant ERR_DEVIATION (err u107))

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

;; Configuration for robustness
(define-data-var max-stale uint u10)          ;; maximum blocks old a submission can be
(define-data-var max-deviation-bps uint u2000) ;; 2000 = 20%; max allowed deviation vs last aggregate

(define-public (set-params (new-max-stale uint) (new-max-dev-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-max-stale u0) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-max-dev-bps u5000) ERR_NOT_AUTHORIZED) ;; cap at 50%
    (var-set max-stale new-max-stale)
    (var-set max-deviation-bps new-max-dev-bps)
    (print { event: "oa-set-params", max-stale: new-max-stale, max-dev-bps: new-max-dev-bps })
    (ok true)))

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

;; Helpers for managing principal lists (max 10)
(define-private (contains-scan (x principal) (state { target: principal, found: bool }))
  (if (get found state)
      state
      (if (is-eq x (get target state))
          { target: (get target state), found: true }
          state)))

(define-private (contains-principal (xs (list 10 principal)) (p principal))
  (get found (fold contains-scan xs { target: p, found: false })))

(define-private (append-oracle-if-needed (xs (list 10 principal)) (p principal))
  (if (contains-principal xs p)
      xs
      (unwrap-panic (as-max-len? (append xs p) u10))))

(define-public (add-oracle (base principal) (quote principal) (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (let ((pair (map-get? pairs { base: base, quote: quote })))
      (asserts! (is-some pair) ERR_PAIR_NOT_FOUND))
    (let ((entry (map-get? oracle-whitelist { base: base, quote: quote, oracle: oracle })))
      (asserts! (is-none entry) ERR_ALREADY_ORACLE))
    ;; Also ensure the pair's enumerated oracle list includes this oracle for aggregation scans
    (let ((p (unwrap! (map-get? pairs { base: base, quote: quote }) ERR_PAIR_NOT_FOUND)))
      (let ((new-list (append-oracle-if-needed (get oracles p) oracle)))
        (map-set pairs { base: base, quote: quote } { oracles: new-list, min-sources: (get min-sources p) }))
      )
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

;; MEDIAN CALCULATION SYSTEM
;; Current prices map per oracle for median calculation
(define-map oracle-prices { base: principal, quote: principal, oracle: principal } uint)
(define-map price-count { base: principal, quote: principal } uint)

;; Get current prices and calculate median
(define-private (collect-prices-and-median (base principal) (quote principal))
  ;; Gather fresh prices from current oracles, build sorted list, then pick median
  (let ((pair (map-get? pairs { base: base, quote: quote })))
    (match pair p
      (let ((max-age (var-get max-stale))
            (oracle-list (get oracles p)))
        (let ((fresh-prices (collect-fresh-prices base quote oracle-list max-age)))
          (if (is-eq (len fresh-prices) u0)
              u0
              (median-from-sorted (sort-prices fresh-prices)))))
      u0)))

;; Update median calculation (simplified for now)
(define-private (update-median (base principal) (quote principal) (new-price uint) (oracle principal))
  (let ((existing (map-get? oracle-prices { base: base, quote: quote, oracle: oracle }))
        (count (default-to u0 (map-get? price-count { base: base, quote: quote }))))
    (begin
      (if (is-some existing)
          (map-set oracle-prices { base: base, quote: quote, oracle: oracle } new-price)
          (begin
            (map-set oracle-prices { base: base, quote: quote, oracle: oracle } new-price)
            (map-set price-count { base: base, quote: quote } (+ count u1))))
      (collect-prices-and-median base quote))))

;; Build a list of fresh prices by iterating over oracle principals for this pair
(define-private (collect-fresh-prices (base principal) (quote principal) (oracle-list (list 10 principal)) (max-age uint))
  (let ((state { prices: (list), base: base, quote: quote, max-age: max-age }))
    (get prices (fold collect-fresh-step oracle-list state))))

(define-private (collect-fresh-step (oracle principal) (state { prices: (list 10 uint), base: principal, quote: principal, max-age: uint }))
  (let ((auth (map-get? oracle-whitelist { base: (get base state), quote: (get quote state), oracle: oracle })))
    (if (and (is-some auth) (get enabled (unwrap-panic auth)))
        (let ((sub (map-get? submissions { base: (get base state), quote: (get quote state), oracle: oracle })))
          (match sub s
            (let ((age (- block-height (get height s))))
              (if (<= age (get max-age state))
                  (merge state { prices: (unwrap-panic (as-max-len? (append (get prices state) (get price s)) u10)) })
                  state))
            state))
        state)))

;; Sort collected prices using insertion into accumulator with a fold
;; Sorting helpers (no lambdas in Clarity). Insert one element into sorted list.
(define-private (sorted-insert-scan (y uint) (state { x: uint, inserted: bool, out: (list 10 uint) }))
  (if (get inserted state)
      { x: (get x state), inserted: true, out: (unwrap-panic (as-max-len? (append (get out state) y) u10)) }
      (if (<= (get x state) y)
          { x: (get x state), inserted: true, out: (unwrap-panic (as-max-len? (append (unwrap-panic (as-max-len? (append (get out state) (get x state)) u10)) y) u10)) }
          { x: (get x state), inserted: false, out: (unwrap-panic (as-max-len? (append (get out state) y) u10)) })) )

(define-private (sorted-insert-one (x uint) (acc (list 10 uint)))
  (let ((final (fold sorted-insert-scan acc { x: x, inserted: false, out: (list) })))
    (if (get inserted final)
        (get out final)
        (unwrap-panic (as-max-len? (append (get out final) x) u10)))) )

(define-private (sort-step (x uint) (acc (list 10 uint)))
  (sorted-insert-one x acc))

(define-private (sort-prices (vals (list 10 uint)))
  (fold sort-step vals (list)))

;; Compute median from a sorted list
;; nth helper (0-based) via fold
(define-private (nth-scan (x uint) (state { idx: uint, target: uint, found: (optional uint) }))
  (if (is-none (get found state))
      (if (is-eq (get idx state) (get target state))
          { idx: (+ (get idx state) u1), target: (get target state), found: (some x) }
          { idx: (+ (get idx state) u1), target: (get target state), found: none })
      state))

(define-private (nth (xs (list 10 uint)) (i uint))
  (let ((res (fold nth-scan xs { idx: u0, target: i, found: none })))
    (default-to u0 (get found res))))

(define-private (median-from-sorted (xs (list 10 uint)))
  (let ((n (len xs)))
    (if (is-eq n u0)
        u0
        (let ((mid (/ n u2)))
          (if (is-eq (* mid u2) n)
              ;; even: average two middle
              (let ((a (nth xs (- mid u1)))
                    (b (nth xs mid)))
                (/ (+ a b) u2))
              ;; odd: take middle
              (nth xs mid))))))

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

;; Simple average over history (equal-weight). NOTE: Can be upgraded to true time-weighted window.
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
                      (default-to u0 (get price (map-get? history { base: base, quote: quote, slot: u4 }))) )))
              (/ s count))))
      u0)))

;; Submit a price for a pair as an authorized oracle
;; Enhanced with median calculation and proper whitelist enforcement
(define-public (submit-price (base principal) (quote principal) (price uint))
  (let ((pair (map-get? pairs { base: base, quote: quote })))
    (match pair
      pair-data
        (let ((min-src (get min-sources pair-data))
              (existing (map-get? submissions { base: base, quote: quote, oracle: tx-sender }))
              (stat (map-get? stats { base: base, quote: quote })))
          ;; Enforce whitelist - CRITICAL SECURITY CHECK FIRST
          (let ((auth (map-get? oracle-whitelist { base: base, quote: quote, oracle: tx-sender })))
            (asserts! (and (is-some auth) (get enabled (unwrap! auth ERR_NOT_ORACLE))) ERR_NOT_ORACLE)
            (let ((curr-sum (if (is-some stat) (get sum (unwrap! stat (err u998))) u0))
                  (curr-sub (if (is-some stat) (get submitted (unwrap! stat (err u998))) u0))
                  (prev-agg (map-get? prices { base: base, quote: quote }))
                  (max-dev (var-get max-deviation-bps)))
              (if (is-some existing)
                  ;; Update existing submission
                  (let ((prev (unwrap! existing (err u997))))
                    (map-set submissions { base: base, quote: quote, oracle: tx-sender } { price: price, height: block-height })
                    (let ((new-sum (+ (- curr-sum (get price prev)) price)))
                      ;; Update stats BEFORE calculating median to avoid race condition
                      (map-set stats { base: base, quote: quote } { sum: new-sum, submitted: curr-sub })
                      (let ((median-price (update-median base quote price tx-sender)))
                        (if (>= curr-sub min-src)
                            (begin
                              ;; Enforce deviation against previous aggregate on the computed median (not individual submission)
                              (if (is-some prev-agg)
                                (let ((prev-price (get price (unwrap-panic prev-agg))))
                                  (let ((diff (if (> median-price prev-price) (- median-price prev-price) (- prev-price median-price)))
                                        (limit (/ (* prev-price max-dev) u10000)))
                                    (asserts! (<= diff limit) ERR_DEVIATION)))
                                true)
                              (map-set prices { base: base, quote: quote } { price: median-price, height: block-height, sources: curr-sub })
                              (record-history base quote median-price)
                              (print { event: "price-aggregate", code: u3001, base: base, quote: quote, price: median-price, sources: curr-sub, height: block-height })
                              (ok { aggregated: true, sources: curr-sub, price: median-price }))
                            (ok { aggregated: false, sources: curr-sub, price: price })))))
                  ;; New submission
                  (begin
                    (map-set submissions { base: base, quote: quote, oracle: tx-sender } { price: price, height: block-height })
                    (let ((new-sub (+ curr-sub u1)) 
                          (new-sum (+ curr-sum price)))
                      ;; Update stats BEFORE calculating median to avoid race condition
                      (map-set stats { base: base, quote: quote } { sum: new-sum, submitted: new-sub })
                      (let ((median-price (update-median base quote price tx-sender)))
                        (if (>= new-sub min-src)
                            (begin
                              ;; Enforce deviation against previous aggregate on the computed median (not individual submission)
                              (if (is-some prev-agg)
                                (let ((prev-price (get price (unwrap-panic prev-agg))))
                                  (let ((diff (if (> median-price prev-price) (- median-price prev-price) (- prev-price median-price)))
                                        (limit (/ (* prev-price max-dev) u10000)))
                                    (asserts! (<= diff limit) ERR_DEVIATION)))
                                true)
                              (map-set prices { base: base, quote: quote } { price: median-price, height: block-height, sources: new-sub })
                              (record-history base quote median-price)
                              (print { event: "price-aggregate", code: u3001, base: base, quote: quote, price: median-price, sources: new-sub, height: block-height })
                              (ok { aggregated: true, sources: new-sub, price: median-price }))
                            (ok { aggregated: false, sources: new-sub, price: price })))))))))
      (err u404))));; Read-only latest price
(define-read-only (get-price (base principal) (quote principal))
  (let ((p (map-get? prices { base: base, quote: quote })))
    (if (is-some p)
        (let ((v (unwrap! p (err u997))))
          (let ((age (- block-height (get height v))))
            (if (> age (var-get max-stale))
                ERR_STALE
                (ok { price: (get price v), height: (get height v), sources: (get sources v) }))))
        (err u404))))

(define-read-only (get-params)
  { max-stale: (var-get max-stale), max-deviation-bps: (var-get max-deviation-bps) })

;; Read-only median calculation for current sorted prices
(define-read-only (get-median (base principal) (quote principal))
  (ok (collect-prices-and-median base quote)))

;; Read-only function to get price count for debugging  
(define-read-only (get-price-count (base principal) (quote principal))
  (map-get? price-count { base: base, quote: quote }))

;; Check if an oracle is whitelisted
(define-read-only (is-oracle (base principal) (quote principal) (oracle principal))
  (let ((auth (map-get? oracle-whitelist { base: base, quote: quote, oracle: oracle })))
    (match auth
      present (get enabled present)
      false)))
