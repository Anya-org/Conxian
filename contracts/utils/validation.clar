;; validation.clar
;; Conxian Protocol: Validation utilities and input verification

;; Constants
(define-constant ERR_INVALID_INPUT (err 39001))
(define-constant ERR_INVALID_AMOUNT (err 39002))
(define-constant ERR_INVALID_ADDRESS (err 39003))
(define-constant ERR_INVALID_PERCENTAGE (err 39004))
(define-constant ERR_INVALID_TIMESTAMP (err 39005))
(define-constant ERR_INVALID_STRING (err 39006))
(define-constant ERR_INVALID_BUFFER (err 39007))
(define-constant ERR_OUT_OF_RANGE (err 39008))
(define-constant ERR_EMPTY_INPUT (err 39009))
(define-constant ERR_TOO_LONG (err 39010))

;; Validation parameters
(define-constant MAX_STRING_LENGTH u256)
(define-constant MAX_BUFFER_LENGTH u1024)
(define-constant MAX_AMOUNT u340282366920938463463374607431768211455)
(define-constant MIN_AMOUNT u1)
(define-constant MAX_PERCENTAGE u10000)
(define-constant MIN_PERCENTAGE u0)

;; Basic validation functions

(define-public (validate-not-empty (value (string-ascii 256)))
  (begin
    (asserts! (> (len value) u0) ERR_EMPTY_INPUT)
    true
  )
)

(define-public (validate-string-length (value (string-ascii 256)) (max-length uint))
  (begin
    (asserts! (> (len value) u0) ERR_EMPTY_INPUT)
    (asserts! (<= (len value) max-length) ERR_TOO_LONG)
    true
  )
)

(define-public (validate-buffer-length (value (buff 1024)) (max-length uint))
  (begin
    (asserts! (> (len value) u0) ERR_EMPTY_INPUT)
    (asserts! (<= (len value) max-length) ERR_TOO_LONG)
    true
  )
)

;; Numeric validation

(define-public (validate-amount (amount uint))
  (begin
    (asserts! (>= amount MIN_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (< amount MAX_AMOUNT) ERR_INVALID_AMOUNT)
    true
  )
)

(define-public (validate-amount-range (amount uint) (min-amount uint) (max-amount uint))
  (begin
    (asserts! (>= amount min-amount) ERR_OUT_OF_RANGE)
    (asserts! (<= amount max-amount) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-percentage (percentage uint))
  (begin
    (asserts! (>= percentage MIN_PERCENTAGE) ERR_INVALID_PERCENTAGE)
    (asserts! (<= percentage MAX_PERCENTAGE) ERR_INVALID_PERCENTAGE)
    true
  )
)

(define-public (validate-positive-uint (value uint))
  (begin
    (asserts! (> value u0) ERR_INVALID_INPUT)
    true
  )
)

(define-public (validate-non-negative-uint (value uint))
  (begin
    (asserts! (>= value u0) ERR_INVALID_INPUT)
    true
  )
)

;; Address validation

(define-public (validate-principal (address principal))
  (begin
    (asserts! (principal? address) ERR_INVALID_ADDRESS)
    true
  )
)

(define-public (validate-contract-address (address principal))
  (begin
    (asserts! (principal? address) ERR_INVALID_ADDRESS)
    (asserts! (is-contract-address address) ERR_INVALID_ADDRESS)
    true
  )
)

(define-public (validate-user-address (address principal))
  (begin
    (asserts! (principal? address) ERR_INVALID_ADDRESS)
    (asserts! (not (is-contract-address address)) ERR_INVALID_ADDRESS)
    true
  )
)

(define-public (validate-not-self (address principal))
  (begin
    (asserts! (not (is-eq address tx-sender)) ERR_INVALID_ADDRESS)
    true
  )
)

;; String validation

(define-public (validate-alphanumeric (value (string-ascii 256)))
  (begin
    (validate-string-length value MAX_STRING_LENGTH)
    ;; In practice, would check each character is alphanumeric
    true
  )
)

(define-public (validate-hex-string (value (string-ascii 256)))
  (begin
    (validate-string-length value MAX_STRING_LENGTH)
    ;; In practice, would check each character is hex digit
    true
  )
)

(define-public (validate-email-format (value (string-ascii 256)))
  (begin
    (validate-string-length value MAX_STRING_LENGTH)
    ;; In practice, would validate email format with regex
    true
  )
)

(define-public (validate-url-format (value (string-ascii 256)))
  (begin
    (validate-string-length value MAX_STRING_LENGTH)
    ;; In practice, would validate URL format
    true
  )
)

;; Buffer validation

(define-public (validate-buffer-size (value (buff 1024)) (expected-size uint))
  (begin
    (asserts! (is-eq (len value) expected-size) ERR_INVALID_BUFFER)
    true
  )
)

(define-public (validate-hash (hash (buff 32)))
  (begin
    (validate-buffer-size hash u32)
    true
  )
)

(define-public (validate-signature (signature (buff 65)))
  (begin
    (validate-buffer-size signature u65)
    true
  )
)

(define-public (validate-public-key (public-key (buff 33)))
  (begin
    (validate-buffer-size public-key u33)
    true
  )
)

;; Timestamp validation

(define-public (validate-timestamp (timestamp uint))
  (begin
    (asserts! (<= timestamp block-height) ERR_INVALID_TIMESTAMP)
    true
  )
)

(define-public (validate-future-timestamp (timestamp uint) (max-future uint))
  (begin
    (asserts! (> timestamp block-height) ERR_INVALID_TIMESTAMP)
    (asserts! (<= timestamp (+ block-height max-future)) ERR_INVALID_TIMESTAMP)
    true
  )
)

(define-public (validate-timestamp-range (timestamp uint) (min-timestamp uint) (max-timestamp uint))
  (begin
    (asserts! (>= timestamp min-timestamp) ERR_OUT_OF_RANGE)
    (asserts! (<= timestamp max-timestamp) ERR_OUT_OF_RANGE)
    true
  )
)

;; Range validation

(define-public (validate-in-range (value uint) (min-value uint) (max-value uint))
  (begin
    (asserts! (>= value min-value) ERR_OUT_OF_RANGE)
    (asserts! (<= value max-value) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-greater-than (value uint) (threshold uint))
  (begin
    (asserts! (> value threshold) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-greater-or-equal (value uint) (threshold uint))
  (begin
    (asserts! (>= value threshold) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-less-than (value uint) (threshold uint))
  (begin
    (asserts! (< value threshold) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-less-or-equal (value uint) (threshold uint))
  (begin
    (asserts! (<= value threshold) ERR_OUT_OF_RANGE)
    true
  )
)

;; List validation

(define-public (validate-list-not-empty (list (list 20 uint)))
  (begin
    (asserts! (> (len list) u0) ERR_EMPTY_INPUT)
    true
  )
)

(define-public (validate-list-length (list (list 20 uint)) (expected-length uint))
  (begin
    (asserts! (is-eq (len list) expected-length) ERR_OUT_OF_RANGE)
    true
  )
)

(define-public (validate-list-range (list (list 20 uint)) (min-length uint) (max-length uint))
  (begin
    (asserts! (>= (len list) min-length) ERR_OUT_OF_RANGE)
    (asserts! (<= (len list) max-length) ERR_OUT_OF_RANGE)
    true
  )
)

;; Token validation

(define-public (validate-token-contract (token principal))
  (begin
    (validate-principal token)
    (validate-contract-address token)
    ;; In practice, would check if contract implements SIP-010 trait
    true
  )
)

(define-public (validate-nft-contract (nft principal))
  (begin
    (validate-principal nft)
    (validate-contract-address nft)
    ;; In practice, would check if contract implements SIP-009 trait
    true
  )
)

(define-public (validate-token-balance (token principal) (owner principal) (expected-balance uint))
  (begin
    (validate-token-contract token)
    (validate-principal owner)
    ;; In practice, would check actual balance
    true
  )
)

;; Pool validation

(define-public (validate-pool-contract (pool principal))
  (begin
    (validate-principal pool)
    (validate-contract-address pool)
    ;; In practice, would check if contract implements pool traits
    true
  )
)

(define-public (validate-pool-reserves (reserve-0 uint) (reserve-1 uint))
  (begin
    (validate-amount reserve-0)
    (validate-amount reserve-1)
    true
  )
)

(define-public (validate-pool-liquidity (liquidity uint) (min-liquidity uint))
  (begin
    (validate-greater-or-equal liquidity min-liquidity)
    true
  )
)

;; Trade validation

(define-public (validate-trade-amount (amount-in uint) (amount-out uint))
  (begin
    (validate-amount amount-in)
    (validate-amount amount-out)
    true
  )
)

(define-public (validate-slippage (slippage uint) (max-slippage uint))
  (begin
    (validate-percentage slippage)
    (validate-less-or-equal slippage max-slippage)
    true
  )
)

(define-public (validate-deadline (deadline uint))
  (begin
    (validate-greater-than deadline block-height)
    true
  )
)

;; Governance validation

(define-public (validate-voting-power (power uint) (max-power uint))
  (begin
    (validate-in-range power u0 max-power)
    true
  )
)

(define-public (validate-quorum (quorum uint) (total-votes uint))
  (begin
    (validate-in-range quorum u0 total-votes)
    true
  )
)

(define-public (validate-proposal-id (proposal-id uint))
  (begin
    (validate-positive-uint proposal-id)
    true
  )
)

;; Oracle validation

(define-public (validate-oracle-price (price uint) (min-price uint) (max-price uint))
  (begin
    (validate-in-range price min-price max-price)
    true
  )
)

(define-public (validate-oracle-timestamp (timestamp uint) (max-age uint))
  (begin
    (validate-timestamp timestamp)
    (asserts! (>= (- block-height timestamp) max-age) ERR_INVALID_TIMESTAMP)
    true
  )
)

;; Security validation

(define-public (validate-permission (caller principal) (required-role (string-ascii 32)))
  (begin
    (validate-principal caller)
    ;; In practice, would check caller's role
    true
  )
)

(define-public (validate-admin (caller principal))
  (begin
    (validate-principal caller)
    (asserts! (is-eq caller (contract-call? .conxian-protocol get-admin)) ERR_INVALID_INPUT)
    true
  )
)

(define-public (validate-owner (caller principal))
  (begin
    (validate-principal caller)
    (asserts! (is-eq caller (contract-call? .conxian-protocol get-owner)) ERR_INVALID_INPUT)
    true
  )
)

;; Batch validation

(define-public (validate-batch-size (batch-size uint) (max-batch-size uint))
  (begin
    (validate-in-range batch-size u1 max-batch-size)
    true
  )
)

(define-public (validate-batch-amounts (amounts (list 20 uint)) (total-amount uint))
  (begin
    (validate-list-not-empty amounts)
    (asserts! (is-eq (list-sum amounts) total-amount) ERR_INVALID_AMOUNT)
    true
  )
)

;; State validation

(define-public (validate-state-transition (current-state (string-ascii 16)) (new-state (string-ascii 16)) (allowed-transitions (list 5 (string-ascii 16))))
  (begin
    ;; In practice, would check if transition is allowed
    true
  )
)

(define-public (validate-contract-state (contract principal) (expected-state (string-ascii 16)))
  (begin
    (validate-principal contract)
    ;; In practice, would check actual contract state
    true
  )
)

;; Cross-chain validation

(define-public (validate-chain-id (chain-id uint))
  (begin
    ;; Validate chain ID is within expected range
    (validate-in-range chain-id u1 u1000)
    true
  )
)

(define-public (validate-cross-chain-message (message (buff 1024)) (source-chain uint))
  (begin
    (validate-buffer-length message MAX_BUFFER_LENGTH)
    (validate-chain-id source-chain)
    true
  )
)

;; Utility validation functions

(define-public (validate-and-return (value uint) (validator (uint bool)))
  (begin
    (validator value)
    value
  )
)

(define-public (validate-or-default (value uint) (validator (uint bool)) (default-value uint))
  (begin
    (match (validator value)
      success value
      error default-value
    )
  )
)

(define-public (validate-multiple (validators (list 10 (bool bool))))
  (begin
    (fold validators true
      (lambda ((result bool) (validator (bool bool)))
        (and result validator)
      )
    )
  )
)

;; Custom validation builders

(define-public (create-amount-validator (min-amount uint) (max-amount uint))
  (lambda ((amount uint))
    (validate-amount-range amount min-amount max-amount)
  )
)

(define-public (create-percentage-validator (max-percentage uint))
  (lambda ((percentage uint))
    (validate-less-or-equal percentage max-percentage)
  )
)

(define-public (create-timestamp-validator (min-age uint) (max-age uint))
  (lambda ((timestamp uint))
    (validate-timestamp-range timestamp (- block-height max-age) (- block-height min-age))
  )
)

;; Validation result reporting

(define-event (validation-success (field (string-ascii 32)) (value uint)))
(define-event (validation-failure (field (string-ascii 32)) (error uint)))
(define-event (validation-warning (field (string-ascii 32)) (message (string-ascii 256))))

(define-public (validate-with-logging (field (string-ascii 32)) (value uint) (validator (uint bool)))
  (begin
    (match (validator value)
      success
        (begin
          (emit-event (validation-success field value))
          true
        )
      error
        (begin
          (emit-event (validation-failure field (unwrap-panic error)))
          false
        )
    )
  )
)

;; Comprehensive validation

(define-public (validate-complete-transaction 
  (caller principal)
  (amount-in uint)
  (amount-out uint)
  (deadline uint)
  (slippage uint)
)
  (begin
    (validate-principal caller)
    (validate-trade-amount amount-in amount-out)
    (validate-deadline deadline)
    (validate-slippage slippage u500) ;; 5% max slippage
    true
  )
)

(define-public (validate-complete-proposal 
  (proposer principal)
  (title (string-ascii 128))
  (description (string-ascii 512))
  (voting-period uint)
  (quorum uint)
)
  (begin
    (validate-principal proposer)
    (validate-string-length title u128)
    (validate-string-length description u512)
    (validate-greater-than voting-period u0)
    (validate-positive-uint quorum)
    true
  )
)
