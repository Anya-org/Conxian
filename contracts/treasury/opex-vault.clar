;; @contract opex-vault
;; @desc SIP-010 operating-expense vault with period budgets and N-of-M
;; approvals. Category IDs match fiscal-vault-oracle.clar.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_AMOUNT u1001)
(define-constant ERR_INVALID_CATEGORY u1002)
(define-constant ERR_INVALID_PERIOD u1003)
(define-constant ERR_BUDGET_NOT_SET u1004)
(define-constant ERR_BUDGET_EXCEEDED u1005)
(define-constant ERR_INSUFFICIENT_BALANCE u1006)
(define-constant ERR_NON_COMPLIANT u1007)
(define-constant ERR_EXPENSE_NOT_FOUND u1008)
(define-constant ERR_EXPENSE_NOT_PENDING u1009)
(define-constant ERR_DUPLICATE_APPROVAL u1010)
(define-constant ERR_SELF_APPROVAL u1011)
(define-constant ERR_THRESHOLD_INVALID u1012)
(define-constant ERR_NOT_ENOUGH_APPROVALS u1013)
(define-constant ERR_TRANSFER_FAILED u1014)
(define-constant ERR_NOT_APPROVER u1015)
(define-constant ERR_ADMIN_APPROVER_COLLISION u1016)

(define-constant CATEGORY_MIN u1)
(define-constant CATEGORY_MAX u8)
(define-constant EXPENSE_PENDING u0)
(define-constant EXPENSE_EXECUTED u1)
(define-constant EXPENSE_CANCELLED u2)

(define-data-var admin principal tx-sender)
(define-data-var governance principal tx-sender)
(define-data-var current-period uint u1)
(define-data-var next-expense-id uint u1)
(define-data-var approval-threshold uint u1)
(define-data-var approver-count uint u1)

;; The administrator is an implicit approver. This keeps a fresh deployment
;; usable while still allowing the approver set to be expanded or rotated.
(define-map approvers principal bool)
(define-map vault-balances principal uint)
(define-map total-reserved principal uint)

(define-map category-budgets
  { period: uint, token: principal, category: uint }
  uint
)

(define-map category-spent
  { period: uint, token: principal, category: uint }
  uint
)

(define-map category-reserved
  { period: uint, token: principal, category: uint }
  uint
)

(define-map expenses
  uint
  {
    id: uint,
    period: uint,
    token: principal,
    category: uint,
    amount: uint,
    payee: principal,
    memo: (string-ascii 128),
    submitter: principal,
    status: uint,
    approvals: uint
  }
)

(define-map expense-approvals
  { expense-id: uint, approver: principal }
  bool
)

(define-map expense-approval-count uint uint)

(define-private (is-valid-category (category uint))
  (and (>= category CATEGORY_MIN) (<= category CATEGORY_MAX))
)

(define-private (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

(define-private (is-config-authorized)
  (or (is-admin contract-caller) (is-eq contract-caller (var-get governance)))
)

(define-private (is-approver (caller principal))
  (or
    (is-eq caller (var-get admin))
    (default-to false (map-get? approvers caller))
  )
)

(define-private (is-execution-authorized)
  (or
    (is-config-authorized)
    (is-approver contract-caller)
  )
)

(define-private (category-key (period uint) (token principal) (category uint))
  { period: period, token: token, category: category }
)

;; @desc Updates admin and governance actors.
(define-public (set-authorized-principals
    (new-admin principal)
    (new-governance principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (asserts!
      (not (default-to false (map-get? approvers new-admin)))
      (err ERR_ADMIN_APPROVER_COLLISION))
    (var-set admin new-admin)
    (var-set governance new-governance)
    (print {
      event: "opex-authorized-principals-updated",
      admin: new-admin,
      governance: new-governance,
      block-height: block-height
    })
    (ok true)
  )
)

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (asserts!
      (not (default-to false (map-get? approvers new-admin)))
      (err ERR_ADMIN_APPROVER_COLLISION))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin contract-caller) (err ERR_UNAUTHORIZED))
    (asserts!
      (not (default-to false (map-get? approvers new-admin)))
      (err ERR_ADMIN_APPROVER_COLLISION))
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

(define-public (set-current-period (new-period uint))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (> new-period u0) (err ERR_INVALID_PERIOD))
    (asserts! (>= new-period (var-get current-period)) (err ERR_INVALID_PERIOD))
    (var-set current-period new-period)
    (print {
      event: "opex-period-updated",
      period: new-period,
      block-height: block-height
    })
    (ok true)
  )
)

;; @desc Adds or removes a non-admin approver.
(define-public (set-approver (approver principal) (active bool))
  (let ((currently-active (default-to false (map-get? approvers approver))))
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (not (is-eq approver (var-get admin))) (err ERR_DUPLICATE_APPROVAL))
      (if active
        (begin
          (asserts! (not currently-active) (err ERR_DUPLICATE_APPROVAL))
          (map-set approvers approver true)
          (var-set approver-count (+ (var-get approver-count) u1))
          (ok true)
        )
        (begin
          (asserts! currently-active (err ERR_NOT_APPROVER))
          (asserts! (>= (- (var-get approver-count) u1) (var-get approval-threshold)) (err ERR_THRESHOLD_INVALID))
          (map-set approvers approver false)
          (var-set approver-count (- (var-get approver-count) u1))
          (ok true)
        )
      )
    )
  )
)

(define-public (set-approval-threshold (threshold uint))
  (begin
    (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
    (asserts! (> threshold u0) (err ERR_THRESHOLD_INVALID))
    (asserts! (<= threshold (var-get approver-count)) (err ERR_THRESHOLD_INVALID))
    (var-set approval-threshold threshold)
    (print {
      event: "opex-approval-threshold-updated",
      threshold: threshold,
      block-height: block-height
    })
    (ok true)
  )
)

;; @desc Deposits a SIP-010 token into the vault.
(define-public (deposit (token <sip-010-trait>) (amount uint))
  (let (
      (token-principal (contract-of token))
      (current-balance (default-to u0 (map-get? vault-balances (contract-of token))))
    )
    (begin
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      ;; State is written only after the token transfer succeeds.
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      (map-set vault-balances token-principal (+ current-balance amount))
      (print {
        event: "opex-deposit",
        token: token-principal,
        amount: amount,
        depositor: tx-sender,
        block-height: block-height
      })
      (ok true)
    )
  )
)

(define-public (set-category-budget
    (token principal)
    (category uint)
    (budget uint))
  (let (
      (period (var-get current-period))
      (key (category-key (var-get current-period) token category))
      (spent (default-to u0 (map-get? category-spent key)))
      (reserved (default-to u0 (map-get? category-reserved key)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (asserts! (>= budget (+ spent reserved)) (err ERR_BUDGET_EXCEEDED))
      (map-set category-budgets { period: period, token: token, category: category } budget)
      (print {
        event: "opex-category-budget-updated",
        period: period,
        token: token,
        category: category,
        budget: budget,
        block-height: block-height
      })
      (ok true)
    )
  )
)

(define-public (set-category-budget-for-period
    (period uint)
    (token principal)
    (category uint)
    (budget uint))
  (let (
      (key (category-key period token category))
      (spent (default-to u0 (map-get? category-spent key)))
      (reserved (default-to u0 (map-get? category-reserved key)))
    )
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (asserts! (> period u0) (err ERR_INVALID_PERIOD))
      (asserts! (>= period (var-get current-period)) (err ERR_INVALID_PERIOD))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (asserts! (>= budget (+ spent reserved)) (err ERR_BUDGET_EXCEEDED))
      (map-set category-budgets key budget)
      (ok true)
    )
  )
)

;; @desc Creates a pending expense and reserves its amount immediately.
(define-public (create-expense
    (token <sip-010-trait>)
    (category uint)
    (amount uint)
    (payee principal)
    (memo (string-ascii 128)))
  (let (
      (token-principal (contract-of token))
      (period (var-get current-period))
      (key (category-key (var-get current-period) (contract-of token) category))
      (budget (default-to u0 (map-get? category-budgets key)))
      (spent (default-to u0 (map-get? category-spent key)))
      (reserved (default-to u0 (map-get? category-reserved key)))
      (balance (default-to u0 (map-get? vault-balances (contract-of token))))
      (total-reserved-value (default-to u0 (map-get? total-reserved (contract-of token))))
      (expense-id (var-get next-expense-id))
    )
    (begin
      (asserts! (or (is-config-authorized) (is-approver contract-caller)) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (is-valid-category category) (err ERR_INVALID_CATEGORY))
      (asserts! (> budget u0) (err ERR_BUDGET_NOT_SET))
      (asserts! (<= (+ spent (+ reserved amount)) budget) (err ERR_BUDGET_EXCEEDED))
      (asserts! (>= balance (+ reserved amount)) (err ERR_INSUFFICIENT_BALANCE))
      ;; Reservations are global per token, not isolated by category. Keep the
      ;; tracked vault balance solvent after adding this expense.
      (asserts! (>= balance (+ total-reserved-value amount)) (err ERR_INSUFFICIENT_BALANCE))
      (asserts!
        (unwrap!
          (contract-call? .regulatory-adapter check-clean-hands-compliance payee)
          (err ERR_NON_COMPLIANT))
        (err ERR_NON_COMPLIANT))
      (map-set expenses expense-id {
        id: expense-id,
        period: period,
        token: token-principal,
        category: category,
        amount: amount,
        payee: payee,
        memo: memo,
        ;; Preserve the immediate authorized caller across nested calls. This
        ;; prevents a configured approver contract from submitting and then
        ;; approving its own expense on behalf of the transaction origin.
        submitter: contract-caller,
        status: EXPENSE_PENDING,
        approvals: u0
      })
      (map-set expense-approval-count expense-id u0)
      (map-set category-reserved key (+ reserved amount))
      (map-set total-reserved token-principal
        (+ (default-to u0 (map-get? total-reserved token-principal)) amount))
      (var-set next-expense-id (+ expense-id u1))
      (print {
        event: "opex-expense-created",
        expense-id: expense-id,
        token: token-principal,
        category: category,
        amount: amount,
        payee: payee,
        block-height: block-height
      })
      (ok expense-id)
    )
  )
)

(define-public (approve-expense (expense-id uint))
  (let ((expense (map-get? expenses expense-id)))
    (begin
      (asserts! (is-approver contract-caller) (err ERR_NOT_APPROVER))
      (match expense
        expense-data
          (begin
            (asserts! (is-eq (get status expense-data) EXPENSE_PENDING) (err ERR_EXPENSE_NOT_PENDING))
            (asserts! (not (is-eq contract-caller (get submitter expense-data))) (err ERR_SELF_APPROVAL))
            (asserts!
              (not (default-to false (map-get? expense-approvals { expense-id: expense-id, approver: contract-caller })))
              (err ERR_DUPLICATE_APPROVAL))
            (map-set expense-approvals { expense-id: expense-id, approver: contract-caller } true)
            (map-set expense-approval-count expense-id
              (+ (default-to u0 (map-get? expense-approval-count expense-id)) u1))
            (map-set expenses expense-id {
              id: (get id expense-data),
              period: (get period expense-data),
              token: (get token expense-data),
              category: (get category expense-data),
              amount: (get amount expense-data),
              payee: (get payee expense-data),
              memo: (get memo expense-data),
              submitter: (get submitter expense-data),
              status: EXPENSE_PENDING,
              approvals: (+ (get approvals expense-data) u1)
            })
            (print {
              event: "opex-expense-approved",
              expense-id: expense-id,
              approver: contract-caller,
              block-height: block-height
            })
            (ok true)
          )
        (err ERR_EXPENSE_NOT_FOUND)
      )
    )
  )
)

(define-public (execute-expense (expense-id uint) (token <sip-010-trait>))
  (let ((expense (map-get? expenses expense-id)))
    (begin
      (asserts! (is-execution-authorized) (err ERR_UNAUTHORIZED))
      (match expense
        expense-data
          (let (
              (token-principal (contract-of token))
              (category-key-value (category-key (get period expense-data) (get token expense-data) (get category expense-data)))
              (budget (default-to u0 (map-get? category-budgets category-key-value)))
              (spent (default-to u0 (map-get? category-spent category-key-value)))
              (reserved (default-to u0 (map-get? category-reserved category-key-value)))
              (total-reserved-value (default-to u0 (map-get? total-reserved token-principal)))
              (balance (default-to u0 (map-get? vault-balances token-principal)))
              (live-balance (try! (contract-call? token get-balance (as-contract tx-sender))))
            )
            (begin
              (asserts! (is-eq (get status expense-data) EXPENSE_PENDING) (err ERR_EXPENSE_NOT_PENDING))
              (asserts! (is-eq token-principal (get token expense-data)) (err ERR_TRANSFER_FAILED))
              (asserts! (>= (get approvals expense-data) (var-get approval-threshold)) (err ERR_NOT_ENOUGH_APPROVALS))
              (asserts! (> budget u0) (err ERR_BUDGET_NOT_SET))
              (asserts! (<= (+ spent (get amount expense-data)) budget) (err ERR_BUDGET_EXCEEDED))
              (asserts! (>= reserved (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              (asserts! (>= total-reserved-value (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              ;; Tracked balances protect the internal ledger; the live token
              ;; balance protects against direct outflows or other balance
              ;; drift that the vault did not record. Both balances must cover
              ;; every outstanding reservation before one can execute.
              (asserts! (>= balance total-reserved-value) (err ERR_INSUFFICIENT_BALANCE))
              (asserts! (>= balance (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              (asserts! (>= live-balance total-reserved-value) (err ERR_INSUFFICIENT_BALANCE))
              (asserts! (>= live-balance (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              (asserts!
                (unwrap!
                  (contract-call? .regulatory-adapter check-clean-hands-compliance (get payee expense-data))
                  (err ERR_NON_COMPLIANT))
                (err ERR_NON_COMPLIANT))
              (try! (as-contract (contract-call? token transfer (get amount expense-data) tx-sender (get payee expense-data) none)))
              (map-set vault-balances token-principal (- balance (get amount expense-data)))
              (map-set category-reserved category-key-value (- reserved (get amount expense-data)))
              (map-set total-reserved token-principal (- total-reserved-value (get amount expense-data)))
              (map-set category-spent category-key-value (+ spent (get amount expense-data)))
              (map-set expenses expense-id {
                id: (get id expense-data),
                period: (get period expense-data),
                token: token-principal,
                category: (get category expense-data),
                amount: (get amount expense-data),
                payee: (get payee expense-data),
                memo: (get memo expense-data),
                submitter: (get submitter expense-data),
                status: EXPENSE_EXECUTED,
                approvals: (get approvals expense-data)
              })
              (print {
                event: "opex-expense-executed",
                expense-id: expense-id,
                token: token-principal,
                amount: (get amount expense-data),
                payee: (get payee expense-data),
                block-height: block-height
              })
              (ok true)
            )
          )
        (err ERR_EXPENSE_NOT_FOUND)
      )
    )
  )
)

(define-public (cancel-expense (expense-id uint))
  (let ((expense (map-get? expenses expense-id)))
    (begin
      (asserts! (is-config-authorized) (err ERR_UNAUTHORIZED))
      (match expense
        expense-data
          (let (
              (token-principal (get token expense-data))
              (category-key-value (category-key (get period expense-data) (get token expense-data) (get category expense-data)))
              (reserved (default-to u0 (map-get? category-reserved category-key-value)))
              (total-reserved-value (default-to u0 (map-get? total-reserved token-principal)))
            )
            (begin
              (asserts! (is-eq (get status expense-data) EXPENSE_PENDING) (err ERR_EXPENSE_NOT_PENDING))
              (asserts! (>= reserved (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              (asserts! (>= total-reserved-value (get amount expense-data)) (err ERR_INSUFFICIENT_BALANCE))
              (map-set category-reserved category-key-value (- reserved (get amount expense-data)))
              (map-set total-reserved token-principal (- total-reserved-value (get amount expense-data)))
              (map-set expenses expense-id {
                id: (get id expense-data),
                period: (get period expense-data),
                token: token-principal,
                category: (get category expense-data),
                amount: (get amount expense-data),
                payee: (get payee expense-data),
                memo: (get memo expense-data),
                submitter: (get submitter expense-data),
                status: EXPENSE_CANCELLED,
                approvals: (get approvals expense-data)
              })
              (print {
                event: "opex-expense-cancelled",
                expense-id: expense-id,
                token: token-principal,
                block-height: block-height
              })
              (ok true)
            )
          )
        (err ERR_EXPENSE_NOT_FOUND)
      )
    )
  )
)

(define-read-only (get-vault-balance (token principal))
  (default-to u0 (map-get? vault-balances token))
)

(define-read-only (get-balance (token principal))
  (default-to u0 (map-get? vault-balances token))
)

(define-read-only (get-expense (expense-id uint))
  (map-get? expenses expense-id)
)

(define-read-only (get-expense-approval
    (expense-id uint)
    (approver principal))
  (default-to false (map-get? expense-approvals { expense-id: expense-id, approver: approver }))
)

(define-read-only (get-category-report
    (period uint)
    (token principal)
    (category uint))
  (let (
      (key (category-key period token category))
      (budget (default-to u0 (map-get? category-budgets key)))
      (spent (default-to u0 (map-get? category-spent key)))
      (reserved (default-to u0 (map-get? category-reserved key)))
    )
    {
      period: period,
      token: token,
      category: category,
      budget: budget,
      spent: spent,
      reserved: reserved,
      remaining-budget: (if (>= budget (+ spent reserved)) (- budget (+ spent reserved)) u0)
    }
  )
)

(define-read-only (get-summary (token principal))
  (let (
      (balance (default-to u0 (map-get? vault-balances token)))
      (reserved (default-to u0 (map-get? total-reserved token)))
    )
    {
      token: token,
      balance: balance,
      tracked-balance: balance,
      reserved: reserved,
      available: (if (>= balance reserved) (- balance reserved) u0),
      available-tracked: (if (>= balance reserved) (- balance reserved) u0),
      period: (var-get current-period)
    }
  )
)

;; @desc Reports both the internal tracked balance and the live SIP-010
;; balance. Direct token transfers may increase live-balance without becoming
;; spendable tracked funds until a deposit records them.
(define-public (get-summary-live (token <sip-010-trait>))
  (let (
      (token-principal (contract-of token))
      (tracked-balance (default-to u0 (map-get? vault-balances (contract-of token))))
      (reserved (default-to u0 (map-get? total-reserved (contract-of token))))
      (live-balance (try! (contract-call? token get-balance (as-contract tx-sender))))
    )
    (ok {
      token: token-principal,
      tracked-balance: tracked-balance,
      live-balance: live-balance,
      reserved: reserved,
      available-tracked: (if (>= tracked-balance reserved) (- tracked-balance reserved) u0),
      available-live: (if (>= live-balance reserved) (- live-balance reserved) u0),
      tracked-solvent: (>= tracked-balance reserved),
      live-solvent: (>= live-balance reserved),
      period: (var-get current-period)
    })
  )
)

(define-read-only (get-current-period)
  (var-get current-period)
)

(define-read-only (get-approval-threshold)
  (var-get approval-threshold)
)

(define-read-only (is-approver-address (approver principal))
  (is-approver approver)
)

(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    version: "v1.0.0",
    period: (var-get current-period),
    admin: (var-get admin),
    governance: (var-get governance),
    approval-threshold: (var-get approval-threshold),
    approver-count: (var-get approver-count)
  })
)
