;; mock-settlement-intermediary.clar
;; Test-only caller used to prove authorization and cross-contract rollback.

(use-trait native-stacking-operator-trait .stacking-traits.native-stacking-operator-trait)
(use-trait pox-adapter-trait .stacking-traits.pox-adapter-trait)

(define-constant ERR_FORCED_FAILURE (err u9300))

(define-public (attempt-bind-btc
    (operator <native-stacking-operator-trait>)
    (commit-id uint)
    (proof-hash (buff 32))
    (amount uint)
  )
  (begin
    (try! (contract-call? operator bind-btc-settlement commit-id proof-hash amount))
    ERR_FORCED_FAILURE
  )
)

(define-public (bind-btc
    (operator <native-stacking-operator-trait>)
    (commit-id uint)
    (proof-hash (buff 32))
    (amount uint)
  )
  (contract-call? operator bind-btc-settlement commit-id proof-hash amount)
)

(define-public (attempt-bind-commit
    (operator <native-stacking-operator-trait>)
    (commit-id uint)
  )
  (contract-call? operator bind-commit commit-id)
)

(define-public (finalize-commit
    (operator <native-stacking-operator-trait>)
    (commit-id uint)
    (adapter <pox-adapter-trait>)
  )
  (contract-call? operator finalize-commit commit-id adapter)
)
