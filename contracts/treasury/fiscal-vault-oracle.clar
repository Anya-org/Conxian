;; @contract fiscal-vault-oracle
;; @desc Period-scoped fiscal allocations and the legacy SBC release surface.
;;
;; Category IDs are intentionally small and stable so off-chain treasury
;; automation can use the same values across deployments:
;;   u1 operations, u2 payroll, u3 infrastructure, u4 grants,
;;   u5 liquidity, u6 compliance, u7 reserves, u8 other.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u400)
(define-constant ERR_INVALID_AMOUNT u401)
(define-constant ERR_INVALID_CATEGORY u402)
(define-constant ERR_INVALID_PERIOD u403)
(define-constant ERR_INVALID_SBC u404)
(define-constant ERR_SBC_NOT_REGISTERED u405)
(define-constant ERR_ALLOCATION_NOT_FOUND u406)
(define-constant ERR_ALLOCATION_ACTIVE u407)
(define-constant ERR_ALLOCATION_NOT_APPROVED u408)
(define-constant ERR_ALLOCATION_ALREADY_APPROVED u409)
(define-constant ERR_ALLOCATION_CANCELLED u410)
(define-constant ERR_CAP_NOT_SET u411)
(define-constant ERR_CAP_EXCEEDED u412)
(define-constant ERR_COMMITMENT_EXCEEDED u413)
(define-constant ERR_RESERVE_VIOLATION u414)
(define-constant ERR_INSUFFICIENT_BALANCE u415)
(define-constant ERR_TRANSFER_FAILED u416)
(define-constant ERR_UNSAFE_CAP_REDUCTION u417)

(define-constant CATEGORY_MIN u1)
(define-constant CATEGORY_MAX u8)

(define-data-var admin principal tx-sender)
(define-data-var governance principal tx-sender)
(define-data-var payment-forge principal tx-sender)
(define-data-var current-period uint u1)
(define-data-var next-allocation-id uint u1)

(define-map sbc-beneficiaries
  (string-ascii 32)
  principal
)

(define-map category-caps
  { period: uint, token: principal, category: uint }
  uint
)

(define-map category-spent
  { period: uint, token: principal, category: uint }
  uint
)

;; Outstanding approved allocations. This is deliberately separate from
;; spent so a cap is reserved when an allocation is approved, not when it is
;; merely drafted.
(define-map category-commitments
  { period: uint, token: principal, category: uint }
  uint
)

(define-map required-reserves principal uint)
(define-map tracked-balances principal uint)

(define-map allocation-records
  uint
  {
    id: uint,
    sbc: (string-ascii 32),
    token: principal,
    period: uint,
    category: uint,
    amount: uint,
    released: uint,
    beneficiary: principal,
    approved: bool,
    active: bool,
    cancelled: bool
  }
)

;; The active index is the only pair-keyed state used by the compatibility
;; release wrapper. Terminal allocations are removed from this index so an
;; SBC/token pair can be reused without mutating its prior record.
(define-map active-allocation-ids
  { sbc: (string-ascii 32), token: principal }
  uint
)

;; Keep the latest record available through the existing pair lookup API while
;; retaining every historical record in allocation-records.
(define-map latest-allocation-ids
  { sbc: (string-ascii 32), token: principal }
  uint
)

(define-private (is-valid-category (category uint))
  (and (>= category CATEGORY_MIN) (<= category CATEGORY_MAX))
)

(define-private (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

(define-private (is-config-authorized)
  (or (is-admin contract-caller) (is-eq contract-caller (var-get governance)))
)

(define-private (is-release-authorized)
  (or
    (is-config-authorized)
    (is-eq contract-caller (var-get payment-forge))
  )
)

(define-private (allocation-key (sbc (string-ascii 32)) (token principal))
  { sbc: sbc, token: token }
)

(define-private (category-key (period uint) (token principal) (category uint))
  { period: period, token: token, category: category }
)

;; @desc Changes the administrative, governance, and payment-forge actors.
(define-public (set-authorized-principals
    (new-admin principal)
    (new-governance principal)
    (new-payment-forge principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (var-set governance new-governance)
    (var-set payment-forge new-payment-forge)
    (print {
      event: "fiscal-authorized-principals-updated",
      admin: new-admin,
      governance: new-governance,
      payment-forge: new-payment-forge,
      block-height: block-height
    })
    (ok true)
  )
)

;; @desc Compatibility initializer used by treasury bootstrap scripts.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-governance (new-governance principal))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (var-set governance new-governance)
    (ok true)
  )
)

(define-public (set-payment-forge (new-payment-forge principal))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (var-set payment-forge new-payment-forge)
    (ok true)
  )
)

(define-public (set-current-period (new-period uint))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (> new-period u0) (err ERR_INVALID_PERIOD))
    (asserts! (>= new-period (var-get current-period)) (err ERR_INVALID_PERIOD))
    (var-set current-period new-period)
    (print {
      event: "fiscal-period-updated",
      period: new-period,
      block-height: block-height
    })
    (ok true)
  )
)

(define-public (register-sbc (sbc (string-ascii 32)) (beneficiary principal))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (> (len sbc) u0) (err ERR_INVALID_SBC))
    (map-set sbc-beneficiaries sbc beneficiary)
    (print {
      event: "fiscal-sbc-registered",
      sbc: sbc,
      beneficiary: beneficiary,
      block-height: block-height
    })
    (ok true)
  )
)

(define-public (set-required-reserve (token principal) (amount uint))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (map-set required-reserves token amount)
    (print {
      event: "fiscal-required-reserve-updated",
      token: token,
      amount: amount,
      block-height: block-height
    })
    (ok true)
  )
)

;; @desc Deposits a SIP-010 token and records the deposit in the fiscal ledger.
;; Payment-forge may also transfer directly to this contract for backwards
;; compatibility; release-funds-to-sbc always checks the live token balance.
(define-public (deposit (token <sip-010-trait>) (amount uint))
  (let (
      (token-principal (contract-of token))
      (tracked (default-to u0 (map-get? tracked-balances (contract-of token))))
    )
    (begin
      (asserts! (is-release-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      (map-set tracked-balances token-principal (+ tracked amount))
      (print {
        event: "fiscal-deposit",
        token: token-principal,
        amount: amount,
        block-height: block-height
      })
      (ok true)
    )
  )
)

(define-public (set-category-cap
    (token principal)
    (category uint)
    (cap uint))
  (let (
      (period (var-get current-period))
      (key (category-key (var-get current-period) token category))
      (spent (default-to u0 (map-get? category-spent key)))
      (committed (default-to u0 (map-get? category-commitments key)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (asserts! (>= cap (+ spent committed)) (err ERR_UNSAFE_CAP_REDUCTION))
      (map-set category-caps { period: period, token: token, category: category } cap)
      (print {
        event: "fiscal-category-cap-updated",
        period: period,
        token: token,
        category: category,
        cap: cap,
        block-height: block-height
      })
      (ok true)
    )
  )
)

(define-public (set-category-cap-for-period
    (period uint)
    (token principal)
    (category uint)
    (cap uint))
  (let (
      (key (category-key period token category))
      (spent (default-to u0 (map-get? category-spent key)))
      (committed (default-to u0 (map-get? category-commitments key)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (> period u0) (err ERR_INVALID_PERIOD))
      (asserts! (>= period (var-get current-period)) (err ERR_INVALID_PERIOD))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (asserts! (>= cap (+ spent committed)) (err ERR_UNSAFE_CAP_REDUCTION))
      (map-set category-caps key cap)
      (ok true)
    )
  )
)

;; @desc Creates one pending allocation for an SBC/token pair.
(define-public (create-allocation
    (sbc (string-ascii 32))
    (token principal)
    (category uint)
    (amount uint))
  (let (
      (key (allocation-key sbc token))
      (beneficiary (map-get? sbc-beneficiaries sbc))
      (allocation-id (var-get next-allocation-id))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (> (len sbc) u0) (err ERR_INVALID_SBC))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (match beneficiary
        beneficiary-principal
          (begin
            (match (map-get? active-allocation-ids key)
              active-id
                (match (map-get? allocation-records active-id)
                  active-record (asserts! (not (get active active-record)) (err ERR_ALLOCATION_ACTIVE))
                  true)
              true)
            (map-set allocation-records allocation-id {
              id: allocation-id,
              sbc: sbc,
              token: token,
              period: (var-get current-period),
              category: category,
              amount: amount,
              released: u0,
              beneficiary: beneficiary-principal,
              approved: false,
              active: true,
              cancelled: false
            })
            (map-set active-allocation-ids key allocation-id)
            (map-set latest-allocation-ids key allocation-id)
            (var-set next-allocation-id (+ allocation-id u1))
            (print {
              event: "fiscal-allocation-created",
              allocation-id: allocation-id,
              sbc: sbc,
              token: token,
              category: category,
              amount: amount,
              block-height: block-height
            })
            (ok allocation-id)
          )
        (err ERR_SBC_NOT_REGISTERED)
      )
    )
  )
)

(define-public (approve-allocation
    (sbc (string-ascii 32))
    (token principal))
  (let (
      (key (allocation-key sbc token))
      (active-id (map-get? active-allocation-ids (allocation-key sbc token)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (match active-id
        allocation-id
          (match (map-get? allocation-records allocation-id)
            allocation-data
              (let (
                  (period (get period allocation-data))
                  (category (get category allocation-data))
                  (amount (get amount allocation-data))
                  (cap (default-to u0 (map-get? category-caps (category-key period token category))))
                  (spent (default-to u0 (map-get? category-spent (category-key period token category))))
                  (committed (default-to u0 (map-get? category-commitments (category-key period token category))))
                )
                (begin
                  (asserts! (get active allocation-data) (err ERR_ALLOCATION_CANCELLED))
                  (asserts! (not (get approved allocation-data)) (err ERR_ALLOCATION_ALREADY_APPROVED))
                  (asserts! (> cap u0) (err ERR_CAP_NOT_SET))
                  (asserts! (<= (+ spent (+ committed amount)) cap) (err ERR_CAP_EXCEEDED))
                  (map-set allocation-records allocation-id {
                    id: (get id allocation-data),
                    sbc: (get sbc allocation-data),
                    token: (get token allocation-data),
                    period: period,
                    category: category,
                    amount: amount,
                    released: (get released allocation-data),
                    beneficiary: (get beneficiary allocation-data),
                    approved: true,
                    active: true,
                    cancelled: false
                  })
                  (map-set category-commitments
                    (category-key period token category)
                    (+ committed amount))
                  (print {
                    event: "fiscal-allocation-approved",
                    allocation-id: (get id allocation-data),
                    sbc: sbc,
                    token: token,
                    block-height: block-height
                  })
                  (ok true)
                )
              )
            (err ERR_ALLOCATION_NOT_FOUND)
          )
        (err ERR_ALLOCATION_NOT_FOUND)
      )
    )
  )
)

(define-public (cancel-allocation
    (sbc (string-ascii 32))
    (token principal))
  (let (
      (key (allocation-key sbc token))
      (active-id (map-get? active-allocation-ids (allocation-key sbc token)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (match active-id
        allocation-id
          (match (map-get? allocation-records allocation-id)
            allocation-data
              (let (
                  (period (get period allocation-data))
                  (category (get category allocation-data))
                  (committed (default-to u0 (map-get? category-commitments (category-key period token category))))
                  (remaining (if
                    (>= (get amount allocation-data) (get released allocation-data))
                    (- (get amount allocation-data) (get released allocation-data))
                    u0))
                )
                (begin
                  (asserts! (get active allocation-data) (err ERR_ALLOCATION_CANCELLED))
                  (if (get approved allocation-data)
                    (begin
                      (asserts! (>= committed remaining) (err ERR_COMMITMENT_EXCEEDED))
                      (map-set category-commitments
                        (category-key period token category)
                        (- committed remaining))
                    )
                    true)
                  (map-set allocation-records allocation-id {
                    id: (get id allocation-data),
                    sbc: (get sbc allocation-data),
                    token: (get token allocation-data),
                    period: period,
                    category: category,
                    amount: (get amount allocation-data),
                    released: (get released allocation-data),
                    beneficiary: (get beneficiary allocation-data),
                    approved: (get approved allocation-data),
                    active: false,
                    cancelled: true
                  })
                  (map-delete active-allocation-ids key)
                  (print {
                    event: "fiscal-allocation-cancelled",
                    allocation-id: (get id allocation-data),
                    sbc: sbc,
                    token: token,
                    block-height: block-height
                  })
                  (ok true)
                )
              )
            (err ERR_ALLOCATION_NOT_FOUND)
          )
        (err ERR_ALLOCATION_NOT_FOUND)
      )
    )
  )
)

;; @desc Legacy payment-forge API. Keep this signature stable.
(define-public (release-funds-to-sbc
    (sbc (string-ascii 32))
    (amount uint)
    (token <sip-010-trait>))
  (let (
      (token-principal (contract-of token))
      (key (allocation-key sbc (contract-of token)))
      (beneficiary (map-get? sbc-beneficiaries sbc))
      (active-id (map-get? active-allocation-ids (allocation-key sbc (contract-of token))))
    )
    (begin
      (asserts! (is-release-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (match beneficiary
        beneficiary-principal
          (match active-id
            allocation-id
              (match (map-get? allocation-records allocation-id)
                allocation-data
                  (let (
                      (period (get period allocation-data))
                      (category (get category allocation-data))
                      (allocation-amount (get amount allocation-data))
                      (released (get released allocation-data))
                      (remaining (if (>= allocation-amount released) (- allocation-amount released) u0))
                      (category-key-value (category-key period token-principal category))
                      (cap (default-to u0 (map-get? category-caps category-key-value)))
                      (spent (default-to u0 (map-get? category-spent category-key-value)))
                      (committed (default-to u0 (map-get? category-commitments category-key-value)))
                      (reserve (default-to u0 (map-get? required-reserves token-principal)))
                      (vault-balance (try! (contract-call? token get-balance (as-contract tx-sender))))
                      (new-released (+ released amount))
                    )
                    (begin
                      (asserts! (get active allocation-data) (err ERR_ALLOCATION_CANCELLED))
                      (asserts! (get approved allocation-data) (err ERR_ALLOCATION_NOT_APPROVED))
                      (asserts! (is-eq beneficiary-principal (get beneficiary allocation-data)) (err ERR_SBC_NOT_REGISTERED))
                      (asserts! (<= amount remaining) (err ERR_CAP_EXCEEDED))
                      (asserts! (> cap u0) (err ERR_CAP_NOT_SET))
                      (asserts! (<= (+ spent amount) cap) (err ERR_CAP_EXCEEDED))
                      (asserts! (>= committed amount) (err ERR_COMMITMENT_EXCEEDED))
                      ;; The live balance must cover the required reserve and all
                      ;; outstanding commitments, including this release. This
                      ;; keeps a successful release from making the vault
                      ;; insolvent for another approved allocation.
                      (asserts! (>= vault-balance (+ reserve committed)) (err ERR_RESERVE_VIOLATION))
                      (try! (as-contract (contract-call? token transfer amount tx-sender beneficiary-principal none)))
                      (map-set allocation-records allocation-id {
                        id: (get id allocation-data),
                        sbc: (get sbc allocation-data),
                        token: (get token allocation-data),
                        period: period,
                        category: category,
                        amount: allocation-amount,
                        released: new-released,
                        beneficiary: beneficiary-principal,
                        approved: true,
                        active: (not (is-eq new-released allocation-amount)),
                        cancelled: false
                      })
                      (if (is-eq new-released allocation-amount)
                        (map-delete active-allocation-ids key)
                        true)
                      (map-set category-commitments category-key-value (- committed amount))
                      (map-set category-spent category-key-value (+ spent amount))
                      ;; Use the live pre-transfer balance as the source of truth
                      ;; so direct payment-forge deposits are reflected too.
                      (map-set tracked-balances token-principal (- vault-balance amount))
                      (print {
                        event: "fiscal-funds-released",
                        allocation-id: (get id allocation-data),
                        sbc: sbc,
                        token: token-principal,
                        beneficiary: beneficiary-principal,
                        amount: amount,
                        block-height: block-height
                      })
                      (ok true)
                    )
                  )
                (err ERR_ALLOCATION_NOT_FOUND)
              )
            (err ERR_ALLOCATION_NOT_FOUND)
          )
        (err ERR_SBC_NOT_REGISTERED)
      )
    )
  )
)

(define-read-only (get-beneficiary (sbc (string-ascii 32)))
  (map-get? sbc-beneficiaries sbc)
)

(define-read-only (get-allocation
    (sbc (string-ascii 32))
    (token principal))
  (match (map-get? latest-allocation-ids (allocation-key sbc token))
    allocation-id (map-get? allocation-records allocation-id)
    none
  )
)

(define-read-only (get-allocation-by-id (allocation-id uint))
  (map-get? allocation-records allocation-id)
)

(define-read-only (get-active-allocation-id
    (sbc (string-ascii 32))
    (token principal))
  (map-get? active-allocation-ids (allocation-key sbc token))
)

(define-read-only (get-category-report
    (period uint)
    (token principal)
    (category uint))
  (let (
      (key (category-key period token category))
      (cap (default-to u0 (map-get? category-caps key)))
      (spent (default-to u0 (map-get? category-spent key)))
      (committed (default-to u0 (map-get? category-commitments key)))
    )
    {
      period: period,
      token: token,
      category: category,
      cap: cap,
      spent: spent,
      committed: committed,
      remaining-cap: (if (>= cap (+ spent committed)) (- cap (+ spent committed)) u0)
    }
  )
)

(define-read-only (get-treasury-health (token principal))
  (let (
      (reserve (default-to u0 (map-get? required-reserves token)))
      (balance (default-to u0 (map-get? tracked-balances token)))
    )
    {
      token: token,
      balance: balance,
      required-reserve: reserve,
      solvent: (>= balance reserve)
    }
  )
)

(define-read-only (get-balance (token principal))
  (default-to u0 (map-get? tracked-balances token))
)

;; @desc Live token-balance report for callers that need on-chain solvency.
;; This is public because Clarity read-only functions cannot make external
;; contract calls. The legacy release path remains the authoritative guard.
(define-public (get-treasury-health-live (token <sip-010-trait>))
  (let (
      (token-principal (contract-of token))
      (reserve (default-to u0 (map-get? required-reserves (contract-of token))))
      (balance (try! (contract-call? token get-balance (as-contract tx-sender))))
    )
    (ok {
      token: token-principal,
      balance: balance,
      required-reserve: reserve,
      solvent: (>= balance reserve)
    })
  )
)

(define-read-only (get-current-period)
  (var-get current-period)
)

(define-read-only (get-category-cap
    (period uint)
    (token principal)
    (category uint))
  (default-to u0 (map-get? category-caps (category-key period token category)))
)

(define-read-only (get-category-spent
    (period uint)
    (token principal)
    (category uint))
  (default-to u0 (map-get? category-spent (category-key period token category)))
)

(define-read-only (get-category-commitment
    (period uint)
    (token principal)
    (category uint))
  (default-to u0 (map-get? category-commitments (category-key period token category)))
)

(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    version: "v1.0.0",
    period: (var-get current-period),
    admin: (var-get admin),
    governance: (var-get governance),
    payment-forge: (var-get payment-forge)
  })
)
