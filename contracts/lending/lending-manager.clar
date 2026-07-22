;; lending-manager.clar
;; Unified lending and borrowing engine
;; Conxian Protocol Standard Contract - Upgraded for Dynamic Multi-Asset Collateral
;; Compliant with Clarity 4 and Sovereign Autonomy standards

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-fee-source-trait .protocol-fee-source-trait.protocol-fee-source-trait)
(impl-trait .protocol-fee-source-trait.protocol-fee-source-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INSUFFICIENT_COLLATERAL u1003)
(define-constant ERR_INVALID_AMOUNT u1004)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_INTERNAL u500)
(define-constant ERR_ORACLE_OFFLINE u5001)
(define-constant ERR_PROTOCOL_FEE_NOT_CONFIGURED u5010)
(define-constant ERR_PROTOCOL_FEE_PENDING u5011)
(define-constant ERR_PROTOCOL_FEE_CALLBACK_UNAUTHORIZED u5012)
(define-constant ERR_PROTOCOL_FEE_CALLBACK_RECIPIENT u5013)
(define-constant ERR_PROTOCOL_FEE_CALLBACK_ASSET u5014)
(define-constant ERR_PROTOCOL_FEE_CALLBACK_AMOUNT u5015)
(define-constant ERR_PROTOCOL_FEE_CALLBACK_BLOCK u5016)
(define-constant ERR_PROTOCOL_FEE_SETTLEMENT u5017)
(define-constant ERR_PROTOCOL_FEE_OVERDRAW u5018)
(define-constant ERR_PROTOCOL_FEE_NONCE_OVERFLOW u5019)
(define-constant ERR_PROTOCOL_FEE_UNSUPPORTED_ASSET u5020)

(define-constant COLLATERAL_FACTOR u7500)      ;; Default: 75%
(define-constant LIQUIDATION_THRESHOLD u8000)   ;; Default: 80%
(define-constant RESERVE_FACTOR u1000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; --- Storage ---
;; @desc Stores protocol-wide reserve data for each supported asset, including dynamic risk parameters.
(define-map reserve-data principal {
  total-deposits: uint,
  total-borrows: uint,
  total-reserves: uint,
  decimals: uint,
  collateral-factor: uint,
  liquidation-threshold: uint,
  last-updated: uint
})

;; @desc Tracks individual user deposit balances per asset.
(define-map deposits { asset: principal, user: principal } uint)
;; @desc Tracks individual user borrow balances per asset.
(define-map borrows { asset: principal, user: principal } uint)

;; @desc The administrative principal authorized to manage lending parameters.
(define-data-var admin principal tx-sender)
;; @desc Flag indicating if the contract has been initialized.
(define-data-var initialized bool false)
;; @desc List of all supported asset principals in the lending pool.
(define-data-var assets-list (list 20 principal) (list))

;; The fee stream is an admin-controlled asset mapping. No repayment may
;; silently fall back to a legacy or caller-selected stream.
(define-map protocol-fee-streams principal uint)

;; A manager-local nonce is hashed into a fixed-size replay key. It is advanced
;; only in the successful transaction that consumes the corresponding pending
;; source debit.
(define-data-var protocol-fee-nonce uint u0)

;; Pending source custody exists only for the current repayment transaction.
;; The callback intentionally receives no stream, base, or settlement ID; it
;; can spend only this exact manager-computed debit for the current payer.
(define-map pending-protocol-fees principal {
  settlement-id: (buff 32),
  stream-id: uint,
  asset: principal,
  expected-amount: uint,
  recipient: principal,
  created-at: uint
})

;; --- Internal Helpers ---

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    none
    (some (+ left right)))
)

(define-private (derive-protocol-fee-settlement-id (nonce uint))
  ;; The manager nonce is monotonic and manager-local. Clarity's native SHA-256
  ;; integer encoding gives a fixed `(buff 32)` replay key without caller input
  ;; or a block-height-only identifier.
  (sha256 nonce)
)

;; @desc Check if the contract is paused
(define-read-only (is-paused)
  (unwrap-panic (contract-call? .enhanced-circuit-breaker is-contract-paused .lending-manager))
)

;; --- Public Functions ---

;; @desc Deposits an asset into the lending pool.
;; @param asset-trait: The token being deposited.
;; @param amount: The quantity to deposit.
;; @returns (response bool uint)
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (match (map-get? reserve-data asset)
               res-val res-val
               {
                 total-deposits: u0,
                 total-borrows: u0,
                 total-reserves: u0,
                 decimals: (unwrap! (contract-call? asset-trait get-decimals) (err ERR_INTERNAL)),
                 collateral-factor: COLLATERAL_FACTOR,
                 liquidation-threshold: LIQUIDATION_THRESHOLD,
                 last-updated: burn-block-height
               }))
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      (if (is-none (index-of (var-get assets-list) asset))
        (var-set assets-list (unwrap! (as-max-len? (append (var-get assets-list) asset) u20) (err ERR_INTERNAL)))
        true
      )
      (map-set deposits { asset: asset, user: tx-sender } (+ (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })) amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (+ (get total-deposits reserve) amount) }))
      (ok true)
    )
  )
)

;; @desc Borrows an asset against collateral.
;; @param asset-trait: The token to borrow.
;; @param amount: The quantity to borrow.
;; @returns (response bool uint)
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (caller tx-sender)
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (<= amount (get total-deposits reserve)) (err ERR_INSUFFICIENT_LIQUIDITY))
      (map-set borrows { asset: asset, user: caller } (+ (default-to u0 (map-get? borrows { asset: asset, user: caller })) amount))
      (map-set reserve-data asset (merge reserve { total-borrows: (+ (get total-borrows reserve) amount) }))
      (let ((hf (unwrap-panic (calculate-account-health caller))))
        (asserts! (>= hf u10000) (err ERR_INSUFFICIENT_COLLATERAL))
      )
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) caller none)))
      (ok true)
    )
  )
)

;; @desc Repays a borrowed asset.
;; @param asset-trait: The token to repay.
;; @param amount: The quantity to repay.
;; @returns (response bool uint)
(define-public (repay
    (asset-trait <sip-010-ft-trait>)
    (amount uint)
    (source <protocol-fee-source-trait>))
  (let (
    (asset (contract-of asset-trait))
    (source-principal (contract-of source))
    (manager-principal (as-contract tx-sender))
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
    (interest-portion (/ (* amount RESERVE_FACTOR) u10000))
    (principal-portion (if (>= amount interest-portion) (- amount interest-portion) u0))
    (current-borrows (get total-borrows reserve))
    (user-borrows (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
  )
    (begin
      ;; The source trait is explicit at the call boundary to avoid a static
      ;; self-contract trait edge in the compiler dependency graph. It is still
      ;; fail-closed: only this lending-manager contract may be supplied.
      (asserts! (is-eq source-principal manager-principal) (err ERR_PROTOCOL_FEE_SETTLEMENT))
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      ;; The canonical lending base is interest-only. The source preview and
      ;; transaction-local pending record bind the collector debit before the
      ;; manager invokes the source-custody settlement callback.
      (let (
        (fee-amount
          (if (is-eq interest-portion u0)
            u0
            (let (
              (stream-id (unwrap! (map-get? protocol-fee-streams asset) (err ERR_PROTOCOL_FEE_NOT_CONFIGURED)))
              (preview (try! (contract-call? .protocol-fee-collector
                preview-source-ft
                source-principal
                stream-id
                asset
                interest-portion)))
              (next-nonce (unwrap! (safe-add (var-get protocol-fee-nonce) u1) (err ERR_PROTOCOL_FEE_NONCE_OVERFLOW)))
              (settlement-id (derive-protocol-fee-settlement-id next-nonce))
              (expected-amount (get assessed-amount preview))
            )
              (begin
                (asserts! (is-eq (get source preview) source-principal) (err ERR_PROTOCOL_FEE_SETTLEMENT))
                (asserts! (is-eq (get stream-id preview) stream-id) (err ERR_PROTOCOL_FEE_SETTLEMENT))
                (asserts! (is-eq (get asset preview) (some asset)) (err ERR_PROTOCOL_FEE_SETTLEMENT))
                (asserts! (is-none (map-get? pending-protocol-fees tx-sender)) (err ERR_PROTOCOL_FEE_PENDING))
                (map-set pending-protocol-fees tx-sender {
                  settlement-id: settlement-id,
                  stream-id: stream-id,
                  asset: asset,
                  expected-amount: expected-amount,
                  recipient: .protocol-fee-collector,
                  created-at: block-height
                })
                (var-set protocol-fee-nonce next-nonce)
                (let ((settled-fee (try! (contract-call? .protocol-fee-collector
                    settle-source-ft
                    source
                    asset-trait
                    stream-id
                    interest-portion
                    settlement-id))))
                  (begin
                    (asserts! (is-eq settled-fee expected-amount) (err ERR_PROTOCOL_FEE_SETTLEMENT))
                    (asserts! (is-none (map-get? pending-protocol-fees tx-sender)) (err ERR_PROTOCOL_FEE_SETTLEMENT))
                    settled-fee
                  )
                )
              )
            )
          )
        )
        (net-interest (if (>= interest-portion fee-amount) (- interest-portion fee-amount) u0))
      )
        (begin
          ;; A scheduled fee can never consume principal. If a future schedule
          ;; or residual bug would exceed interest, fail the whole repayment
          ;; rather than allowing reserve accounting to overdraw.
          (asserts! (>= interest-portion fee-amount) (err ERR_PROTOCOL_FEE_OVERDRAW))
          (let ((bme-res (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) interest-portion)))
            (print { event: "bme-report-processed", success: (is-ok bme-res) })
          )
          (map-set borrows { asset: asset, user: tx-sender } (if (>= user-borrows principal-portion) (- user-borrows principal-portion) u0))
          (map-set reserve-data asset (merge reserve {
            total-borrows: (if (>= current-borrows principal-portion) (- current-borrows principal-portion) u0),
            total-reserves: (unwrap! (safe-add (get total-reserves reserve) net-interest) (err ERR_INTERNAL))
          }))
          (print {
            event: "lending-protocol-fee-processed",
            asset: asset,
            eligible-interest-base: interest-portion,
            protocol-fee: fee-amount,
            net-interest-reserves: net-interest
          })
          (ok true)
        )
      )
    )
  )
)

;; --- Protocol-fee source callbacks ---

;; Lending-manager is an FT source in this phase. Keep the STX callback in the
;; trait implementation but fail closed so a future STX path cannot spend
;; manager custody without an explicit design and pending record.
(define-public (prepay-stx-fee (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq contract-caller .protocol-fee-collector) (err ERR_PROTOCOL_FEE_CALLBACK_UNAUTHORIZED))
    (asserts! (is-eq recipient .protocol-fee-collector) (err ERR_PROTOCOL_FEE_CALLBACK_RECIPIENT))
    (err ERR_PROTOCOL_FEE_UNSUPPORTED_ASSET)
  )
)

;; The callback is the only manager path that can consume the pending source
;; debit. It authenticates the collector, fixed recipient, exact token, exact
;; amount, and same-transaction block before spending manager custody. A zero
;; assessed amount consumes the pending record without attempting a zero-value
;; token transfer.
(define-public (prepay-ft-fee
    (token <sip-010-ft-trait>)
    (amount uint)
    (recipient principal))
  (let ((asset (contract-of token)))
    (begin
      (asserts! (is-eq contract-caller .protocol-fee-collector) (err ERR_PROTOCOL_FEE_CALLBACK_UNAUTHORIZED))
      (asserts! (is-eq recipient .protocol-fee-collector) (err ERR_PROTOCOL_FEE_CALLBACK_RECIPIENT))
      (let ((pending (unwrap! (map-get? pending-protocol-fees tx-sender) (err ERR_PROTOCOL_FEE_PENDING))))
        (begin
          (asserts! (is-eq asset (get asset pending)) (err ERR_PROTOCOL_FEE_CALLBACK_ASSET))
          (asserts! (is-eq amount (get expected-amount pending)) (err ERR_PROTOCOL_FEE_CALLBACK_AMOUNT))
          (asserts! (is-eq block-height (get created-at pending)) (err ERR_PROTOCOL_FEE_CALLBACK_BLOCK))
          (if (> amount u0)
            (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
            true)
          (map-delete pending-protocol-fees tx-sender)
          (ok true)
        )
      )
    )
  )
)

;; @desc Withdraws a previously deposited asset.
;; @param asset-trait: The token to withdraw.
;; @param amount: The quantity to withdraw.
;; @returns (response bool uint)
(define-public (withdraw (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (user-deposit (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
    (recipient tx-sender)
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (>= user-deposit amount) (err ERR_INVALID_AMOUNT))
      (map-set deposits { asset: asset, user: tx-sender } (- user-deposit amount))
      (let ((hf (unwrap-panic (calculate-account-health tx-sender))))
        (asserts! (>= hf u10000) (err ERR_INSUFFICIENT_COLLATERAL))
        (map-set reserve-data asset (merge reserve { total-deposits: (if (>= (get total-deposits reserve) amount) (- (get total-deposits reserve) amount) u0) }))
        (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) recipient none)))
        (ok true)
      )
    )
  )
)

;; @desc Transfers protocol revenue to the revenue-distributor.
;; @param asset-trait: The token asset reserves to collect.
;; @returns (response bool uint)
(define-public (collect-reserves (asset-trait <sip-010-ft-trait>))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
    (amount (get total-reserves reserve))
  )
    (begin
      (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (ok true))
      (map-set reserve-data asset (merge reserve { total-reserves: u0 }))
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) .revenue-distributor none)))
      (ok true)
    )
  )
)

;; --- Read-only Functions ---

;; @desc Private helper for health factor calculation.
(define-private (sum-user-asset-values (asset principal) (acc { user: principal, collateral-value: uint, debt-value: uint }))
  (let (
    (user (get user acc))
    (deposit-amt (default-to u0 (map-get? deposits { asset: asset, user: user })))
    (borrow-amt (default-to u0 (map-get? borrows { asset: asset, user: user })))
    (price (match (contract-call? .oracle-aggregator get-price asset) p p e u100000000))
    (reserve-opt (map-get? reserve-data asset))
  )
    (if (is-some reserve-opt)
      (let (
        (reserve-val (unwrap-panic reserve-opt))
        (decimals (get decimals reserve-val))
        (c-factor (get collateral-factor reserve-val))
        (asset-collateral-value (/ (* deposit-amt price c-factor) (* (pow u10 decimals) u10000)))
        (asset-debt-value (/ (* borrow-amt price) (pow u10 decimals)))
      )
        { user: user, collateral-value: (+ (get collateral-value acc) asset-collateral-value), debt-value: (+ (get debt-value acc) asset-debt-value) }
      )
      acc
    )
  )
)

;; @desc Calculates the health factor for a given user.
;; @param user: The principal to check.
;; @returns (response uint uint)
(define-read-only (calculate-account-health (user principal))
  (let (
    (summary (fold sum-user-asset-values (var-get assets-list) { user: user, collateral-value: u0, debt-value: u0 }))
  )
    (ok (if (is-eq (get debt-value summary) u0)
      u100000
      (/ (* (get collateral-value summary) u10000) (get debt-value summary))
    ))
  )
)

;; @desc Returns supply balance for a user and asset.
;; @param user: The user principal.
;; @param asset: The asset principal.
;; @returns (optional uint)
(define-read-only (get-user-supply-balance (user principal) (asset principal))
  (some (default-to u0 (map-get? deposits { asset: asset, user: user })))
)

;; @desc Returns total deposits for a specific asset.
;; @param asset: The asset principal.
;; @returns (response uint uint)
(define-read-only (get-total-deposits (asset principal))
  (match (map-get? reserve-data asset) reserve-val (ok (get total-deposits reserve-val)) (ok u0))
)

;; @desc Returns total borrows for a specific asset.
;; @param asset: The asset principal.
;; @returns (response uint uint)
(define-read-only (get-total-borrows (asset principal))
  (match (map-get? reserve-data asset) reserve-val (ok (get total-borrows reserve-val)) (ok u0))
)

;; @desc Returns raw reserve data for a specific asset.
;; @param asset: The asset principal.
;; @returns (optional { total-deposits: uint, total-borrows: uint, total-reserves: uint, decimals: uint, collateral-factor: uint, liquidation-threshold: uint, last-updated: uint })
(define-read-only (get-reserve-data (asset principal)) (map-get? reserve-data asset))

;; @desc Returns total value locked (Legacy endpoint).
;; @returns (response uint uint)
(define-read-only (get-protocol-tvl)
  (ok (fold sum-asset-tvl (var-get assets-list) u0))
)

;; @desc Private helper for TVL calculation.
(define-private (sum-asset-tvl (asset principal) (acc uint))
  (let (
    (reserve (default-to { total-deposits: u0, total-borrows: u0, total-reserves: u0, decimals: u8, collateral-factor: COLLATERAL_FACTOR, liquidation-threshold: LIQUIDATION_THRESHOLD, last-updated: u0 } (map-get? reserve-data asset)))
    (price (match (contract-call? .oracle-aggregator get-price asset) p p e u100000000))
  )
    (+ acc (/ (* (get total-deposits reserve) price) (pow u10 (get decimals reserve))))
  )
)

;; --- Admin Functions ---

;; @desc Initialize the contract with an admin.
;; @param new-admin: The admin principal.
;; @returns (response bool uint)
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (not (var-get initialized)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Updates the administrator principal.
;; @param new-admin: The new admin principal.
;; @returns (response bool uint)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Maps one supported lending asset to its canonical collector stream.
;; @param asset: The SIP-010 token principal.
;; @param stream-id: The immutable stream registered for this source/asset.
(define-public (set-protocol-fee-stream (asset principal) (stream-id uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (> stream-id u0) (err ERR_INVALID_AMOUNT))
    (map-set protocol-fee-streams asset stream-id)
    (ok stream-id)
  )
)

;; @desc Removes an asset mapping so repayments fail closed until reconfigured.
(define-public (clear-protocol-fee-stream (asset principal))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-delete protocol-fee-streams asset)
    (ok true)
  )
)

(define-read-only (get-protocol-fee-stream (asset principal))
  (ok (map-get? protocol-fee-streams asset))
)

(define-read-only (get-pending-protocol-fee (payer principal))
  (ok (map-get? pending-protocol-fees payer))
)

;; @desc Configures risk and collateral parameters for a specific asset.
;; @param asset: The asset principal.
;; @param collateral-factor: Loan-to-Value (LTV) ratio in basis points.
;; @param liquidation-threshold: Liquidation threshold in basis points.
;; @returns (response bool uint)
(define-public (configure-asset-collateral (asset principal) (collateral-factor uint) (liquidation-threshold uint))
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (<= collateral-factor u10000) (err ERR_INVALID_AMOUNT))
    (asserts! (<= liquidation-threshold u10000) (err ERR_INVALID_AMOUNT))
    (asserts! (>= liquidation-threshold collateral-factor) (err ERR_INVALID_AMOUNT))
    (let (
      (reserve (match (map-get? reserve-data asset)
                 res-val res-val
                 {
                   total-deposits: u0,
                   total-borrows: u0,
                   total-reserves: u0,
                   decimals: u8,
                   collateral-factor: collateral-factor,
                   liquidation-threshold: liquidation-threshold,
                   last-updated: burn-block-height
                 }))
    )
      (map-set reserve-data asset (merge reserve {
        collateral-factor: collateral-factor,
        liquidation-threshold: liquidation-threshold
      }))
      (if (is-none (index-of (var-get assets-list) asset))
        (var-set assets-list (unwrap! (as-max-len? (append (var-get assets-list) asset) u20) (err ERR_INTERNAL)))
        true
      )
      (ok true)
    )
  )
)
