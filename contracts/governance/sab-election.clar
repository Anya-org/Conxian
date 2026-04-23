;; sab-election.clar
;; @desc On-chain epoch elections for the 7-member Sovereign Autonomous Business (SAB) committee.
;; @param epoch The current epoch number.
;; @param nominations The list of nominated principals for the SAB.
;; @param votes The map of principals to their vote counts.
;; @param sab_members The list of elected SAB members for the current epoch.

(define-constant EPOCH_LENGTH u525600)
(define-constant SAB_SIZE u7)
(define-constant MIN_VOTE_THRESHOLD u100)

(define-map epochs
    uint
    { start_height: uint, end_height: uint, status: (string-ascii 20) }
)

(define-map nominations
    uint
    (list 100 { principal: principal, votes: uint })
)

(define-map votes
    { epoch: uint, principal: principal }
    uint
)

(define-map sab_members
    uint
    (list 7 principal)
)

(define-read-only (get-epoch-status (epoch uint))
    (ok (map-get? epochs epoch))
)

(define-public (nominate (epoch uint) (nominee principal))
    (let
        (
            (current_epoch (get-current-epoch))
            (nomination_list (default-to (list) (map-get? nominations epoch)))
        )
        (asserts! (is-eq current_epoch epoch) (err u100))
        (ok (map-set nominations epoch (unwrap-panic (as-max-len? (append nomination_list { principal: nominee, votes: u0 }) u100))))
    )
)

(define-public (vote (epoch uint) (candidate principal) (amount uint))
    (let
        (
            (current_epoch (get-current-epoch))
            (current_votes (default-to u0 (map-get? votes { epoch: epoch, principal: candidate })))
        )
        (asserts! (is-eq current_epoch epoch) (err u100))
        (asserts! (>= amount MIN_VOTE_THRESHOLD) (err u101))
        (ok (map-set votes { epoch: epoch, principal: candidate } (+ current_votes amount)))
    )
)

(define-public (close-nominations (epoch uint))
    (let
        (
            (current_epoch (get-current-epoch))
            (nomination_list (default-to (list) (map-get? nominations epoch)))
            (sorted_nominees (sort-nominations nomination_list))
            (elected (get result (slice sorted_nominees u0 SAB_SIZE)))
        )
        (asserts! (is-eq current_epoch epoch) (err u100))
        (ok (map-set sab_members epoch elected))
    )
)

(define-read-only (get-elected-sab (epoch uint))
    (ok (map-get? sab_members epoch))
)

(define-read-only (get-current-epoch)
    (/ stacks-block-height EPOCH_LENGTH)
)

(define-read-only (sort-nominations (nominees (list 100 { principal: principal, votes: uint })))
    (fold sort-by-votes nominees)
)

(define-read-only (sort-by-votes (a { principal: principal, votes: uint }) (b (list 100 { principal: principal, votes: uint })))
    (let
        (
            (a_votes (get votes a))
            (b_len (len b))
        )
        (if (or (is-eq b_len u0) (> a_votes (unwrap-panic (get votes (element-at b u0)))))
            (unwrap-panic (as-max-len? (append b a) u100))
            b
        )
    )
)

(define-read-only (slice (lst (list 100 { principal: principal, votes: uint })) (start uint) (end uint))
    (fold
        (lambda (item acc)
            (let
                (
                    (idx (get index acc))
                    (result (get result acc))
                )
                (if (and (>= idx start) (< idx end))
                    { index: (+ idx u1), result: (unwrap-panic (as-max-len? (append result item) u100)) }
                    { index: (+ idx u1), result: result }
                )
            )
        )
        lst
        { index: u0, result: (list) }
    )
)
