;; founder-vault.clar
;; @desc Founder Vault: A 2-of-3 hardware-backed multisig for the founder's personal protection.
;; @dev This vault is wired to operational-treasury and receives the 0.1% Architect Royalty.
;; @constant ERR_UNAUTHORIZED Error code for unauthorized access.
;; @constant MIN_CONFIRMATIONS The minimum number of signatures required to execute a transaction.
;; @constant ERR_NOT_ENOUGH_CONFIRMATIONS Error code for when there are not enough confirmations.

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant MIN_CONFIRMATIONS u2)
(define-constant ERR_NOT_ENOUGH_CONFIRMATIONS u2000)

;; Guardians (hardware-backed keys) - initialized to tx-sender on deploy, configurable via admin
(define-data-var guardian_1 principal tx-sender)
(define-data-var guardian_2 principal tx-sender)
(define-data-var guardian_3 principal tx-sender)
(define-data-var admin principal tx-sender)

;; Pending transactions
(define-map pending_txs
    uint
    { recipient: principal, amount: uint, confirmed_by: (list 3 principal) }
)

(define-map tx_counter uint uint)

;; Authorization

(define-private (is-guardian (p principal))
    (or
        (is-eq p (var-get guardian_1))
        (is-eq p (var-get guardian_2))
        (is-eq p (var-get guardian_3))
    )
)

(define-private (is-admin)
    (is-eq tx-sender (var-get admin))
)

;; Admin Functions

(define-public (set-guardian-1 (new-guardian principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set guardian_1 new-guardian)
        (ok true)
    )
)

(define-public (set-guardian-2 (new-guardian principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set guardian_2 new-guardian)
        (ok true)
    )
)

(define-public (set-guardian-3 (new-guardian principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set guardian_3 new-guardian)
        (ok true)
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (var-set admin new-admin)
        (ok true)
    )
)

(define-read-only (get-guardians)
    (ok {
        guardian_1: (var-get guardian_1),
        guardian_2: (var-get guardian_2),
        guardian_3: (var-get guardian_3)
    })
)

;; Public Functions

;; @desc Propose a new transaction
(define-public (propose_tx (recipient principal) (amount uint))
    (let
        (
            (tx_id (default-to u0 (map-get? tx_counter u0)))
            (new_tx_id (+ tx_id u1))
        )
        (asserts! (is-guardian tx-sender) (err ERR_UNAUTHORIZED))
        (map-set tx_counter u0 new_tx_id)
        (map-set pending_txs new_tx_id { recipient: recipient, amount: amount, confirmed_by: (list tx-sender) })
        (ok new_tx_id)
    )
)

;; @desc Confirm a transaction
(define-public (confirm_tx (tx_id uint))
    (let
        (
            (tx (unwrap! (map-get? pending_txs tx_id) (err ERR_UNAUTHORIZED)))
            (confirmations (get confirmed_by tx))
        )
        (asserts! (is-guardian tx-sender) (err ERR_UNAUTHORIZED))
        (asserts! (not (is-sender-confirmed tx_id tx-sender)) (err ERR_UNAUTHORIZED))
        (map-set pending_txs tx_id (merge tx { confirmed_by: (unwrap-panic (as-max-len? (append confirmations tx-sender) u3)) }))
        (ok true)
    )
)

;; @desc Execute a transaction
(define-public (execute_tx (tx_id uint))
    (let
        (
            (tx (unwrap! (map-get? pending_txs tx_id) (err ERR_UNAUTHORIZED)))
            (confirmations (get confirmed_by tx))
        )
        (asserts! (>= (len confirmations) MIN_CONFIRMATIONS) (err ERR_NOT_ENOUGH_CONFIRMATIONS))
        (as-contract (stx-transfer? (get amount tx) tx-sender (get recipient tx)))
        (map-delete pending_txs tx_id)
        (ok true)
    )
)

;; Read Only Functions

(define-read-only (is-sender-confirmed (tx_id uint) (sender principal))
    (let
        (
            (tx (unwrap-panic (map-get? pending_txs tx_id)))
            (confirmations (get confirmed_by tx))
        )
        (is-some (index-of confirmations sender))
    )
)

(define-read-only (get-pending-tx (tx_id uint))
    (map-get? pending_txs tx_id)
)
