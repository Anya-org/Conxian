;; utils.clar
;; Conxian Protocol: General utility functions and helpers

;; Constants
(define-constant ERR_INVALID_INPUT (err 38001))
(define-constant ERR_DIVISION_BY_ZERO (err 38002))
(define-constant ERR_OVERFLOW (err 38003))
(define-constant ERR_UNDERFLOW (err 38004))

;; Math utilities
(define-public (safe-divide (a uint) (b uint))
  (begin
    (asserts! (> b u0) ERR_DIVISION_BY_ZERO)
    (/ a b)
  )
)

(define-public (safe-modulo (a uint) (b uint))
  (begin
    (asserts! (> b u0) ERR_DIVISION_BY_ZERO)
    (mod a b)
  )
)

(define-public (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-public (max (a uint) (b uint))
  (if (> a b) a b)
)

(define-public (clamp (value uint) (min-value uint) (max-value uint))
  (max min-value (min value max-value))
)

;; String utilities
(define-public (string-to-uint (str (string-ascii 32)))
  (begin
    ;; Simple string to uint conversion (for numeric strings)
    ;; In practice, would need more sophisticated parsing
    (if (is-eq str "0") u0
        (if (is-eq str "1") u1
            (if (is-eq str "2") u2
                (if (is-eq str "3") u3
                    (if (is-eq str "4") u4
                        (if (is-eq str "5") u5
                            (if (is-eq str "6") u6
                                (if (is-eq str "7") u7
                                    (if (is-eq str "8") u8
                                        (if (is-eq str "9") u9
                                            u0
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
  )
)

(define-public (uint-to-string (value uint))
  (begin
    ;; Simple uint to string conversion (for single digits)
    (if (is-eq value u0) "0"
        (if (is-eq value u1) "1"
            (if (is-eq value u2) "2"
                (if (is-eq value u3) "3"
                    (if (is-eq value u4) "4"
                        (if (is-eq value u5) "5"
                            (if (is-eq value u6) "6"
                                (if (is-eq value u7) "7"
                                    (if (is-eq value u8) "8"
                                        (if (is-eq value u9) "9"
                                            "10+"
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
  )
)

;; List utilities
(define-public (list-sum (values (list 20 uint)))
  (fold values u0 +)
)

(define-public (list-average (values (list 20 uint)))
  (begin
    (let ((count (len values)))
      (if (> count u0)
          (/ (list-sum values) count)
          u0
      )
    )
  )
)

(define-public (list-max (values (list 20 uint)))
  (fold values u0 max)
)

(define-public (list-min (values (list 20 uint)))
  (fold values u1000000 min)
)

;; Buffer utilities
(define-public (buff-to-uint (buff (buff 4)))
  (begin
    ;; Convert 4-byte buffer to uint (simplified)
    (if (is-eq (len buff) u4)
        (+ (* (get buff u0) u16777216) (* (get buff u1) u65536) (* (get buff u2) u256) (get buff u3))
        u0
    )
  )
)

(define-public (uint-to-buff (value uint))
  (begin
    ;; Convert uint to 4-byte buffer (simplified)
    (let ((byte3 (/ value u16777216))
          (remaining (- value (* byte3 u16777216)))
          (byte2 (/ remaining u65536))
          (remaining2 (- remaining (* byte2 u65536)))
          (byte1 (/ remaining2 u256))
          (byte0 (- remaining2 (* byte1 u256))))
      
      { u0: byte0, u1: byte1, u2: byte2, u3: byte3 }
    )
  )
)

;; Time utilities
(define-public (blocks-to-seconds (blocks uint))
  (* blocks u600) ;; Assuming 10 minutes per block on average
)

(define-public (seconds-to-blocks (seconds uint))
  (/ seconds u600)
)

(define-public (current-timestamp)
  (* block-height u600)
)

;; Validation utilities
(define-public (is-valid-principal (principal-value principal))
  (principal? principal-value)
)

(define-public (is-valid-amount (amount uint))
  (and (> amount u0) (< amount u340282366920938463463374607431768211455))
)

(define-public (is-valid-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage u10000))
)

;; Conversion utilities
(define-public (percentage-to-decimal (percentage uint))
  (/ percentage u10000)
)

(define-public (decimal-to-percentage (decimal uint))
  (* decimal u10000)
)

(define-public (wei-to-stx (wei uint))
  (/ wei u1000000)
)

(define-public (stx-to-wei (stx uint))
  (* stx u1000000)
)

;; Comparison utilities
(define-public (is-equal-within-tolerance (a uint) (b uint) (tolerance uint))
  (<= (abs (- a b)) tolerance)
)

(define-public (is-greater-within-tolerance (a uint) (b uint) (tolerance uint))
  (and (> a b) (<= (- a b) tolerance))
)

(define-public (is-less-within-tolerance (a uint) (b uint) (tolerance uint))
  (and (< a b) (<= (- b a) tolerance))
)

;; Array utilities
(define-public (reverse-list (values (list 20 uint)))
  (fold values (list 0 uint)
    (lambda ((result (list 20 uint)) (value uint))
      (append result value)
    )
  )
)

(define-public (filter-list (values (list 20 uint)) (predicate (bool uint)))
  (fold values (list 0 uint)
    (lambda ((result (list 20 uint)) (value uint))
      (if (predicate value)
          (append result value)
          result
      )
    )
  )
)

;; Error handling utilities
(define-public (safe-execute (function (response bool uint)) (default-value uint))
  (match function
    success success
    error default-value
  )
)

(define-public (try-catch (function (response bool uint)) (on-error (uint uint)))
  (match function
    success success
    error (on-error u0)
  )
)

;; State utilities
(define-public (if-else (condition bool) (true-value uint) (false-value uint))
  (if condition true-value false-value)
)

(define-public (bool-to-uint (condition bool))
  (if condition u1 u0)
)

(define-public (uint-to-bool (value uint))
  (> value u0)
)

;; Logging utilities (events)
(define-event (debug-log (message (string-ascii 256)) (context (string-ascii 64))))
(define-event (info-log (message (string-ascii 256)) (context (string-ascii 64))))
(define-event (warning-log (message (string-ascii 256)) (context (string-ascii 64))))
(define-event (error-log (message (string-ascii 256)) (context (string-ascii 64))))

(define-public (log-debug (message (string-ascii 256)) (context (string-ascii 64)))
  (emit-event (debug-log message context))
)

(define-public (log-info (message (string-ascii 256)) (context (string-ascii 64)))
  (emit-event (info-log message context))
)

(define-public (log-warning (message (string-ascii 256)) (context (string-ascii 64)))
  (emit-event (warning-log message context))
)

(define-public (log-error (message (string-ascii 256)) (context (string-ascii 64)))
  (emit-event (error-log message context))
)

;; Utility functions for common patterns
(define-public (calculate-percentage (part uint) (total uint))
  (begin
    (asserts! (> total u0) ERR_DIVISION_BY_ZERO)
    (/ (* part u10000) total)
  )
)

(define-public (calculate-proportion (percentage uint) (total uint))
  (/ (* percentage total) u10000)
)

(define-public (calculate-growth-rate (old-value uint) (new-value uint))
  (begin
    (asserts! (> old-value u0) ERR_DIVISION_BY_ZERO)
    (/ (* (- new-value old-value) u10000) old-value)
  )
)

(define-public (calculate-compound-interest (principal uint) (rate uint) (periods uint))
  (* principal (pow (/ (+ u10000 rate) u10000) periods))
)

;; Hash utilities
(define-public (hash-pair (a principal) (b principal))
  (hash160 (concat (principal-to-buff? a) (principal-to-buff? b)))
)

(define-public (hash-triple (a principal) (b principal) (c principal))
  (hash160 (concat (concat (principal-to-buff? a) (principal-to-buff? b)) (principal-to-buff? c)))
)

;; Address utilities
(define-public (is-contract-address (address principal))
  (not (is-eq (principal-to-string address) (principal-to-string tx-sender)))
)

(define-public (get-contract-name (address principal))
  (begin
    ;; Extract contract name from principal (simplified)
    (let ((address-str (principal-to-string address)))
      ;; In practice, would parse the address string properly
      address-str
    )
  )
)

;; Validation helpers
(define-public (validate-address (address principal) (expected-type (string-ascii 16)))
  (begin
    (asserts! (principal? address) ERR_INVALID_INPUT)
    (match expected-type
      "contract" (is-contract-address address)
      "user" (not (is-contract-address address))
      "any" true
      false
    )
  )
)

(define-public (validate-range (value uint) (min-value uint) (max-value uint))
  (and (>= value min-value) (<= value max-value))
)

(define-public (validate-not-zero (value uint))
  (> value u0)
)

;; Collection utilities
(define-public (list-contains (values (list 20 uint)) (target uint))
  (fold values false
    (lambda ((found bool) (value uint))
      (or found (is-eq value target))
    )
  )
)

(define-public (list-index-of (values (list 20 uint)) (target uint))
  (begin
    (let ((index u0))
      (fold values u100
        (lambda ((result uint) (value uint))
          (if (is-eq value target)
              index
              (begin
                (set! index (+ index u1))
                result
              )
          )
        )
      )
    )
  )
)

;; Memory utilities
(define-public (clear-map (map-id (buff 32)))
  (begin
    ;; This would clear a map entry (simplified)
    true
  )
)

;; Format utilities
(define-public (format-amount (amount uint) (decimals uint))
  (begin
    ;; Format amount with specified decimals (simplified)
    (uint-to-string amount)
  )
)

(define-public (format-percentage (percentage uint))
  (begin
    ;; Format as percentage string (simplified)
    (concat (uint-to-string (/ percentage u100)) "%")
  )
)

;; Security utilities
(define-public (require-caller (expected-caller principal))
  (asserts! (is-eq tx-sender expected-caller) ERR_INVALID_INPUT)
)

(define-public (require-admin)
  (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_INVALID_INPUT)
)

(define-public (require-owner)
  (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-owner)) ERR_INVALID_INPUT)
)
