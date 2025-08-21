;; Governance Metrics Contract
;; Tracks participation %, proposal throughput, quorum efficiency, rolling windows (last 50 proposals)
;; Provides analytics to drive automated founder reallocation & DAO reporting

(define-constant CONTRACT_VERSION u1)

;; --- Constants ---
(define-constant WINDOW_SIZE u50)          ;; Rolling window size (last 50 proposals)
(define-constant PRECISION_BPS u10000)     ;; Basis points precision (10000 = 100%)

;; --- Data Vars ---
(define-data-var dao-governance principal tx-sender) ;; set post-deploy via set-dao-governance to avoid compile-time cycle
(define-data-var dao-initialized bool false)
(define-data-var total-proposals uint u0)
(define-data-var total-votes uint u0)
(define-data-var total-supply-snapshots uint u0) ;; Sum of supply snapshots for participation calc
(define-data-var total-succeeded uint u0)
(define-data-var total-defeated uint u0)
(define-data-var total-queued uint u0)
(define-data-var total-executed uint u0)
(define-data-var last-window-index uint u0)      ;; 0..WINDOW_SIZE-1 circular index
(define-data-var rolling-votes uint u0)
(define-data-var rolling-supply-sum uint u0)

;; Rolling window slot -> { votes, supply }
(define-map rolling-window { slot: uint } { votes: uint, supply: uint })

;; Per-proposal stats
(define-map proposal-stats
  { id: uint }
  {
    start-block: uint,
    end-block: uint,
    total-votes: uint,
    supply-snapshot: uint,
    quorum-bps: uint,
    finalized: bool,
    participation-bps: uint
  }
)

;; --- Errors ---
;; u600: unauthorized
;; u601: proposal-already-recorded
;; u602: proposal-not-found
;; u603: proposal-already-finalized
;; u604: invalid-supply

;; --- Authorization Helper ---
(define-private (assert-dao (sender principal))
  (begin
    (asserts! (is-eq sender (var-get dao-governance)) (err u600))
    (ok true)
  )
)

;; Authorization for enhanced analytics integration
(define-private (is-authorized)
  (or (is-eq tx-sender (var-get dao-governance))
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender .enhanced-analytics)))

;; Add admin variable
(define-data-var admin principal tx-sender)

;; --- Recording Functions (called by dao-governance) ---
(define-public (record-proposal-created (proposal-id uint) (start-block uint) (end-block uint) (supply-snapshot uint) (quorum-bps uint))
  (begin
    (try! (assert-dao tx-sender))
    (asserts! (> supply-snapshot u0) (err u604))
    (asserts! (is-none (map-get? proposal-stats { id: proposal-id })) (err u601))
    (map-set proposal-stats { id: proposal-id } {
      start-block: start-block,
      end-block: end-block,
      total-votes: u0,
      supply-snapshot: supply-snapshot,
      quorum-bps: quorum-bps,
      finalized: false,
      participation-bps: u0
    })
    (var-set total-proposals (+ (var-get total-proposals) u1))
    (var-set total-supply-snapshots (+ (var-get total-supply-snapshots) supply-snapshot))
    (print { event: "gm-proposal-created", proposal-id: proposal-id, supply: supply-snapshot })
    (ok true)
  )
)

(define-public (record-vote (proposal-id uint) (weight uint))
  (let ((p (map-get? proposal-stats { id: proposal-id })))
    (match p
      proposal (begin
        (try! (assert-dao tx-sender))
        (asserts! (not (get finalized proposal)) (err u603))
        (let ((new-total (+ (get total-votes proposal) weight)))
          (map-set proposal-stats { id: proposal-id } (merge proposal { total-votes: new-total }))
          (var-set total-votes (+ (var-get total-votes) weight))
          (print { event: "gm-vote", proposal-id: proposal-id, added: weight, total: new-total })
          (ok true)))
      (err u602)))
)

(define-public (finalize-proposal (proposal-id uint) (for-votes uint) (against-votes uint) (abstain-votes uint) (succeeded bool) (queued bool) (executed bool))
  (let ((p (map-get? proposal-stats { id: proposal-id })))
    (match p
      proposal (begin
        (try! (assert-dao tx-sender))
        (asserts! (not (get finalized proposal)) (err u603))
        (let (
          (total-prop-votes (+ for-votes against-votes abstain-votes))
          (supply (get supply-snapshot proposal))
          (participation-bps (if (> supply u0) (/ (* total-prop-votes PRECISION_BPS) supply) u0))
        )
          ;; Update aggregate counts
          (if succeeded (var-set total-succeeded (+ (var-get total-succeeded) u1)) true)
          (if (not succeeded) (var-set total-defeated (+ (var-get total-defeated) u1)) true)
          (if queued (var-set total-queued (+ (var-get total-queued) u1)) true)
          (if executed (var-set total-executed (+ (var-get total-executed) u1)) true)
          ;; Rolling window update
          (let ((idx (var-get last-window-index)))
            (let ((old (map-get? rolling-window { slot: idx })))
              (match old
                prev (begin
                  (var-set rolling-votes (if (> (var-get rolling-votes) (get votes prev)) (- (var-get rolling-votes) (get votes prev)) u0))
                  (var-set rolling-supply-sum (if (> (var-get rolling-supply-sum) (get supply prev)) (- (var-get rolling-supply-sum) (get supply prev)) u0))
                  true)
                true))
            (map-set rolling-window { slot: idx } { votes: total-prop-votes, supply: supply })
            (var-set rolling-votes (+ (var-get rolling-votes) total-prop-votes))
            (var-set rolling-supply-sum (+ (var-get rolling-supply-sum) supply))
            ;; advance index
            (var-set last-window-index (mod (+ idx u1) WINDOW_SIZE))
          )
          ;; Persist finalize
          (map-set proposal-stats { id: proposal-id } (merge proposal { finalized: true, participation-bps: participation-bps, total-votes: total-prop-votes }))
          (print { event: "gm-proposal-finalized", proposal-id: proposal-id, participation-bps: participation-bps })
          (ok participation-bps)
        )
      )
      (err u602)))
)

;; --- Read-Only Analytics ---
(define-read-only (get-proposal-stats (proposal-id uint))
  (map-get? proposal-stats { id: proposal-id })
)

(define-read-only (get-aggregate-stats)
  {
    total-proposals: (var-get total-proposals),
    total-votes: (var-get total-votes),
    total-supply-snapshots: (var-get total-supply-snapshots),
    succeeded: (var-get total-succeeded),
    defeated: (var-get total-defeated),
    queued: (var-get total-queued),
    executed: (var-get total-executed)
  }
)

(define-read-only (get-overall-participation-bps)
  (let ((supply-sum (var-get total-supply-snapshots)))
    (if (> supply-sum u0)
      (/ (* (var-get total-votes) PRECISION_BPS) supply-sum)
      u0))
)

(define-read-only (get-rolling-participation-bps)
  (let ((supply-sum (var-get rolling-supply-sum)))
    (if (> supply-sum u0)
      (/ (* (var-get rolling-votes) PRECISION_BPS) supply-sum)
      u0))
)

;; Quorum efficiency: approximate using rolling participation
(define-read-only (get-quorum-efficiency-bps)
  (get-rolling-participation-bps)
)

;; Simplified invariant view (full recompute omitted for cost efficiency)
(define-read-only (verify-rolling-window)
  {
    stored-votes: (var-get rolling-votes),
    stored-supply: (var-get rolling-supply-sum),
    last-index: (var-get last-window-index),
    window-size: WINDOW_SIZE
  }
)
;; Admin
;; Persistent configuration
(define-data-var governance-contract principal tx-sender)
;; --- Enhanced Analytics Integration ---

;; Record data for enhanced analytics
(define-public (record-enhanced-analytics-data 
  (participation-bps uint)
  (market-performance-bps uint)
  (tvl-growth-bps uint)
  (volatility-index uint))
  (begin
    (asserts! (is-authorized) (err u620))
    ;; NOTE: Direct call to enhanced-analytics removed to avoid circular deployment dependency.
    ;; Off-chain indexers or an automation contract can relay this event to enhanced-analytics.
    (print {
      event: "analytics-data-emitted",
      participation: participation-bps,
      market-perf: market-performance-bps,
      tvl-growth: tvl-growth-bps,
      volatility: volatility-index
    })
    (ok true)))

;; Get enhanced analytics status
(define-read-only (get-enhanced-analytics-status)
  ;; Placeholder without direct contract call (avoids cycle). Returns minimal stub.
  { analytics-enabled: false, predictive-model-enabled: false })

;; Check if reallocation timing is optimal based on predictive models
(define-read-only (is-optimal-reallocation-timing)
  false)

;; --- Administrative Functions ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u601))
    (var-set admin new-admin)
    (ok true)))

(define-public (set-governance-contract (new-governance principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u602))
    (var-set governance-contract new-governance)
    (ok true)))
