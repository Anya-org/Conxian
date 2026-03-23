;; economic-policy-engine.clar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

;; @desc Get the current protocol interest rate
(define-read-only (get-current-interest-rate) (ok u500)) ;; 5%

;; @desc Get the protocol reserve factor
(define-read-only (get-reserve-factor) (ok u1000)) ;; 10%

;; @desc Get the principal of the revenue distributor
(define-read-only (get-revenue-distributor) (ok .revenue-distributor))
