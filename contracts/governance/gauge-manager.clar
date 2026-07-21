;; gauge-manager.clar
;; Canonical escrowed gauge voting and historical weight registry.
;;
;; `gauge-orchestrator.clar` is an older compatibility surface and must not be
;; treated as a parallel source of emission truth. This contract records vote
;; weights only; it does not call token-emission-controller or distribute
;; emissions because that controller currently does not mint/distribute here.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant BPS u10000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_BLOCK_WINDOW u1000000)

(define-constant ERR_UNAUTHORIZED u1200)
(define-constant ERR_INVALID_TOKEN u1201)
(define-constant ERR_GAUGE_EXISTS u1202)
(define-constant ERR_GAUGE_NOT_FOUND u1203)
(define-constant ERR_INVALID_CAP u1204)
(define-constant ERR_GAUGE_DISABLED u1205)
(define-constant ERR_INVALID_EPOCH_LENGTH u1206)
(define-constant ERR_EPOCH_ENDED u1207)
(define-constant ERR_EPOCH_NOT_ENDED u1208)
(define-constant ERR_ZERO_AMOUNT u1209)
(define-constant ERR_DUPLICATE_VOTE u1210)
(define-constant ERR_EPOCH_NOT_FINALIZED u1211)
(define-constant ERR_ALREADY_CLAIMED u1212)
(define-constant ERR_ARITHMETIC_OVERFLOW u1213)

(define-data-var admin principal tx-sender)
(define-data-var voting-token principal tx-sender)
(define-data-var epoch-length uint u2016)
(define-data-var next-epoch-length uint u2016)
(define-data-var epoch-start uint u0)
(define-data-var epoch-end uint u0)
(define-data-var current-epoch uint u0)
(define-data-var epoch-initialized bool false)

(define-map gauges principal {
  metadata-hash: (buff 32),
  cap-bps: uint,
  enabled: bool
})

(define-map epoch-gauge-weights { epoch: uint, gauge: principal } uint)
(define-map epoch-gauge-caps { epoch: uint, gauge: principal } uint)
(define-map epoch-gauge-eligibility { epoch: uint, gauge: principal } bool)
(define-map epoch-voting-tokens uint principal)
(define-map epoch-total-votes uint uint)
(define-map user-epoch-totals { epoch: uint, voter: principal } uint)
(define-map votes { epoch: uint, voter: principal, gauge: principal } {
  amount: uint,
  claimed: bool
})
(define-map finalized-epochs uint bool)

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-token-configured (token <sip-010-ft-trait>))
  (is-eq (contract-of token) (var-get voting-token))
)

(define-private (is-token-valid-for-epoch (epoch uint) (token <sip-010-ft-trait>))
  (match (map-get? epoch-voting-tokens epoch)
    bound-token (is-eq (contract-of token) bound-token)
    (is-token-configured token)
  )
)

(define-private (safe-add-blocks (base uint) (window uint))
  (if (> window (- MAX_UINT base))
    none
    (some (+ base window))
  )
)

(define-private (current-boundary)
  (var-get epoch-end)
)

(define-private (raw-relative-weight (epoch uint) (gauge principal))
  (let ((total (default-to u0 (map-get? epoch-total-votes epoch))))
    (if (> total u0)
      (/ (* (default-to u0 (map-get? epoch-gauge-weights { epoch: epoch, gauge: gauge })) BPS) total)
      u0
    )
  )
)

;; @desc Update administrator.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Configure the principal that must back gauge token trait calls.
(define-public (set-voting-token (token principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set voting-token token)
    (print { event: "gauge-voting-token-configured", token: token })
    (ok true)
  )
)

;; @desc Set a positive burn-block epoch length.
;; Once the first epoch is initialized, this schedules the length for the next
;; epoch only. The current epoch-end is immutable, including after votes land.
(define-public (set-epoch-length (new-epoch-length uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> new-epoch-length u0) (err ERR_INVALID_EPOCH_LENGTH))
    (asserts! (<= new-epoch-length MAX_BLOCK_WINDOW) (err ERR_INVALID_EPOCH_LENGTH))
    (if (not (var-get epoch-initialized))
      (let ((new-end (unwrap! (safe-add-blocks burn-block-height new-epoch-length) (err ERR_INVALID_EPOCH_LENGTH))))
        (begin
          (var-set epoch-start burn-block-height)
          (var-set epoch-end new-end)
          (var-set epoch-length new-epoch-length)
          (var-set next-epoch-length new-epoch-length)
          (var-set epoch-initialized true)
        )
      )
      (var-set next-epoch-length new-epoch-length)
    )
    (print { event: "gauge-epoch-length-updated", epoch-length: new-epoch-length })
    (ok true)
  )
)

;; @desc Register a gauge with metadata and an optional relative-weight cap.
(define-public (register-gauge
    (gauge principal)
    (metadata-hash (buff 32))
    (cap-bps uint)
  )
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (<= cap-bps BPS) (err ERR_INVALID_CAP))
    (asserts! (is-none (map-get? gauges gauge)) (err ERR_GAUGE_EXISTS))
    (map-set gauges gauge {
      metadata-hash: metadata-hash,
      cap-bps: cap-bps,
      enabled: true
    })
    (print { event: "gauge-registered", gauge: gauge, metadata-hash: metadata-hash, cap-bps: cap-bps })
    (ok true)
  )
)

;; @desc Enable or disable a registered gauge for the current epoch.
(define-public (set-gauge-enabled (gauge principal) (enabled bool))
  (let ((gauge-data (unwrap! (map-get? gauges gauge) (err ERR_GAUGE_NOT_FOUND))))
    (begin
      (asserts! (is-admin) (err ERR_UNAUTHORIZED))
      (map-set gauges gauge (merge gauge-data { enabled: enabled }))
      (map-set epoch-gauge-eligibility { epoch: (var-get current-epoch), gauge: gauge } enabled)
      (print { event: "gauge-enabled-updated", gauge: gauge, enabled: enabled })
      (ok true)
    )
  )
)

;; @desc Update a gauge cap without modifying historical epochs.
(define-public (set-gauge-cap (gauge principal) (cap-bps uint))
  (let ((gauge-data (unwrap! (map-get? gauges gauge) (err ERR_GAUGE_NOT_FOUND))))
    (begin
      (asserts! (is-admin) (err ERR_UNAUTHORIZED))
      (asserts! (<= cap-bps BPS) (err ERR_INVALID_CAP))
      (map-set gauges gauge (merge gauge-data { cap-bps: cap-bps }))
      (print { event: "gauge-cap-updated", gauge: gauge, cap-bps: cap-bps })
      (ok true)
    )
  )
)

;; @desc Escrow one positive vote per voter/gauge/epoch.
(define-public (vote-gauge
    (gauge principal)
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    (let (
        (epoch (var-get current-epoch))
        (gauge-data (unwrap! (map-get? gauges gauge) (err ERR_GAUGE_NOT_FOUND)))
        (vote-key { epoch: epoch, voter: tx-sender, gauge: gauge })
        (current-epoch-total (default-to u0 (map-get? epoch-total-votes epoch)))
      )
      (begin
        (asserts! (is-token-valid-for-epoch epoch token) (err ERR_INVALID_TOKEN))
        (asserts! (get enabled gauge-data) (err ERR_GAUGE_DISABLED))
        (asserts! (< burn-block-height (current-boundary)) (err ERR_EPOCH_ENDED))
        (asserts! (is-none (map-get? votes vote-key)) (err ERR_DUPLICATE_VOTE))
        (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
        ;; Keep every aggregate at or below MAX_UINT / BPS so the canonical
        ;; relative-weight calculation can multiply by BPS without overflow.
        (asserts! (<= current-epoch-total (/ MAX_UINT BPS)) (err ERR_ARITHMETIC_OVERFLOW))
        (asserts! (<= amount (- (/ MAX_UINT BPS) current-epoch-total)) (err ERR_ARITHMETIC_OVERFLOW))
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (let (
            (current-gauge-weight (default-to u0 (map-get? epoch-gauge-weights { epoch: epoch, gauge: gauge })))
            (current-user-total (default-to u0 (map-get? user-epoch-totals { epoch: epoch, voter: tx-sender })))
          )
          (begin
            (map-set votes vote-key { amount: amount, claimed: false })
            (if (is-none (map-get? epoch-voting-tokens epoch))
              (map-set epoch-voting-tokens epoch (contract-of token))
              true
            )
            (if (is-none (map-get? epoch-gauge-eligibility { epoch: epoch, gauge: gauge }))
              (map-set epoch-gauge-eligibility { epoch: epoch, gauge: gauge } true)
              true
            )
            (if (is-none (map-get? epoch-gauge-caps { epoch: epoch, gauge: gauge }))
              (map-set epoch-gauge-caps { epoch: epoch, gauge: gauge } (get cap-bps gauge-data))
              true
            )
            (map-set epoch-gauge-weights { epoch: epoch, gauge: gauge } (+ current-gauge-weight amount))
            (map-set epoch-total-votes epoch (+ current-epoch-total amount))
            (map-set user-epoch-totals { epoch: epoch, voter: tx-sender } (+ current-user-total amount))
            (print {
              event: "gauge-vote-cast",
              epoch: epoch,
              gauge: gauge,
              voter: tx-sender,
              amount: amount,
              epoch-total: (+ current-epoch-total amount)
            })
            (ok true)
          )
        )
      )
    )
  )
)

;; @desc Finalize the current epoch permissionlessly at or after its boundary.
(define-public (advance-epoch)
  (let (
      (epoch (var-get current-epoch))
      (boundary (current-boundary))
      (next-length (var-get next-epoch-length))
      (next-end (unwrap! (safe-add-blocks boundary (var-get next-epoch-length)) (err ERR_INVALID_EPOCH_LENGTH)))
    )
    (begin
      (asserts! (var-get epoch-initialized) (err ERR_INVALID_EPOCH_LENGTH))
      (asserts! (>= burn-block-height boundary) (err ERR_EPOCH_NOT_ENDED))
      ;; Epoch identifiers are monotonic; reject the terminal value before
      ;; advancing it so the next identifier cannot wrap.
      (asserts! (< epoch MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
      ;; Finalized weight maps are never written again. The next epoch uses a
      ;; distinct key and starts at the scheduled boundary, not at call time.
      (map-set finalized-epochs epoch true)
      (var-set current-epoch (+ epoch u1))
      (var-set epoch-start boundary)
      (var-set epoch-length next-length)
      (var-set epoch-end next-end)
      (print {
        event: "gauge-epoch-finalized",
        epoch: epoch,
        epoch-total: (default-to u0 (map-get? epoch-total-votes epoch)),
        finalized-at: burn-block-height,
        next-epoch: (+ epoch u1)
      })
      (ok epoch)
    )
  )
)

;; @desc Withdraw one vote's escrow after its epoch has finalized.
(define-public (withdraw-vote
    (epoch uint)
    (gauge principal)
    (token <sip-010-ft-trait>)
  )
  (begin
    (let (
        (vote-key { epoch: epoch, voter: tx-sender, gauge: gauge })
        (voter tx-sender)
        (vote-data (unwrap! (map-get? votes vote-key) (err ERR_ALREADY_CLAIMED)))
      )
      (begin
        (asserts! (match (map-get? epoch-voting-tokens epoch)
          bound-token (is-eq (contract-of token) bound-token)
          false
        ) (err ERR_INVALID_TOKEN))
        (asserts! (default-to false (map-get? finalized-epochs epoch)) (err ERR_EPOCH_NOT_FINALIZED))
        (asserts! (not (get claimed vote-data)) (err ERR_ALREADY_CLAIMED))
        (try! (as-contract (contract-call? token transfer (get amount vote-data) tx-sender voter none)))
        (map-set votes vote-key (merge vote-data { claimed: true }))
        (print { event: "gauge-vote-withdrawn", epoch: epoch, gauge: gauge, voter: voter, amount: (get amount vote-data) })
        (ok (get amount vote-data))
      )
    )
  )
)

(define-read-only (get-config)
  {
    admin: (var-get admin),
    voting-token: (var-get voting-token),
    epoch-length: (var-get epoch-length),
    next-epoch-length: (var-get next-epoch-length),
    epoch-start: (var-get epoch-start),
    epoch-end: (var-get epoch-end),
    current-epoch: (var-get current-epoch),
    epoch-initialized: (var-get epoch-initialized)
  }
)

(define-read-only (get-gauge (gauge principal))
  (map-get? gauges gauge)
)

(define-read-only (get-vote (epoch uint) (voter principal) (gauge principal))
  (map-get? votes { epoch: epoch, voter: voter, gauge: gauge })
)

(define-read-only (get-user-epoch-total (epoch uint) (voter principal))
  (default-to u0 (map-get? user-epoch-totals { epoch: epoch, voter: voter }))
)

(define-read-only (get-epoch-total (epoch uint))
  (default-to u0 (map-get? epoch-total-votes epoch))
)

(define-read-only (get-raw-relative-weight (epoch uint) (gauge principal))
  (raw-relative-weight epoch gauge)
)

;; Caps are applied after raw relative-weight calculation. Capped weights do
;; not get redistributed, so enabled gauges may leave emission weight unused.
(define-read-only (get-capped-relative-weight (epoch uint) (gauge principal))
  (if (match (map-get? epoch-gauge-eligibility { epoch: epoch, gauge: gauge })
        eligible eligible
        (if (is-eq epoch (var-get current-epoch))
          (match (map-get? gauges gauge)
            gauge-data (get enabled gauge-data)
            false
          )
          false
        )
      )
    (match (map-get? gauges gauge)
      gauge-data
        (let (
            (raw (raw-relative-weight epoch gauge))
            (cap (default-to (get cap-bps gauge-data) (map-get? epoch-gauge-caps { epoch: epoch, gauge: gauge })))
          )
          (if (> raw cap) cap raw)
        )
      u0
    )
    u0
  )
)

(define-read-only (is-epoch-finalized (epoch uint))
  (default-to false (map-get? finalized-epochs epoch))
)
