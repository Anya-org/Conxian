;; oracle-trait.clar
;; Conxian Enterprise Standard: Oracle Trait Interface
;; Defines the canonical oracle interface for price feeds and data oracles

(define-trait oracle-trait (
  ;; Get the current price for a given asset pair
  (get-price 
    (base (string-ascii 32)) 
    (quote (string-ascii 32)) 
    (response (uint 1000) uint)
  )
  
  ;; Get price with confidence interval
  (get-price-with-confidence 
    (base (string-ascii 32)) 
    (quote (string-ascii 32)) 
    (response { price: uint, confidence: uint, timestamp: uint } uint)
  )
  
  ;; Update price data (only authorized oracles)
  (update-price 
    (base (string-ascii 32)) 
    (quote (string-ascii 32)) 
    (price uint) 
    (confidence uint) 
    (response bool uint)
  )
  
  ;; Check if oracle is valid and active
  (is-valid 
    () 
    (response bool uint)
  )
  
  ;; Get last update timestamp
  (get-last-update 
    (base (string-ascii 32)) 
    (quote (string-ascii 32)) 
    (response uint uint)
  )
))
